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
    attributes = %w{id member_email product_name product_count amount currency filled_volume}

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

    if is_tsf_purchase?
      set_volume
      fill_volume(self.volume)
    else
      calc_and_fill_daily
    end
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

  # Only for PLD Purchase
  def calc_and_fill_daily
    return if is_tsf_purchase?

    # define constants
    c_t = 52_500_000 # USD
    c_n = 105_000_000.0 # all PLD
    c_k = 1.011 # 1.1%
    c_u = 250_000 # lot unit
    c_x = c_t / c_u * (c_k - 1) / (c_k ** (c_n / c_u) - 1)

    # get last PLD price and total distributed
    last_price = PurchaseOption.get('pld_usd') || 0
    total_distributed = PurchaseOption.get('distributed_pld') || 0
    last_price = c_x unless last_price > 0

    d_paid = daily_paid
    daily_distribution = 0

    if total_distributed > 0
      first_distribution = c_u - (total_distributed.to_i - 1) % c_u
      if d_paid >= first_distribution * last_price
        daily_distribution = first_distribution
        d_paid -= first_distribution * last_price
        last_price *= c_k
      else
        daily_distribution = d_paid / last_price
        d_paid = 0
      end
    end

    until d_paid <= 0 do
      if d_paid >= last_price * c_u
        daily_distribution += c_u
        d_paid -= last_price * c_u
        last_price *= c_k
      else
        daily_distribution += d_paid / last_price
        d_paid = 0
      end
    end

    fill_volume(daily_distribution)

    # calculate PLD price and total distributed
    total_distributed += daily_distribution

    # update DB
    PurchaseOption.set('pld_usd', last_price)
    PurchaseOption.set('distributed_pld', total_distributed)
  end

  def daily_paid
    return_rate * amount / period
  end

  def period
    (PurchaseOption.get('pld_completion_date').to_date - created_at.to_date).to_i + 1
  end

  def return_rate
    case product.sales_price
    when 1000
      return 1
    when 3000
      return 1.1
    when 10000
      return 1.2
    else
      return 1
    end
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

  def is_tsf_purchase?
    self.product.currency.upcase == 'TSF'
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

  def member_email
    member.email
  end

  def product_name
    product.label
  end
end
