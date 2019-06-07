class TSFMailer < BaseMailer

  def purchase(purchase)
    @purchase = purchase
    mail to: @purchase.member.email
  end

  def affiliate(purchase, commission)
    @purchase = purchase
    @amount = commission
    mail to: @purchase.member.referrer.email
  end

end
