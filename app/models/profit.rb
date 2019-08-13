class Profit < ActiveRecord::Base
  include Currencible

  belongs_to :modifiable, polymorphic: true
  belongs_to :member

  def for_notify
    {
        id: id,
        at: created_at.to_i,
        currency: currency,
        amount: amount,
        fee: fee,
        modifiable: modifiable
    }
  end

end
