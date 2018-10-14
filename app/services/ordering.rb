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
        order_id = BinanceAPI.create_order(order)
        if order_id
          ActiveRecord::Base.transaction do
            order.binance_id = order_id
            order.save!
          end
        else
          order.destroy
          raise InvalidOrderError
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

    account = order.hold_account
    account.lock_tradable_funds(order.locked, reason: Account::ORDER_SUBMIT, ref: order)
  end

  def do_cancel(order)
    if order.market_obj.is_binance?
      result = BinanceAPI.cancel_order(order)
      if result
        do_cancel! order
      end
    else # if order.market.is_inner?
      AMQPQueue.enqueue(:matching, action: 'cancel', order: order.to_matching_attributes)
    end
  end

  def do_cancel!(order)
    account = order.hold_account
    order   = Order.find(order.id).lock!

    if order.state == Order::WAIT
      order.state = Order::CANCEL
      account.unlock_tradable_funds(order.locked, reason: Account::ORDER_CANCEL, ref: order)
      order.save!
    else
      raise CancelOrderError, "Only active order can be cancelled. id: #{order.id}, state: #{order.state}"
    end
  end

end
