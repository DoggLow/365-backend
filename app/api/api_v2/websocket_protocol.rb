module APIv2
  class WebSocketProtocol

    FRESH_ORDERS = 40

    def initialize(socket, channel, logger)
      @socket = socket
      @channel = channel #FIXME: amqp should not be mixed into this class
      @logger = logger
    end

    def broadcast(path)
      market_id = nil
      if Market.find_by_id(path).present?
        market_id = path
        init_market(market_id)
      end
      subscribe_orderbook(market_id)
      subscribe_trades(market_id)
    rescue
      @logger.error "Error on handling message: #{$!}"
      @logger.error $!.backtrace.join("\n")
    end

    private

    def send(method, market, data)
      payload = JSON.dump({market: market, method => data})
      # @logger.debug payload
      @socket.send payload
    end

    def init_market(market_id)
      send_orders(market_id)
      send_trades(market_id)
    end

    def send_trades(market_id)
      send :trades, market_id, Global[market_id].trades.first(FRESH_ORDERS)
    end

    def send_orders(market_id)
      asks = Global[market_id].asks
      bids = Global[market_id].bids
      asks = asks.sort_by{|order| order[0].to_f}
      bids = bids.sort_by{|order| order[0].to_f}
      asks = asks.first(FRESH_ORDERS).reverse
      bids = bids.reverse.first(FRESH_ORDERS)
      send :asks, market_id, asks
      send :bids, market_id, bids
    end

    def subscribe_orderbook(market_id = nil)
      x = @channel.send *AMQPConfig.exchange(:orderbook)
      q = @channel.queue '', auto_delete: true
      q.bind(x).subscribe do |metadata, payload|
        begin
          payload = JSON.parse payload
          if market_id.present? && payload['order']['market'] == market_id
            send_orders market_id
          end
        rescue
          @logger.error "Error on receiving orders: #{$!}"
          @logger.error $!.backtrace.join("\n")
        end
      end
    end

    def subscribe_trades(market_id = nil)
      x = @channel.send *AMQPConfig.exchange(:trade)
      q = @channel.queue '', auto_delete: true
      q.bind(x, arguments: {trade: 'new'})
      q.subscribe(ack: true) do |metadata, payload|
        begin
          payload = JSON.parse payload
          if market_id.present? && payload['market'] == market_id
            # send_orders(market_id)
            send :trade, market_id, format_trade(payload)
          end
        rescue
          @logger.error "Error on receiving trades: #{$!}"
          @logger.error $!.backtrace.join("\n")
        ensure
          metadata.ack
        end
      end
    end

    def format_trade(data)
      {
          tid: data['id'],
          date: data['at'],
          price: data['price'].to_s || ZERO,
          amount: data['volume'].to_s || ZERO
      }
    end
  end
end
