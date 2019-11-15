class Pool < ActiveRecord::Base
  include Currencible

  POOL_SYMBOL = 'pld'
  ZERO = 0.to_d
  REFERRAL_RATE = 0.01

  belongs_to :member
  belongs_to :account
  validates :member_id, uniqueness: {scope: :currency}
  validates_numericality_of :balance, greater_than_or_equal_to: ZERO

  has_many :castings
  has_many :pool_deposits

  scope :active, -> {where("balance > ?", 0)}
  scope :balance_sum, -> (currency) {with_currency(currency).sum(:balance)}

  before_validation :set_account

  def set_account
    self.account = member.get_account(currency)
  end

  def allocate(alloc_amount)
    # TODO: Need to update when add new casting bot
    ask_coin = 'btc'
    bid_coin = 'usdt'
    # casting = castings.active.first
    org_allocation = (alloc_amount * Price.get_rate(POOL_SYMBOL, 'USD')).round(8) # USD amount
    ask_allocation = Global.estimate('usdt', ask_coin, org_allocation / 2.0).round(8)
    bid_allocation = Global.estimate('usdt', bid_coin, org_allocation / 2.0).round(8)
    member.get_account(ask_coin).lock!.plus_funds ask_allocation, reason: Account::CC_ALLOCATION, ref: self
    member.get_account(bid_coin).lock!.plus_funds bid_allocation, reason: Account::CC_ALLOCATION, ref: self

    create_and_calculate_referral(ask_coin, ask_allocation)
    create_and_calculate_referral(bid_coin, bid_allocation)
  end

  def deposit_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount <= ZERO or fee > amount) and raise PoolError, "cannot add funds (amount: #{amount})"
    change_balance amount
  end

  def withdraw_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount <= ZERO or amount > self.balance) and raise PoolError, "cannot subtract funds (amount: #{amount})"
    change_balance -amount
  end

  def change_balance(delta_b)
    self.balance += delta_b
    self.save!
  end

  class PoolError < RuntimeError;
  end

  private

  def create_and_calculate_referral(coin, value)
    referral = Referral.create(
        member: member,
        currency: coin,
        amount: value,
        modifiable_id: self.id,
        modifiable_type: Pool.name,
        state: Referral::PENDING
    )
    referral.calculate_from_cc_allocation(value * REFERRAL_RATE, self)
  end

end