class Purchase < ActiveRecord::Base
  include Currencible

  validates_presence_of :unit, :amount, :price, :total, :fee, :currency
  validates_numericality_of :unit, :amount, :price, :total, greater_than: 0.0
  validates_numericality_of :fee, greater_than_or_equal_to: 0.0

  validate :validate_data, on: :create

  before_validation :calc_price
  after_create :strike

  belongs_to :member

  def strike
    hold_account.sub_funds total + fee, fee: 0, reason: Account::PURCHASE, ref: self
    expect_account.plus_funds amount * unit, fee: 0, reason: Account::PURCHASE, ref: self

    TSFMailer.purchase(self).deliver

    # Referral for TSF Purchase
    create_and_calculate_referral
  end

  private

  def create_and_calculate_referral
    referrer = member.referrer
    return if referrer.blank?
    return unless referrer.id_document and referrer.id_document_verified?
    return if referrer.purchases.blank?

    coin = 'tsfp'
    # Create referral
    referral = Referral.create(
        member: member,
        currency: coin,
        amount: amount * unit,
        modifiable_id: self.id,
        modifiable_type: Purchase.name,
        state: Referral::PENDING
    )

    # calculate
    ref_amount = amount * unit * PurchaseOption.affiliate_fee
    referral.calculate_from_purchase(ref_amount, self)
  end

  def calc_price
    self.price = Price.latest_price_3rd_party(currency, 'USD')
    self.total = (amount.to_i * unit * PurchaseOption.tsf_price / price).round(8)
    self.fee = 1 #CoinAPI[currency].gas_price.round(8) * 21000
  end

  def validate_data
    account = hold_account
    if account.blank?
      errors.add 'account', 'invalid'
    else
      balance = account.balance
      if balance < total + fee
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def hold_account
    member.get_account(currency)
  end

  def expect_account
    member.get_account('tsf')
  end
end
