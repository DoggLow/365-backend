class Pool < ActiveRecord::Base
  include Currencible

  ZERO = 0.to_d

  belongs_to :member
  belongs_to :account
  validates :member_id, uniqueness: {scope: :currency}
  validates_numericality_of :balance, greater_than_or_equal_to: ZERO

  has_many :castings
  has_many :pool_deposits

  scope :balance_sum, -> (currency) {with_currency(currency).sum(:balance)}

  before_validation :set_account

  def set_account
    self.account = member.get_account(currency)
  end

  def deposit_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount <= ZERO or fee > amount) and raise PoolError, "cannot add funds (amount: #{amount})"
    change_balance amount
  end

  def withdraw_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount <= ZERO or amount > self.balance) and raise PoolError, "cannot subtract funds (amount: #{amount})"
    change_balance -amount
    # TODO: account management
  end

  def change_balance(delta_b)
    self.balance += delta_b
    self.save!
  end

  class PoolError < RuntimeError;
  end

  def for_notify
    {
        id: id,
        currency: currency_obj,
        balance: balance,
        locked: locked,
        estimated: estimate_balance,
        payment_address: payment_address
    }
  end

  private

end