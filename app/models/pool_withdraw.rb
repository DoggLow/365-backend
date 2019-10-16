class PoolWithdraw < ActiveRecord::Base
  STATES = [:pending, :done]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  enumerize :aasm_state, in: STATES, scope: true
  enumerize :currency, in: Currency.enumerize

  validates_presence_of :amount, :currency
  validates_numericality_of :amount, greater_than: 0.0

  before_validation :fill_data, on: :create
  validate :validate_data, on: :create
  after_create :strike

  DONE = 'done'
  CC_POOL_DEPOSIT_FEE = 0.05

  belongs_to :member
  belongs_to :account
  belongs_to :modifiable, polymorphic: true

  scope :pending, -> { where(aasm_state: :pending) }
  scope :h24, -> { where("created_at > ?", 24.hours.ago) }

  aasm :whiny_transitions => false do
    state :pending, initial: true
    state :done
  end

  def strike
    modifiable.move_from_pool(self.amount, self)
    self.aasm_state = PoolWithdraw::DONE
    self.save
  end

  private

  def fill_data
    self.account = member.get_account(currency)
  end

  def validate_data
    if modifiable_type == Casting.name && modifiable.aasm_state != Casting::DONE
      errors.add 'withdraw', 'unavailable'
    else # limit validation
      mod_period = (Date.yesterday - self.modifiable.created_at.to_date).to_i
      mod_amount = self.modifiable_type == Casting.name ? modifiable.distribution : modifiable.remained
      limit_percent = mod_period >= 180 ? 1.0 : 0.2 * (mod_period / 60 + 2)
      withdrawal_limit = limit_percent *  mod_amount
      errors.add 'amount', 'exceed limits' if withdrawal_limit < amount
    end
  end

  def hold_account
    member.get_account(currency)
  end
end
