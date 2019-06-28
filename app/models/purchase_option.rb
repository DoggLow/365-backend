class PurchaseOption < ActiveRecord::Base
  class << self
    def get(option)
      Rails.cache.fetch "exchange:#{option}".to_sym, expires_in: 1.hour do
        find_or_create_by(id: 1).instance_eval(option)
      end
    rescue StandardError => e
      0
    end
  end
end
