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

  def point_exchange_submitted(point_exchange)
    @point_exchange = point_exchange
    mail to: @point_exchange.member.email
  end

  def point_exchange_done(point_exchange)
    @point_exchange = point_exchange
    mail to: @point_exchange.member.email
  end

end
