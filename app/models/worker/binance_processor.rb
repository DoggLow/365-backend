module Worker
  class BinanceProcessor

    FRESH_TRADES = 50

    def initialize
      @binance_api_client  = Binance::Client::REST.new

      init_market_data

      Thread.new do
        loop do
          Market.from_binance.each do |market|
            fetch_depth market
            sleep 2
          end
        end
      end
    end

    def process(payload, metadata, delivery_info)
      event = payload['event']
      data  = payload['data']

      case event
      when 'depth_update'
        market_id = data.fetch('market')
        bids = data.fetch('bids')
        asks = data.fetch('asks')

        update_depth(market_id, bids, asks)
      when 'trade'
        process_trade(data)
      else
        raise ArgumentError, "Unknown event: #{event}"
      end
    rescue
      Rails.logger.error "Failed to process payload: #{$!}"
      Rails.logger.error $!.backtrace.join("\n")
    end

    private

    def init_market_data
      @bid_depth = Hash.new
      @ask_depth = Hash.new

      @trades = {}

      Market.from_binance.each do |market|
        @bid_depth[market.id] = RBTree.new
        @ask_depth[market.id] = RBTree.new

        @trades[market.id] = Array.new

        cache_depth(market.id)
      end
    end

    def fetch_depth(market)
      data = @binance_api_client.depth symbol: market.id.upcase, limit: 80
      last_update_id = data.fetch('lastUpdateId')
      Rails.cache.write("exchange:#{market.id}:last_update_id", last_update_id, force: true)

      @bid_depth[market.id].clear
      @ask_depth[market.id].clear

      update_depth market.id, data.fetch('bids'), data.fetch('asks')
    rescue
      Rails.logger.error "Failed to get depth: #{$!}"
      Rails.logger.error $!.backtrace.join("\n")
      Rails.logger.error "Response: #{data}"
    end

    def update_depth(market_id, bids, asks)
      bids.each do |order|
        @bid_depth[market_id][order[0]] = order[1]
        @bid_depth[market_id].delete_if{|k, v| v.to_f == 0}
      end

      asks.each do |order|
        @ask_depth[market_id][order[0]] = order[1]
        @ask_depth[market_id].delete_if{|k, v| v.to_f == 0}
      end

      cache_depth market_id

      AMQPQueue.enqueue(:slave_book, {action: 'none', order: {market: market_id}}, {persistent: false})
    end

    def cache_depth(market)
      bids = @bid_depth[market].to_a
      asks = @ask_depth[market].to_a
        bids.reverse!

        Rails.cache.write "exchange:#{market}:depth:asks", asks
        Rails.cache.write "exchange:#{market}:depth:bids", bids
    rescue
      Rails.logger.error "Failed to cache depth: #{$!}"
      Rails.logger.error $!.backtrace.join("\n")
    end

    def process_trade(data)
      market_id = data.fetch('s').downcase
      id = data.fetch('t')
      price = data.fetch('p').to_f
      volume = data.fetch('q').to_f
      created_at = Time.at(data.fetch('T')/1000)

      trade_params = {id: id, price: price, volume: volume, funds: price * volume, currency: market_id.to_sym, created_at: created_at}
      trade = Trade.new(trade_params)
      trades = @trades[market_id]
      trades.unshift(trade.for_global)
      trades.pop if trades.size > FRESH_TRADES

      Rails.cache.write "exchange:#{market_id}:trades", trades
      Rails.cache.write "exchange:#{market_id}:ticker_last", price
      AMQPQueue.publish(:trade, trade.for_notify, {headers: {trade: 'new'}})
    end
  end
end
