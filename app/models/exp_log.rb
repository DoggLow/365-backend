class ExpLog < ActiveRecord::Base
  extend Enumerize

  UNKNOWN = :unknown
  DAILY_ALL = :daily_all
  LOGIN = :login
  CC = :cc
  BUY = :buy
  SELL = :sell
  TRADE = :trade
  REFEREE_KYC = :referee_kyc
  REFEREE_CC = :referee_cc
  BUY_PLD = :buy_pld
  CC_30 = :cc_30
  CC_TOTAL_10K = :cc_10_k
  CC_TOTAL_30K = :cc_30_k
  CC_TOTAL_100K = :cc_100_k

  REASON_CODES = {
      UNKNOWN => 0,
      DAILY_ALL => 100,
      LOGIN => 110,
      CC => 120,
      BUY => 130,
      SELL => 140,
      TRADE => 150,
      REFEREE_KYC => 210,
      REFEREE_CC => 220,
      BUY_PLD => 300,
      CC_30 => 310,
      CC_TOTAL_10K => 410,
      CC_TOTAL_30K => 420,
      CC_TOTAL_100K => 430
  }
  DAILY_ACTIONS = [ExpLog::LOGIN, ExpLog::CC, ExpLog::BUY, ExpLog::SELL, ExpLog::TRADE]
  TOTAL_ACTIONS = [ExpLog::CC_TOTAL_10K, ExpLog::CC_TOTAL_30K, ExpLog::CC_TOTAL_100K]

  enumerize :reason, in: REASON_CODES, scope: true

  belongs_to :member
  belongs_to :modifiable, polymorphic: true

  scope :today, lambda { where('DATE(created_at) = ?', Date.today)}

  def for_api
    {
        id: id,
        at: created_at.to_i,
        reason: reason,
        amount: amount,
        value: value
    }
  end
end
