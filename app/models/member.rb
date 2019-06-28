class Member < ActiveRecord::Base
  extend Enumerize
  acts_as_taggable
  acts_as_reader

  has_many :orders
  has_many :trigger_orders
  has_many :open_loans
  has_many :positions
  has_many :referrals
  has_many :accounts
  has_many :lending_accounts
  has_many :margin_accounts
  has_many :payment_addresses, through: :accounts
  has_many :withdraws
  has_many :fund_sources
  has_many :deposits
  has_many :api_tokens
  has_many :two_factors
  has_many :tickets, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :signup_histories
  has_many :purchases
  has_many :invests
  has_many :point_exchanges

  has_one :id_document
  enumerize :level, in: Level.enumerize

  has_many :authentications, dependent: :destroy

  belongs_to :referrer, class_name: 'Member', foreign_key: :referrer_id
  has_many :referees, class_name: 'Member', foreign_key: :referrer_id
  serialize :referrer_ids, Array

  scope :enabled, -> {where(disabled: false)}

  delegate :activated?, to: :two_factors, prefix: true, allow_nil: true
  delegate :name, to: :id_document, allow_nil: true
  delegate :full_name, to: :id_document, allow_nil: true
  delegate :verified?, to: :id_document, prefix: true, allow_nil: true

  before_validation :sanitize, :generate_sn

  validates :sn, presence: true
  validates :display_name, uniqueness: true, allow_blank: true
  validates :email, email: true, uniqueness: true, allow_nil: true
  validates :ref_id, uniqueness: true, allow_nil: true

  before_create :build_default_id_document
  after_create :touch_accounts
  after_create :touch_margin_accounts
  after_create :touch_lending_accounts
  after_update :resend_activation

  class << self
    def from_auth(auth_hash)
      locate_auth(auth_hash) || locate_email(auth_hash) || create_from_auth(auth_hash)
    end

    def current
      Thread.current[:user]
    end

    def current=(user)
      Thread.current[:user] = user
    end

    def admins
      Figaro.env.admin.split(',')
    end

    def admin_member
      where("email in (?)", admins).first
    end

    def search(field: nil, term: nil)
      result = case field
               when 'email'
                 where('members.email LIKE ?', "%#{term}%")
               when 'phone_number'
                 where('members.phone_number LIKE ?', "%#{term}%")
               when 'name'
                 joins(:id_document).where('id_documents.name LIKE ?', "%#{term}%")
               when 'wallet_address'
                 members = joins(:fund_sources).where('fund_sources.uid' => term)
                 if members.empty?
                   members = joins(:payment_addresses).where('payment_addresses.address' => term)
                 end
                 members
               else
                 all
               end

      result.order(:id).reverse_order
    end

    private

    def locate_auth(auth_hash)
      Authentication.locate(auth_hash).try(:member)
    end

    def locate_email(auth_hash)
      return nil if auth_hash['info']['email'].blank?
      member = find_by_email(auth_hash['info']['email'])
      return nil unless member
      member.add_auth(auth_hash)
      member
    end

    def create_from_auth(auth_hash)
      member = create(email: auth_hash['info']['email'], nickname: auth_hash['info']['nickname'],
                      activated: false)
      member.add_auth(auth_hash)
      member.send_activation if auth_hash['provider'] == 'identity'
      member.set_referrers(auth_hash['ref_id']) if auth_hash['ref_id']
      member
    end
  end


  def create_auth_for_identity(identity)
    self.authentications.create(provider: 'identity', uid: identity.id)
  end

  def trades
    Trade.where('bid_member_id = ? OR ask_member_id = ?', id, id)
  end

  def active_loans
    ActiveLoan.where('demand_member_id = ? OR offer_member_id = ?', id, id)
  end

  def active!
    update activated: true
  end

  def update_password(password)
    identity.update password: password, password_confirmation: password
    send_password_changed_notification
  end

  def admin?
    @is_admin ||= self.class.admins.include?(self.email)
  end

  def add_auth(auth_hash)
    authentications.build_auth(auth_hash).save
  end

  def to_s
    "#{name || email} - #{sn}"
  end

  def gravatar
    "//gravatar.com/avatar/" + Digest::MD5.hexdigest(email.strip.downcase) + "?d=retro"
  end

  def initial?
    name? and !name.empty?
  end

  def get_ref_id
    if self.ref_id.blank?
      begin
        self.ref_id = ROTP::Base32.random_base32(8).upcase
      end while Member.where(:ref_id => self.ref_id).any?

      self.save!
    end
    self.ref_id
  end

  def set_referrers(ref_id)
    referrer = Member.find_by_ref_id(ref_id)
    return if referrer.blank?

    self.referrer_id = referrer.id
    self.save!

    set_referrer_ids
  end

  def set_referrer_ids
    referrer_ids = self.recur_referrers.map &:id
    self.update(referrer_ids: referrer_ids)
  end

  # Same function as 'referrers', but used recursive with only referrer_id.
  # You can test speed with referral task.
  def recur_referrers
    if referrer_id.blank?
      []
    else
      [referrer] + referrer.recur_referrers
    end
  end

  def referrers
    if referrer_ids.blank?
      []
    else
      Member.where(id: referrer_ids)
    end
  end

  # Same function as 'all_referees', but used recursive with only referees
  # You can test speed with referral task
  def recur_all_referees
    if referees.blank?
      []
    else
      recur_referees = [referees]
      referees.each do |referee|
        recur_referees << referee.recur_all_referees
      end
      recur_referees.flatten!
    end
  end

  def all_referees
    Member.where("referrer_ids LIKE ?", "% #{id}\n%")
    # Member.all.select{ |m| m.referrer_ids.include? id } # same with above line , but slow in leafs
  end

  def get_tier(member_id)
    tier = referrer_ids.index(member_id)
    tier.nil? ? -1 : tier + 1
  end

  def calculate_trade_volume(trade_unit, trade_list)
    trade_amount = Hash.new {|h, k| h[k] = 0}
    trade_list.each do |trade|
      quote_unit = trade.market.bid["currency"]
      trade_amount[quote_unit] += trade.funds
    end
    total_volume = 0
    trade_amount.each do |key, value|
      if key == trade_unit
        total_volume += value
      else
        total_volume += Global.estimate(key, trade_unit, value)
      end
    end
    total_volume
  end

  def calculate_level
    total_trade_volume = calculate_trade_volume(level_obj.trade['currency'], trades.d30)

    level = 0
    Level.all.each do |level_config|
      unless (total_trade_volume >= level_config.trade['amount']) && (fee_account.balance >= level_config.holding['amount'])
        level = level_config.id - 1
        break
      end
    end

    self.level = level
    self.save!
  end

  def level_obj
    Level.find level
  end

  def get_trade_fee(currency, amount, is_maker)
    fee_config = is_maker ? level_obj.maker : level_obj.taker

    if commission_status
      fee = amount * fee_config['holding'] / 100
      fee_estimation = Global.estimate(currency, level_obj.holding['currency'], fee)
      if fee_estimation != 0 && fee_account.balance > fee_estimation
        return [0, fee_estimation]
      end
    end

    fee = amount * fee_config['normal'] / 100
    [fee, 0]
  end

  def fee_account
    get_account(level_obj.holding['currency'])
  end

  def get_account(currency)
    account = accounts.with_currency(currency.to_sym).first

    if account.nil?
      touch_accounts
      account = accounts.with_currency(currency.to_sym).first
    end

    account
  end

  alias :get_main_account :get_account
  alias :ac :get_account

  def get_margin_account(currency)
    margin_account = margin_accounts.with_currency(currency.to_sym).first

    if margin_account.nil?
      touch_margin_accounts
      margin_account = margin_accounts.with_currency(currency.to_sym).first
    end

    margin_account
  end

  def get_lending_account(currency)
    lending_account = lending_accounts.with_currency(currency.to_sym).first

    if lending_account.nil?
      touch_lending_accounts
      lending_account = lending_accounts.with_currency(currency.to_sym).first
    end

    lending_account
  end

  def touch_accounts
    less = Currency.codes - self.accounts.map(&:currency).map(&:to_sym)
    less.each do |code|
      self.accounts.create(currency: code, balance: 0, locked: 0)
    end
  end

  def touch_margin_accounts
    less = Currency.coin_codes - self.margin_accounts.map(&:currency).map(&:to_sym)
    less.each do |code|
      self.margin_accounts.create(currency: code, balance: 0, locked: 0)
    end
  end

  def touch_lending_accounts
    less = Currency.coin_codes - self.lending_accounts.map(&:currency).map(&:to_sym)
    less.each do |code|
      self.lending_accounts.create(currency: code, balance: 0, locked: 0)
    end
  end

  def get_margin_info(quote_unit)

    total_margin = 0
    margin_accounts.non_zero.each do |margin_account|
      base_unit = margin_account.currency_obj.code
      total_margin += margin_account.balance * Market.last_price(base_unit, quote_unit)
    end

    total_borrowed = 0
    unrealized_lending_fee = 0
    realized_lending_fee = 0
    unrealized_pnl = 0

    positions.open.each do |position|
      unrealized_pnl += position.unrealized_pnl
      realized_lending_fee += position.lending_fees
      unrealized_lending_fee += position.unrealized_lending_fee
    end

    ActiveLoan.where(demand_member_id: id, state: 100).each do |active_loan| # ActiveLoan::WAIT
      base_unit = active_loan.currency
      price = Market.last_price(base_unit, quote_unit)
      total_borrowed += active_loan.amount * price
    end

    net_value = total_margin - unrealized_lending_fee + unrealized_pnl

    current_margin = if total_borrowed > 0
                       net_value / total_borrowed * 100
                     else
                       100
                     end

    {
        total_margin: total_margin,
        unrealized_pnl: unrealized_pnl,
        unrealized_lending_fee: -unrealized_lending_fee,
        net_value: net_value,
        total_borrowed: total_borrowed,
        current_margin: current_margin,
        quote_unit: quote_unit
    }
  end

  def sync_margin_info(quote_unit)
    margin_info = get_margin_info(quote_unit)
    margin_info[:current_margin]
  end

  def force_liquidation
    positions.open.each {|position| position.complete_close}
  end

  def all_ref_commissions
    all_commissions = {}
    Currency.all.each do |currency|
      commissions = referrals.blank? ? 0 : referrals.paid_sum(currency.code)
      all_commissions[currency.code] = commissions
    end
    all_commissions
  end

  def ref_uplines # TODO
    uplines = []
    referrers.each do |member|
      tier = member.referrer.blank? ? 1 : get_tier(member.id) + 1
      commission = (ENV["REFERRAL_MAX_TIER"].to_i - tier) * ENV["REFERRAL_RATE_STEP"].to_d
      rewards = {}
      Currency.all.each do |currency|
        amount = referrals.blank? ? 0 : referrals.amount_sum(currency.code)
        rewards[currency.code.upcase] = amount * commission if amount > 0
      end
      if member.referrer.blank?
        uplines << {parent: email, child: referrer.email, attributes: rewards}
      else
        uplines << {parent: member.email, child: member.referrer.email, attributes: rewards}
      end
    end
    uplines
  end

  def ref_downlines
    all_rewards = {}
    downlines = []
    all_referees.each do |referee|
      tier = referee.get_tier(self.id)
      commission = (ENV["REFERRAL_MAX_TIER"].to_i - tier) * ENV["REFERRAL_RATE_STEP"].to_d
      commissions = {}
      Currency.all.each do |currency|
        amount = referee.referrals.blank? ? 0 : referee.referrals.amount_sum(currency.code)
        paid = amount * commission
        commissions[currency.code.upcase] = paid if amount > 0
        all_rewards[currency.code] = all_rewards[currency.code].blank? ? paid : all_rewards[currency.code] + paid
      end
      downlines << {parent: referee.referrer.email, child: referee.email, attributes: commissions} # TODO
    end
    [all_rewards, downlines]
  end

  def referral_info
    all_rewards, downlines = ref_downlines
    {
        referral_id: get_ref_id,
        all_commissions: all_ref_commissions,
        all_rewards: all_rewards,
        uplines: ref_uplines,
        downlines: downlines
    }

  end

  def ref_uplines_admin
    uplines = [{parent: referrer.email, name: email, attributes: nil}]
    referrers.each do |member|
      tier = get_tier(member.id)
      commission = (ENV["REFERRAL_MAX_TIER"].to_i - tier) * ENV["REFERRAL_RATE_STEP"].to_d
      rewards = {}
      Currency.all.each do |currency|
        amount = referrals.blank? ? 0 : referrals.amount_sum(currency.code)
        rewards[currency.code.upcase] = amount * commission if amount > 0
      end
      parent = member.referrer.blank? ? nil : member.referrer.email
      uplines << {parent: parent, name: member.email, attributes: rewards}
    end
    uplines
  end

  def ref_downlines_admin
    downlines = [{parent: nil, name: email, attributes: nil}]
    all_referees.each do |referee|
      tier = referee.get_tier(self.id)
      commission = (ENV["REFERRAL_MAX_TIER"].to_i - tier) * ENV["REFERRAL_RATE_STEP"].to_d
      commissions = {}
      Currency.all.each do |currency|
        amount = referee.referrals.blank? ? 0 : referee.referrals.amount_sum(currency.code)
        paid = amount * commission
        commissions[currency.code.upcase] = paid if amount > 0
      end
      downlines << {parent: referee.referrer.email, name: referee.email, attributes: commissions}
    end
    downlines
  end

  def identity
    authentication = authentications.find_by(provider: 'identity')
    authentication ? Identity.find(authentication.uid) : nil
  end

  def auth(name)
    authentications.where(provider: name).first
  end

  def auth_with?(name)
    auth(name).present?
  end

  def remove_auth(name)
    identity.destroy if name == 'identity'
    auth(name).destroy
  end

  def send_activation
    Token::Activation.create(member: self)
  end

  def send_password_changed_notification
    MemberMailer.reset_password_done(self.id).deliver

    if sms_two_factor.activated?
      sms_message = I18n.t('sms.password_changed', email: self.email)
      AMQPQueue.enqueue(:sms_notification, phone: phone_number, message: sms_message)
    end
  end

  def unread_comments
    ticket_ids = self.tickets.open.collect(&:id)
    if ticket_ids.any?
      Comment.where(ticket_id: [ticket_ids]).where("author_id <> ?", self.id).unread_by(self).to_a
    else
      []
    end
  end

  def app_two_factor
    two_factors.by_type(:app)
  end

  def sms_two_factor
    two_factors.by_type(:sms)
  end

  def as_json(options = {})
    super(options).merge({
                             "name" => self.name,
                             "app_activated" => self.app_two_factor.activated?,
                             "sms_activated" => self.sms_two_factor.activated?,
                             "memo" => self.id
                         })
  end

  private

  def sanitize
    self.email.try(:downcase!)
  end

  def generate_sn
    self.sn and return
    begin
      self.sn = "PEA#{ROTP::Base32.random_base32(8).upcase}TIO"
    end while Member.where(:sn => self.sn).any?
  end

  def build_default_id_document
    build_id_document
    true
  end

  def resend_activation
    self.send_activation if self.email_changed?
  end

end
