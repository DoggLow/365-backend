class Ordering

  class CancelOrderError < StandardError; end
  class InvalidOrderError < StandardError; end

  def initialize(order_or_orders)
    @orders = Array(order_or_orders)
  end

  def submit
    ActiveRecord::Base.transaction do
      @orders.each {|order| do_submit order }
    end

    @orders.each do |order|
      if order.market_obj.is_binance?
        order_id = BinanceClient.new.create_order(order)
        if order_id
          ActiveRecord::Base.transaction do
            order.binance_id = order_id
            order.save!
          end
        else
          do_fail! order
        end
      else # if order.market.is_inner?
        AMQPQueue.enqueue(:matching, action: 'submit', order: order.to_matching_attributes)
      end
    end

    true
  end

  def cancel
    @orders.each {|order| do_cancel order }
  end

  def cancel!
    ActiveRecord::Base.transaction do
      @orders.each do |order|
        if order.market_obj.is_binance?
          do_cancel order
        else # if order.market.is_inner?
          do_cancel! order
        end
      end
    end
  end

  private

  def do_submit(order)
    order.fix_number_precision # number must be fixed before computing locked
    order.locked = order.origin_locked = order.compute_locked
    order.save!

    if order.trigger_order_id.blank? && order.source != 'Position'
      # submit normal order
      account = order.hold_account
      account.lock_funds(order.locked, reason: Account::ORDER_SUBMIT, ref: order)
    else
      # submit margin order
      account = order.hold_margin_account
      account.lock_borrowed(order.locked, reason: Account::ORDER_SUBMIT, ref: order)
    end
  end

  def do_cancel(order)
    if order.market_obj.is_binance?
      result = BinanceClient.new.cancel_order(order)
      if result
        do_cancel! order
      end
    else # if order.market.is_inner?
      AMQPQueue.enqueue(:matching, action: 'cancel', order: order.to_matching_attributes)
    end
  end

  def do_cancel!(order)
    order   = Order.find(order.id).lock!

    if order.state == Order::WAIT
      order.state = Order::CANCEL
      if order.trigger_order_id.blank? && order.source != 'Position'
        # cancel normal order
        account = order.hold_account
        account.unlock_funds(order.locked, reason: Account::ORDER_CANCEL, ref: order)
      else
        # cancel margin order
        account = order.hold_margin_account
        account.unlock_borrowed(order.locked, reason: Account::ORDER_CANCEL, ref: order)
        order.active_loans.each { |active_loan| active_loan.close }
      end
      order.save!
    else
      raise CancelOrderError, "Only active order can be cancelled. id: #{order.id}, state: #{order.state}"
    end
  end

  def do_fail!(order)
    order = Order.find(order.id).lock!

    if order.state == Order::WAIT
      order.state = Order::FAIL
      account = order.hold_account
      account.unlock_funds(order.locked, reason: Account::ORDER_FAIL, ref: order)
      order.save!
    end
    raise InvalidOrderError, "Order failed. id: #{order.id}, state: #{order.state}"
  end

end
