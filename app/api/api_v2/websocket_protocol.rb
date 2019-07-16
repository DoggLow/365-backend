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
      subscribe_market(market_id)
    rescue
      @logger.error "Error on handling message: #{$!}"
      @logger.error $!.backtrace.join("\n")
    end

    private

    def send(method, data)
      payload = JSON.dump({method => data})
      # @logger.debug payload
      @socket.send payload
    end

    def init_market(market_id)
      subscribe_orderbook(market_id)
      subscribe_trades(market_id)
    end

    def subscribe_trades(market_id)
      send :trades, Global[market_id].trades.first(FRESH_ORDERS)
    end

    def subscribe_orderbook(market_id)
      send :asks, Global[market_id].asks.first(FRESH_ORDERS).reverse()
      send :bids, Global[market_id].bids.first(FRESH_ORDERS)
    end

    def subscribe_market(market_id = nil)
      x = @channel.send *AMQPConfig.exchange(:trade)
      q = @channel.queue '', auto_delete: true
      q.bind(x, arguments: {trade: 'new'})
      q.subscribe(ack: true) do |metadata, payload|
        begin
          payload = JSON.parse payload
          if market_id.blank?
            send :trade, payload
          elsif payload['market'] == market_id
            subscribe_orderbook(market_id)
            send :trade, format_trade(payload)
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
