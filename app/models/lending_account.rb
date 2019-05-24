class LendingAccount < ActiveRecord::Base
  include Currencible

  FIX = :fix
  UNKNOWN = :unknown
  STRIKE_ADD = :strike_add
  STRIKE_SUB = :strike_sub
  STRIKE_FEE = :strike_fee
  STRIKE_UNLOCK = :strike_unlock
  LOAN_CANCEL = :loan_cancel
  LOAN_SUBMIT = :loan_submit
  LOAN_MATCHED = :loan_matched
  LENDING_DONE = :lending_done
  TRANSFER = :transfer
  ZERO = 0.to_d

  belongs_to :member

  validates :member_id, uniqueness: { scope: :currency }
  validates_numericality_of :locked, greater_than_or_equal_to: ZERO

  scope :enabled, -> { where("currency in (?)", Currency.ids) }

  def self.after(*names)
    names.each do |name|
      m = instance_method(name.to_s)
      define_method(name.to_s) do |*args, &block|
        m.bind(self).(*args, &block)
        yield(self, name.to_sym, *args)
        self
      end
    end
  end

  def plus_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount <= ZERO or fee > amount) and raise LendingAccountError, "cannot add funds (amount: #{amount})"
    change_balance amount-fee, 0
  end

  def sub_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount < ZERO or amount > self.balance or fee > self.balance) and raise BalanceError, "cannot subtract funds (amount: #{amount})"
    change_balance -amount-fee, 0
  end

  def lock_funds(amount, reason: nil, ref: nil)
    (amount < ZERO or amount > self.balance) and raise BalanceError, "cannot lock funds (amount: #{amount})"
    change_balance -amount, amount
  end

  def unlock_funds(amount, reason: nil, ref: nil)
    (amount < ZERO or amount > self.locked) and raise LockedError, "cannot unlock funds (amount: #{amount})"
    change_balance amount, -amount
  end

  def unlock_and_sub_funds(amount, reason: nil, ref: nil)
    (amount < ZERO or amount > self.locked) and raise LockedError, "cannot unlock and sub funds (amount: #{amount})"
    change_balance 0, -amount
  end

  def amount
    self.balance + self.locked
  end

  def change_balance(delta_ba, delta_lo)
    self.balance += delta_ba
    self.locked  += delta_lo
    self.class.connection.execute "update lending_accounts set balance = balance + #{delta_ba}, locked = locked + #{delta_lo} where id = #{id}"
    add_to_transaction
    self
  end

  scope :locked_sum, -> (currency) { with_currency(currency).sum(:locked) }
  scope :balance_sum, -> (currency) { with_currency(currency).sum(:balance) }

  class LendingAccountError < RuntimeError; end
  class LockedError < LendingAccountError; end
  class BalanceError < LendingAccountError; end

  def as_json(options = {})
    super(options).merge({
      "name_text" => currency_obj.name_text
    })
  end

  def for_notify
    {
        id:     id,
        currency: currency_obj,
        balance: balance,
        locked: locked,
        estimated: estimate_balance('btc')
    }
  end

  private

  def estimate_balance(quote_unit)
    base_unit = currency_obj.code
    if base_unit == quote_unit
      price = 1
    elsif base_unit == 'usdt'
      mkt_id = "#{quote_unit}#{base_unit}"
      price = 0
      if Market.find(mkt_id).present?
        price = Global[mkt_id].ticker[:last]
      end
      if price != 0
        price = 1 / price
      end
    else
      mkt_id = "#{base_unit}#{quote_unit}"
      if Market.find(mkt_id).blank?
        price = 0
      else
        price = Global[mkt_id].ticker[:last]
      end
    end

    (self.balance + self.locked) * price
  end
end