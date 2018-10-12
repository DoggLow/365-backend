class Account < ActiveRecord::Base
  include Currencible

  FIX = :fix
  UNKNOWN = :unknown
  STRIKE_ADD = :strike_add
  STRIKE_SUB = :strike_sub
  STRIKE_FEE = :strike_fee
  STRIKE_UNLOCK = :strike_unlock
  ORDER_CANCEL = :order_cancel
  ORDER_SUBMIT = :order_submit
  ORDER_FULLFILLED = :order_fullfilled
  WITHDRAW_LOCK = :withdraw_lock
  WITHDRAW_UNLOCK = :withdraw_unlock
  DEPOSIT = :deposit
  WITHDRAW = :withdraw
  ZERO = 0.to_d

  FUNS = {:unlock_funds => 1, :lock_funds => 2, :plus_funds => 3, :sub_funds => 4, :unlock_and_sub_funds => 5}

  belongs_to :member
  has_many :payment_addresses
  has_many :versions, class_name: "::AccountVersion"
  has_many :partial_trees

  # Suppose to use has_one here, but I want to store
  # relationship at account side. (Daniel)
  belongs_to :default_withdraw_fund_source_id, class_name: 'FundSource'

  validates :member_id, uniqueness: { scope: :currency }
  validates_numericality_of :balance, :locked, greater_than_or_equal_to: ZERO
  validates_numericality_of :borrowed, :borrow_locked, greater_than_or_equal_to: ZERO

  scope :enabled, -> { where("currency in (?)", Currency.ids) }

  after_commit :trigger, :sync_update

  def payment_address
    payment_addresses.last || payment_addresses.create(currency: self.currency)
  end

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
    (amount <= ZERO or fee > amount) and raise AccountError, "cannot add funds (amount: #{amount})"
    change_balance_and_locked amount, 0
  end

  def sub_funds(amount, fee: ZERO, reason: nil, ref: nil)
    (amount <= ZERO or amount > self.balance) and raise AccountError, "cannot subtract funds (amount: #{amount})"
    change_balance_and_locked -amount, 0
  end

  def lock_funds(amount, reason: nil, ref: nil)
    (amount <= ZERO or amount > self.balance) and raise AccountError, "cannot lock funds (amount: #{amount})"
    change_balance_and_locked -amount, amount
  end

  def unlock_funds(amount, reason: nil, ref: nil)
    (amount <= ZERO or amount > self.locked) and raise AccountError, "cannot unlock funds (amount: #{amount})"
    change_balance_and_locked amount, -amount
  end

  def unlock_and_sub_funds(amount, locked: ZERO, fee: ZERO, reason: nil, ref: nil)
    raise AccountError, "cannot unlock and subtract funds (amount: #{amount})" if ((amount <= 0) or (amount > locked))
    raise LockedError, "invalid lock amount" unless locked
    raise LockedError, "invalid lock amount (amount: #{amount}, locked: #{locked}, self.locked: #{self.locked})" if ((locked <= 0) or (locked > self.locked))
    change_balance_and_locked locked-amount, -locked
  end

  def sub_tradable_funds(amount, reason: nil, ref: nil)
    if balance >= amount
      sub_funds(amount, reason: reason, ref: ref)
    else
      delta = amount - balance
      sub_funds(balance, reason: reason, ref: ref)
      sub_borrowed(delta, reason: reason, ref: ref)
    end
  end

  def lock_tradable_funds(amount, reason: nil, ref: nil)
    if balance >= amount
      lock_funds(amount, reason: reason, ref: ref)
    else
      lock_funds(balance, reason: reason, ref: ref) if balance > 0
      lock_borrowed(amount - balance, reason: reason, ref: ref)
    end
  end

  def unlock_tradable_funds(amount, reason: nil, ref: nil)
    if locked >= amount
      unlock_funds(amount, reason: reason, ref: ref)
    else
      unlock_funds(locked, reason: reason, ref: ref) if locked > 0
      unlock_borrowed(amount - locked, reason: reason, ref: ref)
    end
  end

  def plus_borrowed(amount, reason: nil, ref: nil)
    (amount <= ZERO) and raise BorrowedError, "cannot add borrowed (amount: #{amount})"
    change_borrowed amount, 0
  end

  def sub_borrowed(amount, reason: nil, ref: nil)
    (amount <= ZERO or amount > self.borrowed) and raise BorrowedError, "cannot sub borrowed (amount: #{amount})"
    change_borrowed -amount, 0
  end

  def lock_borrowed(amount, reason: nil, ref: nil)
    (amount < ZERO or amount > self.borrowed) and raise BorrowedError, "cannot lock borrowed (amount: #{amount})"
    change_borrowed -amount, amount
  end

  def unlock_borrowed(amount, reason: nil, ref: nil)
    (amount < ZERO or amount > self.borrow_locked) and raise BorrowedError, "cannot unlock borrowed (amount: #{amount})"
    change_borrowed amount, -amount
  end

  def return_borrowed(amount, reason: nil, ref: nil)
    if borrowed >= amount
      sub_borrowed amount, reason:reason, ref: ref
    else
      sub_borrowed borrowed, reason:reason, ref: ref
      sub_funds amount-borrowed, fee: ZERO, reason: reason, ref: ref
    end
  end

  after(*FUNS.keys) do |account, fun, changed, opts|
    begin
      opts ||= {}
      fee = opts[:fee] || ZERO
      reason = opts[:reason] || Account::UNKNOWN

      attributes = { fun: fun,
                     fee: fee,
                     reason: reason,
                     amount: account.amount,
                     currency: account.currency.to_sym,
                     member_id: account.member_id,
                     account_id: account.id }

      if opts[:ref] and opts[:ref].respond_to?(:id)
        ref_klass = opts[:ref].class
        attributes.merge! \
          modifiable_id: opts[:ref].id,
          modifiable_type: ref_klass.respond_to?(:base_class) ? ref_klass.base_class.name : ref_klass.name
      end

      locked, balance = compute_locked_and_balance(fun, changed, opts)
      attributes.merge! locked: locked, balance: balance

      AccountVersion.optimistically_lock_account_and_create!(account.balance, account.locked, attributes)
    rescue ActiveRecord::StaleObjectError
      Rails.logger.info "Stale account##{account.id} found when create associated account version, retry."
      account = Account.find(account.id)
      raise ActiveRecord::RecordInvalid, account unless account.valid?
      retry
    end
  end

  def self.compute_locked_and_balance(fun, amount, opts)
    raise AccountError, "invalid account operation" unless FUNS.keys.include?(fun)

    case fun
    when :sub_funds then [ZERO, ZERO - amount]
    when :plus_funds then [ZERO, amount]
    when :lock_funds then [amount, ZERO - amount]
    when :unlock_funds then [ZERO - amount, amount]
    when :unlock_and_sub_funds
      locked = ZERO - opts[:locked]
      balance = opts[:locked] - amount
      [locked, balance]
    else raise AccountError, "forbidden account operation"
    end
  end

  def tradable_balance
    self.balance + self.borrowed
  end

  def all_amount
    self.balance + self.borrowed + self.locked + self.borrow_locked
  end

  def amount
    self.balance + self.locked
  end

  def last_version
    versions.last
  end

  def examine
    expected = 0
    versions.find_each(batch_size: 100000) do |v|
      expected += v.amount_change
      return false if expected != v.amount
    end

    expected == self.amount
  end

  def trigger
    return unless member

    json = Jbuilder.encode do |json|
      json.(self, :balance, :locked, :borrowed, :borrow_locked, :currency)
    end
    member.trigger('account', json)
  end

  def change_balance_and_locked(delta_b, delta_l)
    self.balance += delta_b
    self.locked  += delta_l
    self.class.connection.execute "update accounts set balance = balance + #{delta_b}, locked = locked + #{delta_l} where id = #{id}"
    add_to_transaction # so after_commit will be triggered
    self
  end

  def change_borrowed(delta_ba, delta_lo)
    self.borrowed  += delta_ba
    self.borrow_locked  += delta_lo
    self.class.connection.execute "update accounts set borrowed = borrowed + #{delta_ba}, borrow_locked = borrow_locked + #{delta_lo} where id = #{id}"
    add_to_transaction # so after_commit will be triggered
    self
  end

  scope :locked_sum, -> (currency) { with_currency(currency).sum(:locked) }
  scope :balance_sum, -> (currency) { with_currency(currency).sum(:balance) }

  scope :borrowed_sum, -> (currency) { with_currency(currency).sum(:borrowed) }
  scope :borrow_locked_sum, -> (currency) { with_currency(currency).sum(:borrow_locked) }

  class AccountError < RuntimeError; end
  class LockedError < AccountError; end
  class BalanceError < AccountError; end
  class BorrowedError < AccountError; end
  class BorrowLockedError < AccountError; end

  def as_json(options = {})
    super(options).merge({
      # check if there is a useable address, but don't touch it to create the address now.
      "deposit_address" => payment_addresses.empty? ? "" : payment_address.deposit_address,
      "name_text" => currency_obj.name_text,
      "default_withdraw_fund_source_id" => default_withdraw_fund_source_id,
      "tag" => payment_addresses.empty? ? "" : payment_address.tag
    })
  end

  private

  def sync_update
    ::Pusher["private-#{member.sn}"].trigger_async('accounts', { type: 'update', id: self.id, attributes: {balance: balance, locked: locked, borrowed: borrowed, borrow_locked: borrow_locked} })
  end

end