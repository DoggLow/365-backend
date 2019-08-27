require 'csv'

class Purchase < ActiveRecord::Base
  STATES = [:pending, :processing, :done]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  enumerize :aasm_state, in: STATES, scope: true

  validates_presence_of :fiat, :amount, :product_id, :product_count, :sale_rate, :currency, :rate, :amount
  validates_numericality_of :product_count, :sale_rate, :rate, :amount, greater_than: 0.0
  validates_numericality_of :fee, :product_rate, :volume, :filled_volume, greater_than_or_equal_to: 0.0

  before_validation :fill_data, on: :create
  validate :validate_data, on: :create
  after_create :strike

  belongs_to :member
  belongs_to :product
  has_many :profits, as: :modifiable

  scope :pending, -> { where(aasm_state: :pending) }
  scope :processing, -> { where(aasm_state: :processing) }
  scope :not_done, -> { where.not(aasm_state: :done) }

  def self.to_csv
    attributes = %w{id product_name product_count amount currency}

    CSV.generate(headers: true) do |csv|
      csv << attributes

      all.each do |purchase|
        csv << attributes.map{ |attr| purchase.send(attr) }
      end
    end
  end

  aasm :whiny_transitions => false do
    state :pending, initial: true
    state :processing
    state :done, after_commit: :unlock_filled

    event :check do |e|
      transitions :from => [:pending, :processing], :to => :done, :guard => :all_filled?
      transitions :from => [:pending], :to => :processing, :guard => :any_filled?
    end
  end

  def strike
    sub_funds
    PurchaseMailer.purchase(self).deliver
    return unless is_tsf_purchase?

    set_volume
    fill_volume(self.volume)
  end

  def set_volume(return_rate = 0)
    self.product_rate = Price.get_rate(self.product.currency, self.fiat)
    self.volume = is_tsf_purchase? ? self.product_count * self.product.sales_price : self.amount * self.rate / self.product_rate * return_rate
    self.save!
  end

  def fill_volume(value)
    self.filled_volume += value
    self.save!

    lock_filled(value)
    check!

    unless is_tsf_purchase? # PLD
      create_profit(value)
    end

    # Referral for TSF Purchase
    create_and_calculate_referral(value)
  end

  def for_notify
    {
        id: id,
        product_name: product.label,
        product_currency: product.currency,
        product_count: product_count,
        at: created_at.to_i,
        fiat: fiat,
        currency: currency,
        rate: rate,
        sale_rate: sale_rate,
        amount: amount,
        volume: volume,
        filled_volume: filled_volume,
        fee: fee,
        state: aasm_state
    }
  end

  def as_json(options = {})
    for_notify
  end

  private

  def sub_funds
    hold_account.lock!.sub_funds amount + fee, fee: 0, reason: Account::PURCHASE, ref: self
  end

  def lock_filled(value)
    expect_account.lock!.plus_locked value, reason: Account::PURCHASE, ref: self
  end

  def unlock_filled
    expect_account.lock!.unlock_funds self.filled_volume, reason: Account::PURCHASE, ref: self
  end

  def create_profit(value)
    profit = Profit.create(
        member: member,
        currency: product.currency,
        amount: value,
        modifiable_id: self.id,
        modifiable_type: Purchase.name
    )
    PurchaseMailer.profit(self, profit).deliver
  end

  def create_and_calculate_referral(value)
    referrer = member.referrer
    return if referrer.blank?

    if is_tsf_purchase?
      # return if referrer.id_document.blank?
      # return unless referrer.id_document_verified?
      return if referrer.purchases.blank? # For only TSF
    end

    # calculate
    coin = "#{product.currency}p" # TSFP, PLDP
    aff_fee = PurchaseOption.get("#{product.currency}_aff_fee") / 100

    # Create referral
    referral = Referral.create(
        member: member,
        currency: coin,
        amount: value,
        modifiable_id: self.id,
        modifiable_type: Purchase.name,
        state: Referral::PENDING
    )
    referral.calculate_from_purchase(value * aff_fee, self)
  end

  def is_tsf_purchase?
    self.product.currency.upcase == 'TSF'
  end

  def any_filled?
    filled_volume > 0
  end

  def all_filled?
    (Date.today > PurchaseOption.get('pld_completion_date').to_date) && (filled_volume > 0)
  end

  def fill_data
    self.fiat = 'usd' if self.fiat.blank?
    self.sale_rate = Price.get_rate(self.product.sales_unit, self.fiat)
    self.rate = Price.get_rate(currency, self.fiat)
    self.amount = (self.product_count.to_i * self.product.sales_price * self.sale_rate / self.rate).round(8)

    if is_tsf_purchase? # TODO
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

  def product_name
    product.label
  end
end
