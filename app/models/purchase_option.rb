class PurchaseOption < ActiveRecord::Base

  class << self
    def lot_unit
      Rails.cache.fetch "latest_lot_unit".to_sym, expires_in: 1.hour do
        find_or_create_by(id: 1).lot_unit
      end
    rescue StandardError => e
      0
    end

    def tsf_price
      Rails.cache.fetch "latest_tsf_price".to_sym, expires_in: 1.hour do
        find_or_create_by(id: 1).tsf_usd
      end
    rescue StandardError => e
      0
    end

    def affiliate_fee
      Rails.cache.fetch "latest_tsf_ref_fee".to_sym, expires_in: 1.day do
        find_or_create_by(id: 1).affiliate_fee / 100
      end
    rescue StandardError => e
      0
    end
  end
end
