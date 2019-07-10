module APIv2
  class WebSocketProtocol

    def initialize(socket, channel, logger)
      @socket = socket
      @channel = channel #FIXME: amqp should not be mixed into this class
      @logger = logger
    end

    def broadcast(path)
      market_id = nil
      if Market.find_by_id(path).present?
        market_id = path
      end
      subscribe_orders(market_id)
      subscribe_trades(market_id)
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

    def subscribe_orders(market_id = nil)
      x = @channel.send *AMQPConfig.exchange(:orderbook)
      q = @channel.queue '', auto_delete: true
      q.bind(x).subscribe do |metadata, payload|
        begin
          payload = JSON.parse payload
          if market_id.blank? || (market_id.present? && payload['order']['market'] == market_id)
            send payload['order']['type'], payload['order']
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
          if market_id.blank? || (market_id.present? && payload['market'] == market_id)
            send :trade, payload
          end
        rescue
          @logger.error "Error on receiving trades: #{$!}"
          @logger.error $!.backtrace.join("\n")
        ensure
          metadata.ack
        end
      end
    end

  end
end
