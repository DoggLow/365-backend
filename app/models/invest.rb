class Invest < ActiveRecord::Base
  STATES = [:pending, :processing, :done]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  enumerize :aasm_state, in: STATES, scope: true

  belongs_to :member

  validates_presence_of :unit, :count, :currency
  validates_numericality_of :unit, :count, greater_than: 0.0
  validates_numericality_of :profit, :paid_profit, greater_than_or_equal_to: 0.0

  validate :validate_data, on: :create

  scope :processing, -> { where(aasm_state: :processing) }
  scope :with_year_and_month, ->(date_str) {
    date = Date.strptime(date_str, '%Y-%m')
    where(created_at: date...date.next_month)
  }

  aasm :whiny_transitions => false do
    state :pending, initial: true, before_enter: :lock_funds
    state :processing
    state :done, after_commit: :complete_invest

    event :check do |e|
      before :pay_profit

      transitions :from => [:pending], :to => :processing, :guard => :profit_is_set?
      transitions :from => [:pending, :processing], :to => :done, :guard => :all_paid?
    end
  end

  def for_notify
    {
        id: id,
        created_at: created_at.to_i,
        unit: unit,
        count: count,
        currency: currency
    }
  end

  private

  def lock_funds
    hold_account.lock!
    hold_account.lock_funds unit * count, reason: Account::INVEST_LOCK, ref: self
  end

  def unlock_funds
    hold_account.lock!
    hold_account.unlock_funds unit * count, reason: Account::INVEST_UNLOCK, ref: self
  end

  def validate_data
    if hold_account.blank?
      errors.add 'account', 'invalid'
    else
      balance = hold_account.balance
      if balance < unit * count
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def hold_account
    member.get_account(currency)
  end

  def expect_account
    member.get_account('tsfp')
  end

  def profit_is_set?
    profit > 0
  end

  def all_paid?
   (paid_profit >= profit) && (profit > 0)
  end

  def pay_profit
    m_amount = self.profit / 12 # Monthly pay amount

    expect_account.lock!
    expect_account.plus_funds m_amount , fee: 0, reason: Account::INVEST_PROFIT, ref: self

    self.paid_profit += m_amount
    self.save!
  end

  def complete_invest
    unlock_funds
  end
end
