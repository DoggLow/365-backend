class AccountVersion < ActiveRecord::Base
  include Currencible

  HISTORY = [Account::STRIKE_ADD, Account::STRIKE_SUB, Account::STRIKE_FEE, Account::DEPOSIT, Account::WITHDRAW, Account::FIX]

  enumerize :fun, in: Account::FUNS

  REASON_CODES = {
      Account::UNKNOWN => 0,
      Account::FIX => 1,
      Account::STRIKE_FEE => 100,
      Account::STRIKE_ADD => 110,
      Account::STRIKE_SUB => 120,
      Account::STRIKE_UNLOCK => 130,
      Account::ORDER_SUBMIT => 600,
      Account::ORDER_CANCEL => 610,
      Account::ORDER_FULLFILLED => 620,
      Account::ORDER_FAIL => 660,
      Account::WITHDRAW_LOCK => 800,
      Account::WITHDRAW_UNLOCK => 810,
      Account::DEPOSIT => 1000,
      Account::WITHDRAW => 2000,
      Account::REFERRAL => 700,
      Account::PURCHASE => 3000,
      Account::INVEST_LOCK => 3100,
      Account::INVEST_UNLOCK => 3110,
      Account::INVEST_PROFIT => 3120,
      Account::POINT_EXCHANGE_LOCK => 3200,
      Account::POINT_EXCHANGE_UNLOCK => 3210,
      Account::POINT_EXCHANGE => 3220,
      Account::CC_CHARGE => 4100,
      Account::CC_LOCK => 4200,
      Account::CC_UNLOCK => 4300,
      Account::CC_DISTRIBUTION => 4400,
      Account::CC_MOVE_POOL => 4500,
      Account::POOL_DEPOSIT => 4600,
      Account::POOL_WITHDRAW => 4700,
      Account::CC_ALLOCATION => 4800,
      Account::BET_SUB => 5100,
      Account::BET_RETURN => 5200,
      Account::BET_BONUS => 5300,
      Account::API => 6000,
      Account::LEND => 6100,
      Account::LEND_PROFIT => 6200
  }
  enumerize :reason, in: REASON_CODES, scope: true

  belongs_to :account
  belongs_to :modifiable, polymorphic: true

  scope :history, -> { with_reason(*HISTORY).reverse_order }

  # Use account balance and locked columes as optimistic lock column. If the
  # passed in balance and locked doesn't match associated account's data in
  # database, exception raise. Otherwise the AccountVersion record will be
  # created.
  #
  # TODO: find a more generic way to construct the sql
  def self.optimistically_lock_account_and_create!(balance, locked, attrs)
    attrs = attrs.symbolize_keys

    attrs[:created_at] = Time.now
    attrs[:updated_at] = attrs[:created_at]
    attrs[:fun]        = Account::FUNS[attrs[:fun]]
    attrs[:reason]     = REASON_CODES[attrs[:reason]]
    attrs[:currency]   = Currency.enumerize[attrs[:currency]]

    account_id = attrs[:account_id]
    raise ActiveRecord::ActiveRecordError, "account must be specified" unless account_id.present?

    qmarks       = (['?']*attrs.size).join(',')
    values_array = [qmarks, *attrs.values]
    values       = ActiveRecord::Base.send :sanitize_sql_array, values_array

    select = Account.unscoped.select(values).where(id: account_id, balance: balance, locked: locked).to_sql
    stmt   = "INSERT INTO account_versions (#{attrs.keys.join(',')}) #{select}"

    connection.insert(stmt).tap do |id|
      if id == 0
        record = new attrs
        raise ActiveRecord::StaleObjectError.new(record, "create")
      end
    end
  end

  def detail_template
    if self.detail.nil? || self.detail.empty?
      return ["system", {}]
    end

    [self.detail.delete(:tmp) || "default", self.detail || {}]
  end

  def amount_change
    balance + locked
  end

  def in
    amount_change > 0 ? amount_change : nil
  end

   def out
    amount_change < 0 ? amount_change : nil
  end

  alias :template :detail_template

  def for_cc
    {
        id: id,
        at: created_at.to_i,
        reason: reason,
        currency: currency,
        amount: (balance != 0.0 ? balance : locked).abs,
        fee: fee
    }
  end

  def for_commissions
    {
        id: id,
        at: created_at.to_i,
        reason: reason,
        currency: currency,
        amount: balance,
        fee: fee
    }
  end
end
