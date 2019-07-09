class BinanceClient

  def initialize
    @client = Binance::Client::REST.new api_key: ENV["BINANCE_API_KEY"], secret_key: ENV["BINANCE_SEC_KEY"]
  end

  def create_order(order)
    side = order.type[-3, 3].downcase == 'ask' ? 'SELL' : 'BUY'
    response = @client.create_order!(symbol: order.market.upcase, side: side, type: order.ord_type,
                                     quantity: order.origin_volume, price: order.price, time_in_force: 'GTC')
    response['orderId']
  end

  def create_test_order(order)
    side = order.type[-3, 3].downcase == 'ask' ? 'SELL' : 'BUY'
    response = @client.create_test_order(symbol: order.market.upcase, side: side, type: order.ord_type,
                                         quantity: order.origin_volume, price: order.price, time_in_force: 'GTC')
    response['orderId']
  end

  def cancel_order(order)
    response = @client.cancel_order!(symbol: order.market.upcase, order_id: order.binance_id)
    response
  end

  def my_trades(market_id, from_id = nil, limit = 1000)
    @client.my_trades(symbol: market_id.upcase, from_id: from_id, limit: limit)
  end

  def all_orders(market_id, order_id = nil, limit = 1000)
    @client.all_orders(symbol: market_id.upcase, order_id: order_id, limit: limit)
  end

  def open_orders(market_id = nil)
    market_id.blank? ? @client.open_orders : @client.open_orders(symbol: market_id.upcase)
  end

end