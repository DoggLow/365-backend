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
  scope :paid_sum, -> (currency) {paid.with_currency(currency).sum(:total)}
  scope :amount_sum, -> (currency) {paid.with_currency(currency).sum(:amount)}

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
    TSFMailer.affiliate(ref, commission).deliver
  end
end
