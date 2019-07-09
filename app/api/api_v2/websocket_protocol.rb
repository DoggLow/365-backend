module APIv2
  class WebSocketProtocol

    def initialize(socket, channel, logger)
      @socket = socket
      @channel = channel #FIXME: amqp should not be mixed into this class
      @logger = logger
    end

    def broadcast
      subscribe_orders
      subscribe_trades
    rescue
      @logger.error "Error on handling message: #{$!}"
      @logger.error $!.backtrace.join("\n")
    end

    private

    def send(method, data)
      payload = JSON.dump({method => data})
      @logger.debug payload
      @socket.send payload
    end

    def subscribe_orders
      x = @channel.send *AMQPConfig.exchange(:orderbook)
      q = @channel.queue '', auto_delete: true
      q.bind(x).subscribe do |metadata, payload|
        begin
          payload = JSON.parse payload
          send payload['order']['type'], payload['order']
        rescue
          @logger.error "Error on receiving orders: #{$!}"
          @logger.error $!.backtrace.join("\n")
        end
      end
    end

    def subscribe_trades
      x = @channel.send *AMQPConfig.exchange(:trade)
      q = @channel.queue '', auto_delete: true
      q.bind(x, arguments: {trade: 'new'})
      q.subscribe(ack: true) do |metadata, payload|
        begin
          payload = JSON.parse payload
          send :trade, payload
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
