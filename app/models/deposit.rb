class Deposit < ActiveRecord::Base
  STATES = [:submitting, :cancelled, :submitted, :rejected, :accepted, :checked, :warning]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible
  # added when removing Deposits::{CoinName}
  include Deposits::Coinable

  has_paper_trail on: [:update, :destroy]

  enumerize :aasm_state, in: STATES, scope: true

  alias_attribute :sn, :id

  delegate :name, to: :member, prefix: true
  delegate :coin?, :fiat?, to: :currency_obj

  belongs_to :member
  belongs_to :account

  validates_presence_of \
    :amount, :account, \
    :member, :currency
  validates_numericality_of :amount, greater_than: 0

  scope :recent, -> { order('id DESC')}

  before_validation :set_account

  aasm :whiny_transitions => false do
    state :submitting, initial: true, before_enter: :set_fee
    state :cancelled
    state :submitted, after_commit: :check_min_amount
    state :rejected
    state :accepted, after_commit: [:do, :send_mail, :send_sms]
    state :checked
    state :warning

    event :submit do
      transitions from: :submitting, to: :submitted
    end

    event :cancel do
      transitions from: :submitting, to: :cancelled
    end

    event :reject do
      transitions from: :submitted, to: :rejected
    end

    event :accept do
      transitions from: :submitted, to: :accepted
    end

    event :check do
      transitions from: :accepted, to: :checked
    end

    event :warn do
      transitions from: :accepted, to: :warning
    end
  end

  def txid_desc
    txid
  end

  class << self
    def resource_name
      name.demodulize.underscore.pluralize
    end

    def params_name
      name.underscore.gsub('/', '_')
    end

    def new_path
      "new_#{params_name}_path"
    end
  end

  def update_confirmations(data)
    update_column(:confirmations, data)
  end

  def txid_text
    txid && txid.truncate(40)
  end

  private
  def do
    account.lock!.plus_funds amount, reason: Account::DEPOSIT, ref: self
  end

  def send_mail
    DepositMailer.accepted(self.id).deliver if self.accepted?
  end

  def send_sms
    return true if not member.sms_two_factor.activated?

    sms_message = I18n.t('sms.deposit_done', email: member.email,
                                             currency: currency_text,
                                             time: I18n.l(Time.now),
                                             amount: amount,
                                             balance: account.balance)

    AMQPQueue.enqueue(:sms_notification, phone: member.phone_number, message: sms_message)
  end

  def set_account
    self.account = member.get_account(currency)
  end

  def check_min_amount
    if self.amount < currency_obj.deposit['min_amount']
      with_lock do
        reject!
        save!
      end
    end
  end

  def set_fee
    amount, fee = calc_fee
    self.amount = amount
    self.fee = fee
  end

  def calc_fee
    [amount, 0]
  end

end
