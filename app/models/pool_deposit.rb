class PoolDeposit < ActiveRecord::Base
  extend Enumerize

  include Currencible

  enumerize :currency, in: Currency.enumerize

  validates_presence_of :unit, :amount, :currency, :org_total
  validates_numericality_of :unit, :amount, :org_total, greater_than: 0.0
  validates_numericality_of :remained, :fee, greater_than_or_equal_to: 0.0

  before_validation :fill_data, on: :create
  validate :validate_data, on: :create
  after_create :strike

  CC_POOL_DEPOSIT_FEE = 0.05

  belongs_to :member
  belongs_to :pool

  def strike
    hold_account.lock!.sub_funds self.org_total + self.fee, fee: self.fee, reason: Account::POOL_DEPOSIT, ref: self
    pool.lock!.deposit_funds(org_total)

    CastingMailer.pool_deposit_completed(self).deliver
  end

  def move_from_pool(amount, ref)
    self.remained -= amount
    self.save!

    pool.lock!.withdraw_funds(amount)
    hold_account.lock!.plus_funds amount, reason: Account::POOL_WITHDRAW, ref: ref
  end

  def for_pool
    {
        id: id,
        type: PoolDeposit.name,
        currency: currency,
        amount: org_total + fee,
        fee: fee,
        funds: remained,
        at: created_at.to_i
    }
  end

  def hold_account
    member.get_account(currency)
  end

  private

  def fill_data
    total = amount * unit
    self.fee = total * CC_POOL_DEPOSIT_FEE
    self.org_total = self.remained = total * (1 - CC_POOL_DEPOSIT_FEE)
    self.pool = member.get_pool(currency)
  end

  def validate_data
    if has_casting?
      errors.add 'castings', 'empty'
    elsif hold_account.blank?
      errors.add 'account', 'invalid'
    else
      balance = hold_account.balance
      if balance < unit * amount
        errors.add 'balance', 'insufficient'
      end
    end
  end

end
