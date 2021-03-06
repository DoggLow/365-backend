class Product < ActiveRecord::Base
  include Currencible

  paranoid

  before_validation :format_attributes
  validates_presence_of :currency, :sales_unit, :sales_price
  validates_numericality_of :sales_price, greater_than: 0.0
  validate :validate_sales_unit

  has_many :purchases

  class << self
    def sale_currencies
      ['USD', 'TSF', 'PLD']
    end
  end

  def label
    if name.blank?
      "#{currency.upcase} - #{sales_price}#{sales_unit.upcase}"
    else
      name
    end
  end

  def as_json(options = {})
    super(options).merge({label: label})
  end

  protected

  def format_attributes
    self.sales_unit = self.sales_unit.downcase if self.sales_unit.present?
  end

  def validate_sales_unit
    unless Product.sale_currencies.include?(self.sales_unit.upcase)
      errors.add(:sales_unit, 'should be currency code')
    end
  end
end
