class Bet < ActiveRecord::Base
  STATES = [:accepted, :win, :lose]
  BET_FEE = 0.05

  extend Enumerize

  include AASM
  include AASM::Locking

  enumerize :aasm_state, in: STATES, scope: true

  belongs_to :member

  validates_presence_of :unit, :amount, :member, :expectancy
  validates_numericality_of :unit, :amount, greater_than: 0

  validate :validate_data, on: :create
  after_create :strike

  scope :accepted, -> { where(aasm_state: :accepted) }
  scope :amount_sum, -> {sum('unit*amount')}

  aasm :whiny_transitions => false do
    state :accepted, initial: true, after_commit: [:send_email]
    state :win, after_commit: [:plus_funds, :send_email]
    state :lose, after_commit: [:send_email]

    event :check do |e|
      transitions :from => :accepted, :to => :win, :guard => :win?
      transitions :from => :accepted, :to => :lose, :guard => :lose?
    end
  end

  def validate_data
    if hold_account.blank?
      errors.add 'account', 'invalid'
    else
      balance = hold_account.balance
      if balance < unit * amount
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def strike
    hold_account.sub_funds(unit * amount, reason: Account::BET_SUB)
  end

  def complete(result, bonus)
    self.update!(result: result, bonus: bonus, fee: unit * amount * BET_FEE)
    check!
  end

  private

  def plus_funds
    hold_account.plus_funds(unit * amount * (1 - BET_FEE), reason: Account::BET_RETURN)
    hold_account.plus_funds(bonus * (1 - BET_FEE), reason: Account::BET_BONUS)
  end

  def send_email
    case aasm_state
    when 'accepted'
      CastingMailer.bet_accepted(self).deliver
    when 'win'
      CastingMailer.bet_win(self).deliver
    when 'lose'
      CastingMailer.bet_lose(self).deliver
    end
  end

  def win?
    expectancy == result
  end

  def lose?
    expectancy != result
  end

  def hold_account
    member.get_account(:btc)
  end
end
