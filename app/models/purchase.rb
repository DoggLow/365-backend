class Purchase < ActiveRecord::Base
  include Currencible

  validates_presence_of :fiat, :amount, :product_id, :product_count, :sale_rate, :currency, :rate, :amount
  validates_numericality_of :product_count, :sale_rate, :rate, :amount, greater_than: 0.0
  validates_numericality_of :fee, greater_than_or_equal_to: 0.0

  before_validation :fill_data, on: :create
  validate :validate_data, on: :create
  after_create :strike

  belongs_to :member
  belongs_to :product

  def strike
    hold_account.sub_funds amount + fee, fee: 0, reason: Account::PURCHASE, ref: self
    expect_account.plus_funds real_purchase_amount, fee: 0, reason: Account::PURCHASE, ref: self # TODO: calculate amount to add

    PurchaseMailer.purchase(self).deliver

    # Referral for TSF Purchase
    create_and_calculate_referral if self.product.currency.upcase == 'TSF'
  end

  private

  def create_and_calculate_referral
    referrer = member.referrer
    return if referrer.blank?
    return unless referrer.id_document and referrer.id_document_verified?
    return if referrer.purchases.blank?

    # calculate
    coin = 'tsfp'
    ref_amount = real_purchase_amount * PurchaseOption.get('affiliate_fee') / 100

    # Create referral
    referral = Referral.create(
        member: member,
        currency: coin,
        amount: real_purchase_amount,
        modifiable_id: self.id,
        modifiable_type: Purchase.name,
        state: Referral::PENDING
    )
    referral.calculate_from_purchase(ref_amount, self)
  end

  def real_purchase_amount
    if self.product.currency.upcase == 'TSF'
      self.product_count * self.product.sales_price
    else # PLD
      self.product_count * self.product.sales_price / Price.get_rate(self.product.currency, self.product.sales_unit)
    end
  end

  def fill_data
    self.fiat = 'usd' if self.fiat.blank?
    self.sale_rate = Price.get_rate(self.product.sales_unit, self.fiat)
    self.rate = Price.get_rate(currency, self.fiat)
    self.amount = (self.product_count.to_i * self.product.sales_price * self.sale_rate / self.rate).round(8)

    if self.product.currency.upcase == 'TSF'
      self.fee = CoinAPI[currency].gas_price.round(8) * 21000
    end
  end

  def validate_data
    account = hold_account
    if account.blank?
      errors.add 'account', 'invalid'
    else
      balance = account.balance
      if balance < amount + fee
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def hold_account
    member.get_account(currency)
  end

  def expect_account
    member.get_account(self.product.currency)
  end
end
