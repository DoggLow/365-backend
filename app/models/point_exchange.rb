class PointExchange < ActiveRecord::Base
  STATES = [:submitting, :submitted, :rejected, :done]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  enumerize :aasm_state, in: STATES, scope: true

  validates_presence_of :amount, :price, :total, :fee, :currency
  validates_numericality_of :amount, :price, :total, greater_than: 0.0
  validates_numericality_of :fee, greater_than_or_equal_to: 0.0

  validate :validate_data, on: :create

  before_validation :calc_price, on: :create

  belongs_to :member

  aasm :whiny_transitions => false do
    state :submitting, initial: true
    state :submitted, after_commit: :send_email
    state :rejected
    state :done, after_commit: [:send_email]

    event :submit do
      transitions from: :submitting, to: :submitted
      after :lock_funds
    end

    event :reject do
      transitions from: :submitted, to: :rejected
      after :unlock_funds
    end

    event :accept do
      transitions from: :submitted, to: :done
      before [:set_txid, :unlock_and_sub_funds]
    end
  end

  private

  def lock_funds
    hold_account.lock!
    hold_account.lock_funds amount, reason: Account::POINT_EXCHANGE_LOCK, ref: self
  end

  def unlock_funds
    hold_account.lock!
    hold_account.unlock_funds amount, reason: Account::POINT_EXCHANGE_UNLOCK, ref: self
  end

  def unlock_and_sub_funds
    hold_account.lock!
    hold_account.unlock_and_sub_funds amount, locked: amount, fee: 0, reason: Account::POINT_EXCHANGE, ref: self
  end

  def plus_funds
    expect_account.lock!
    expect_account.plus_funds total, fee: 0, reason: Account::POINT_EXCHANGE, ref: self
  end

  def send_email
    case aasm_state
    when 'submitted'
      TSFMailer.point_exchange_submitted(self.id).deliver
    when 'done'
      TSFMailer.point_exchange_done(self.id).deliver
    end
  end

  def calc_price
    if currency == 'tsf'
      coin_price = PurchaseOption.get(tsf_usd)
    else
      coin_price = Price.latest_price_3rd_party(currency, 'USD')
    end

    self.fee = amount.to_d * PurchaseOption.get(tsfp_fee) / 100
    self.price = coin_price == 0 ? 0 : (coin_price / PurchaseOption.get(tsfp_usd)).round(8)
    self.total = (amount.to_d - self.fee) * self.price
  end

  def validate_data
    account = hold_account
    if account.blank?
      errors.add 'account', 'invalid'
    else
      balance = account.balance
      if balance < amount
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def hold_account
    member.get_account('tsfp')
  end

  def expect_account
    member.get_account(currency)
  end
end
