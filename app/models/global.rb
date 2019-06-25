class Global
  ZERO = '0.0'.to_d
  NOTHING_ARRAY = YAML::dump([])
  LIMIT = 80

  class << self
    def daemon_statuses
      Rails.cache.fetch('exchange:daemons:statuses', expires_in: 3.minute) do
        Daemons::Rails::Monitoring.statuses
      end
    end

    def estimate(base_unit, quote_unit, amount)
      if base_unit == quote_unit
        price = 1
      else
        mkt_id = "#{base_unit}#{quote_unit}"
        if Market.find_by_id(mkt_id).present?
          price = Global[mkt_id].ticker[:last]
        else
          mkt_id = "#{quote_unit}#{base_unit}"
          if Market.find_by_id(mkt_id).present?
            price = Global[mkt_id].ticker[:last]
            if price != 0
              price = 1 / price
            end
          else
            price = Global["#{quote_unit}btc"].ticker[:last]
            if price != 0
              price = Global["#{base_unit}btc"].ticker[:last] / price
            end
          end
        end
      end
      amount * price
    end
  end

  def initialize(currency)
    @currency = currency
  end

  attr_accessor :currency

  def self.[](market)
    if (market.is_a? Market) || (market.is_a? LoanMarket)
      self.new(market.id)
    else
      self.new(market)
    end
  end

  def key(key, interval = 5)
    seconds = Time.now.to_i
    time_key = seconds - (seconds % interval)
    "exchange:#{@currency}:#{key}:#{time_key}"
  end

  def asks
    Rails.cache.read("exchange:#{currency}:depth:asks") || []
  end

  def bids
    Rails.cache.read("exchange:#{currency}:depth:bids") || []
  end

  def default_ticker
    {low: ZERO, high: ZERO, last: ZERO, volume: ZERO}
  end

  def ticker
    ticker = Rails.cache.read("exchange:#{currency}:ticker") || default_ticker
    open = Rails.cache.read("exchange:#{currency}:ticker:open") || ticker[:last]
    best_buy_price = bids.first && bids.first[0] || ZERO
    best_sell_price = asks.first && asks.first[0] || ZERO

    ticker.merge({
                     open: open,
                     volume: h24_volume,
                     sell: best_sell_price,
                     buy: best_buy_price,
                     at: at
                 })
  end

  def h24_volume
    market = Market.find currency

    Rails.cache.fetch key('h24_volume', 5), expires_in: 24.hours do
      if market.is_binance?
        Rails.cache.read "exchange:#{market.id}:h24_volume:latest" || ZERO
      else # if market.is_inner?
        Trade.with_currency(currency).h24.sum(:volume) || ZERO
      end
    end
  end

  def trades
    Rails.cache.read("exchange:#{currency}:trades") || []
  end

  def at
    @at ||= DateTime.now.to_i
  end

  def demands
    Rails.cache.read("exchange:#{currency}:demands") || []
  end

  def offers
    Rails.cache.read("exchange:#{currency}:offers") || []
  end

  def active_loans
    Rails.cache.read("exchange:#{currency}:active_loans") || []
  end

end
