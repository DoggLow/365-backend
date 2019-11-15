class Referral < ActiveRecord::Base
  extend Enumerize

  include Currencible

  enumerize :state, in: {:pending => 100, :paid => 200}, scope: true

  PENDING = 'pending'
  PAID = 'paid'

  belongs_to :modifiable, polymorphic: true
  belongs_to :member

  scope :paid, -> {with_state(:paid)}
  scope :pending, -> {with_state(:pending)}
  scope :paid_sum, -> (currency, type=Trade.name) {paid.with_currency(currency).where(modifiable_type: type).sum(:total)}
  scope :amount_sum, -> (currency, type=Trade.name) {paid.with_currency(currency).where(modifiable_type: type).sum(:amount)}

  def calculate
    return unless state == Referral::PENDING
    return unless modifiable_type == Trade.name

    total = 0.0
    member.referrer_ids.each do |referrer_id|
      begin
        tier = member.get_tier(referrer_id)
        commission = amount * (ENV["REFERRAL_MAX_TIER"].to_i - tier) * ENV["REFERRAL_RATE_STEP"].to_d
        referrer_account = Account.find_by(currency: currency_obj.id, member_id: referrer_id)
        referrer_account.lock!.plus_funds commission, reason: Account::REFERRAL, ref: self
        total += commission
      rescue => e
        Rails.logger.fatal e.inspect
        next
      end
    end

    self.update!(total: total, state: Referral::PAID)
  end


  def calculate_from_purchase(commission, ref)
    return unless state == Referral::PENDING
    return unless modifiable_type == Purchase.name

    referrer_account = member.referrer.get_account(currency)
    referrer_account.lock!.plus_funds commission, reason: Account::PURCHASE, ref: ref

    self.update!(total: commission, state: Referral::PAID)
    PurchaseMailer.affiliate(self, ref).deliver
  end

  def calculate_from_cc_allocation(commission, ref)
    return unless state == Referral::PENDING
    return unless modifiable_type == Pool.name

    total = 0.0
    member.referrer_ids.each do |referrer_id|
      begin
        referrer_account = Account.find_by(currency: currency_obj.id, member_id: referrer_id)
        referrer_account.lock!.plus_funds commission, reason: Account::REFERRAL, ref: ref
        total += commission
      rescue => e
        Rails.logger.fatal e.inspect
        next
      end
    end

    self.update!(total: total, state: Referral::PAID)
  end

  def as_json
    {
        id: id,
        at: created_at.to_i,
        currency: currency,
        amount: amount,
        total: total,
        member: member,
        referrer: member.referrer,
        state: state,
        modifiable: modifiable
    }
  end

  def for_purchase
    mem_id = member.email[0,2] + '*' * 5 + member.email[-2..-1]
    {
        id: id,
        at: created_at.to_i,
        currency: currency,
        amount: amount,
        total: total,
        referee: mem_id,
        state: state,
        modifiable: modifiable
    }
  end

end
