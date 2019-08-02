class Price < ActiveRecord::Base
  extend Enumerize

  PRICE_TYPE = {normal: 0, min_limit: 1, fixed: 2}

  validates :market_id, presence: true, uniqueness: true
  validates :price, numericality: {greater_than_or_equal_to: 0}

  enumerize :price_type, in: PRICE_TYPE, default: :normal

  class << self

    def update(market_id, type, value)
      unless value.nil? || value.empty?
        price = Price.find_by(market_id: market_id)
        price.price_type = type
        price.price = value.to_d
        price.save!
      end
    end

    def latest_price_3rd_party(fromSymbol, toSymbol)
      from = fromSymbol.upcase
      to = toSymbol.upcase
      Rails.cache.fetch "latest_#{from}#{to}_price".to_sym, expires_in: 1.minute do
        response = Faraday.get "https://min-api.cryptocompare.com/data/price?fsym=#{from}&tsyms=#{to}"
        JSON.parse(response.body)[to].round(2)
      end
    rescue StandardError => e
      0
    end

    def get_rate(base_unit, quote_unit)
      if base_unit.upcase == quote_unit.upcase
        1
      elsif base_unit.upcase == 'TSF'
        PurchaseOption.get('tsf_usd')
      elsif base_unit.upcase == 'PLD'
        PurchaseOption.get('pld_usd')
      else
        Price.latest_price_3rd_party(base_unit, quote_unit)
      end
    end
  end

  def market_name
    Market.find(market_id).name
  end
end
