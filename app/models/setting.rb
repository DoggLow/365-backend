class Setting < ActiveRecord::Base
  validates_numericality_of :maintenance_margin, :initial_margin, :greater_than => 0
  validates_numericality_of :maintenance_margin, :initial_margin, :less_than => 100
  validate :market_order_validations

  class << self
    def get(option)
      Rails.cache.fetch "exchange:#{option}".to_sym, expires_in: 5.minutes do
        find_or_create_by(id: 1).instance_eval(option)
      end
    rescue StandardError => e
      0
    end
  end

  private

  def market_order_validations
    errors.add(:maintenance_margin, :invalid) if maintenance_margin >= initial_margin
  end

end
