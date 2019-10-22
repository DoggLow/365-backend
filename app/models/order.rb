class Order < ActiveRecord::Base
  extend Enumerize

  enumerize :bid, in: Currency.enumerize
  enumerize :ask, in: Currency.enumerize
  enumerize :currency, in: Market.enumerize, scope: true
  enumerize :state, in: {:wait => 100, :done => 200, :cancel => 0, :fail => -100}, scope: true

  ORD_TYPES = %w(market limit)
  enumerize :ord_type, in: ORD_TYPES, scope: true

  SOURCES = %w(Web APIv2 Position debug)
  enumerize :source, in: SOURCES, scope: true

  before_validation :fix_number_precision, on: :create

  validates_presence_of :ord_type, :volume, :origin_volume, :locked, :origin_locked
  validates_numericality_of :origin_volume, :greater_than => 0

  validates_numericality_of :price, greater_than: 0, allow_nil: false,
                            if: "ord_type == 'limit'"
  validate :market_order_validations, if: "ord_type == 'market'"

  after_create :increase_exp

  WAIT = 'wait'
  DONE = 'done'
  CANCEL = 'cancel'
  FAIL = 'fail'

  ATTRIBUTES = %w(id at market kind price state state_text volume origin_volume)

  belongs_to :member
  attr_accessor :total

  belongs_to :trigger_order

  has_many :active_loans

  scope :done, -> {with_state(:done)}
  scope :active, -> {with_state(:wait)}
  scope :position, -> {group("price").pluck(:price, 'sum(volume)')}
  scope :best_price, ->(currency) {where(ord_type: 'limit').active.with_currency(currency).matching_rule.position}
  scope :h24, -> {where("created_at > ?", 24.hours.ago)}

  def funds_used
    origin_locked - locked
  end

  def config
    @config ||= Market.find(currency)
  end

  def strike(trade, is_maker_option = nil)
    raise "Cannot strike on cancelled or done order. id: #{id}, state: #{state}" unless state == Order::WAIT

    is_maker = is_maker_option.nil? ? member_id == trade.maker : is_maker_option

    real_sub, add = get_account_changes trade
    real_fee, real_fee_estimation = member.get_trade_fee(expect_account.currency, add, is_maker)
    real_add = add - real_fee

    if self.trigger_order_id.blank? && self.source != 'Position'
      # normal order
      hold_account.unlock_and_sub_funds real_sub, locked: real_sub, reason: Account::STRIKE_SUB, ref: trade
      expect_account.plus_funds real_add, fee: real_fee, reason: Account::STRIKE_ADD, ref: trade
      if real_fee_estimation != 0
        member.fee_account.sub_funds real_fee_estimation, fee: 0, reason: Account::STRIKE_ADD, ref: trade
      end
    else
      # margin order
      hold_margin_account.unlock_and_sub_borrowed real_sub, locked: real_sub, reason: MarginAccount::STRIKE_SUB, ref: trade
      expect_margin_account.plus_borrowed real_add - real_fee, reason: MarginAccount::STRIKE_ADD, ref: trade
    end

    self.volume -= trade.volume
    self.locked -= real_sub
    self.funds_received += add
    self.trades_count += 1

    if volume.zero?
      self.state = Order::DONE

      # unlock not used funds
      if self.trigger_order_id.blank? && self.source != 'Position'
        # normal order
        hold_account.unlock_funds locked,
                                  reason: Account::ORDER_FULLFILLED, ref: trade unless locked.zero?
      else
        # margin order
        hold_margin_account.unlock_borrowed locked,
                                            reason: MarginAccount::ORDER_FULLFILLED, ref: trade unless locked.zero?
      end
    elsif ord_type == 'market' && locked.zero?
      # partially filled market order has run out its locked fund
      self.state = Order::CANCEL
    end

    self.save!

    if false # member.referrer_ids.present?
      if real_fee_estimation != 0
        ref_amount = real_fee_estimation
        ref_currency = member.fee_account.currency
      else
        ref_amount = real_fee
        ref_currency = expect_account.currency
      end
      create_or_update_referral(ref_amount, ref_currency, trade.id)
    end

    member.increase_exp(ExpLog::TRADE, ref: trade)
    member.increase_exp(ExpLog::BUY_PLD, ref: trade) if expect_account.currency == 'pld'

    create_or_update_position(trade) if trigger_order || source == 'Position'
  end

  def increase_exp
    reason = type == 'OrderBid' ? ExpLog::BUY : ExpLog::SELL
    member.increase_exp(reason, ref: self)
  end

  def kind
    type.underscore[-3, 3]
  end

  def self.head(currency)
    active.with_currency(currency.downcase).matching_rule.first
  end

  def at
    created_at.to_i
  end

  def market_obj
    Market.find currency
  end

  def market
    currency
  end

  def for_notify
    {
        id: id,
        market: market,
        kind: kind,
        at: at,
        price: price,
        volume: volume,
        origin_volume: origin_volume,
        ord_type: ord_type,
        state: state
    }
  end

  def to_matching_attributes
    {id: id,
     market: market,
     type: type[-3, 3].downcase.to_sym,
     ord_type: ord_type,
     volume: volume,
     price: price,
     locked: locked,
     timestamp: created_at.to_i}
  end

  def fix_number_precision
    self.price = config.fix_number_precision(:bid, price.to_d) if price

    if volume
      self.volume = config.fix_number_precision(:ask, volume.to_d)
      self.origin_volume = origin_volume.present? ? config.fix_number_precision(:ask, origin_volume.to_d) : volume
    end
  end

  private

  def market_order_validations
    errors.add(:price, 'must not be present') if price.present?
  end

  FUSE = '0.9'.to_d

  def estimate_required_funds(price_levels)
    required_funds = Account::ZERO
    expected_volume = volume

    start_from, _ = price_levels.first
    filled_at = start_from

    until expected_volume.zero? || price_levels.empty?
      level_price, level_volume = price_levels.shift
      filled_at = level_price

      v = [expected_volume, level_volume].min
      required_funds += yield level_price, v
      expected_volume -= v
    end

    raise "Market is not deep enough" unless expected_volume.zero?
    raise "Volume too large" if (filled_at - start_from).abs / start_from > FUSE

    required_funds
  end

  def create_or_update_referral(amount, currency, trade_id)
    Referral.create(
        member: member,
        currency: currency,
        amount: amount,
        modifiable_id: trade_id,
        modifiable_type: Trade.name,
        state: Referral::PENDING
    )
  end

  def create_or_update_position(trade)
    position = Position.find_or_create_by(member_id: member_id, currency: market_obj.code)
    position.update(trade, self.source == 'Position')
  end
end
