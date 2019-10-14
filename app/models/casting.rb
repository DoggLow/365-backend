class Casting < ActiveRecord::Base
  STATES = [:pending, :processing, :done]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  enumerize :aasm_state, in: STATES, scope: true
  enumerize :ask, in: Currency.enumerize
  enumerize :bid, in: Currency.enumerize
  enumerize :currency, in: Currency.enumerize
  enumerize :market_id, in: Market.enumerize, scope: true
  serialize :ask_distributions, Array
  serialize :bid_distributions, Array

  POOL_SYMBOL = 'pld'

  validates_presence_of :unit, :amount, :currency, :paid_amount, :market_id
  validates_numericality_of :unit, :amount, :paid_amount, :paid_fee, :ask_org_locked, :bid_org_locked, :org_distribution, greater_than: 0.0
  validates_numericality_of :ask_locked, :bid_locked, :distribution, greater_than_or_equal_to: 0.0

  before_validation :fill_data, on: :create
  validate :validate_data, on: :create
  after_create :strike

  CC_FEE = 0.05

  belongs_to :member
  belongs_to :pool

  scope :pending, -> { where(aasm_state: :pending) }
  scope :processing, -> { where(aasm_state: :processing) }
  scope :pending_or_processing, -> { where('aasm_state = ? OR aasm_state = ?', :processing, :pending) }
  scope :not_done, -> { where.not(aasm_state: :done) }
  scope :h24, -> { where("created_at > ?", 24.hours.ago) }

  aasm :whiny_transitions => false do
    state :pending, initial: true
    state :processing
    state :done, after_commit: :move_to_pool

    event :check do |e|
      transitions :from => [:processing], :to => :done, :guard => :all_distributed?
      transitions :from => [:pending], :to => :processing, :guard => :any_distributed?
    end
  end

  def strike
    hold_account.lock!.sub_funds self.paid_amount, fee: self.paid_fee, reason: Account::CC_CHARGE, ref: self
    ask_account.lock!.plus_locked self.ask_org_locked, reason: Account::CC_LOCK, ref: self
    bid_account.lock!.plus_locked self.bid_org_locked, reason: Account::CC_LOCK, ref: self

    check!
  end

  def distribute
    ask_unlock_amount = ask_distributions[self.distribution_times] * ask_org_locked / 100.0
    bid_unlock_amount = bid_distributions[self.distribution_times] * bid_org_locked / 100.0
    ask_account.lock!.unlock_and_sub_funds ask_unlock_amount, locked: ask_unlock_amount, reason: Account::CC_UNLOCK, ref: self
    bid_account.lock!.unlock_and_sub_funds bid_unlock_amount, locked: bid_unlock_amount, reason: Account::CC_UNLOCK, ref: self

    ask_distribution = ask_distributions[self.distribution_times] * org_distribution / 200.0
    bid_distribution = bid_distributions[self.distribution_times] * org_distribution / 200.0
    expect_account.lock!.plus_locked ask_distribution, reason: Account::CC_DISTRIBUTION, ref: self
    expect_account.lock!.plus_locked bid_distribution, reason: Account::CC_DISTRIBUTION, ref: self

    self.ask_locked -= ask_unlock_amount
    self.bid_locked -= bid_unlock_amount
    self.distribution += ask_distribution + bid_distribution
    self.distribution_times += 1
    self.save!

    check!
  end

  private

  def any_distributed?
    distribution > 0 || distribution_times > 0
  end

  def all_distributed?
    org_distribution <= distribution
  end

  def move_to_pool
    expect_account.lock!.unlock_and_sub_funds distribution, locked: distribution, reason: Account::CC_MOVE_POOL, ref: self
    pool.lock!.deposit_funds(distribution)
  end

  def fill_data
    fiat_amount = amount * unit
    real_fee = fiat_amount * CC_FEE
    real_fiat_amount = fiat_amount - real_fee
    self.ask = market_obj.ask['currency']
    self.bid = market_obj.bid['currency']
    self.paid_amount = Global.estimate('usdt', currency, fiat_amount).round(8)
    self.paid_fee = Global.estimate('usdt', currency, real_fee).round(8)
    self.ask_locked = self.ask_org_locked = Global.estimate('usdt', ask, real_fiat_amount / 2.0).round(8)
    self.bid_locked = self.bid_org_locked = Global.estimate('usdt', bid, real_fiat_amount / 2.0).round(8)
    self.org_distribution = (real_fiat_amount / Price.get_rate(POOL_SYMBOL, 'USD')).round(8)
    self.ask_distributions = gen_distributions
    self.bid_distributions = gen_distributions
    self.pool = member.get_pool(POOL_SYMBOL)
  end

  def gen_distributions
    total = 100
    n = 24
    dividers = (1..total-1).to_a.sample(n - 1).sort
    copied = dividers.clone << total
    dividers.unshift(0)
    result = []
    copied.each_with_index do |item, index|
      result << item - dividers[index]
    end
    result
  end

  def validate_data
    if hold_account.blank?
      errors.add 'account', 'invalid'
    else
      balance = hold_account.balance
      if balance < paid_amount
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def expect_account
    member.get_account(POOL_SYMBOL)
  end

  def hold_account
    member.get_account(currency)
  end

  def ask_account
    member.get_account(ask)
  end

  def bid_account
    member.get_account(bid)
  end

  def market_obj
    Market.find market_id
  end
end
