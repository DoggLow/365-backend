#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= "development"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

running = true
Signal.trap(:TERM) {running = false}

def process_trade(data)
  market_id = data.fetch('symbol').downcase
  id = data.fetch('id')

  trade = Trade.find_by(binance_id: id)
  return if trade.present?

  price = data.fetch('price').to_f
  volume = data.fetch('qty').to_f
  # funds = data.fetch('quoteQty').to_f
  funds = price * volume
  created_at = Time.at(data.fetch('time') / 1000)
  order_id = data.fetch('orderId')
  is_buyer = data.fetch('isBuyer')
  is_maker = data.fetch('isMaker')

  trade_params = {price: price, volume: volume, funds: funds, currency: market_id.to_sym, created_at: created_at}
  trade_params[:binance_id] = id if id.present?

  order = Order.find_by(binance_id: order_id)
  return if order.blank?
  # raise "Cannot find order of which binance id is #{order_id}" if order.blank?

  if is_buyer
    trade_params[:bid_id] = order.id
    trade_params[:bid_member_id] = order.member_id
  else
    trade_params[:ask_id] = order.id
    trade_params[:ask_member_id] = order.member_id
  end

  trade = Trade.create!(trade_params)

  order.strike(trade, is_maker)
rescue StandardError => e
  Rails.logger.fatal e.inspect
end

def process_order(data)
  id = data.fetch('orderId')
  order = Order.find_by(binance_id: id)
  return if order.blank?
  # raise "Cannot find order of which binance id is #{id}" if order.blank?

  status = data.fetch('status')
  return if order.state != Order::WAIT || status == 'NEW'

  # price = data.fetch('price').to_f
  origin_volume = data.fetch('origQty').to_f
  executed_volume = data.fetch('executedQty').to_f
  funds_received = data.fetch('cummulativeQuoteQty').to_f
  case status
  when 'FILLED'
    state = Order::DONE
  when 'CANCELED'
    state = Order::CANCEL
  when 'EXPIRED'
    state = Order::CANCEL
  when 'REJECTED'
    state = Order::FAIL
  else
    state = Order::WAIT
  end

  if state == Order::DONE
    order.update!(volume: origin_volume - executed_volume, funds_received: funds_received, state: state) if order.locked == 0 || order.volume == 0
  elsif state == Order::WAIT
  else
    order.update!(volume: origin_volume - executed_volume, funds_received: funds_received, state: state)
  end
rescue StandardError => e
  Rails.logger.fatal e.inspect
end

while running
  Market.from_binance.each do |market|
    begin
      next if Order.active.with_currency(market).blank?

      BinanceClient.new.my_trades(market.id).each {|trade| process_trade trade}
      BinanceClient.new.all_orders(market.id).each {|order| process_order order}
    rescue => e
      Rails.logger.fatal e.inspect
    end
  end

  Kernel.sleep 60
end
