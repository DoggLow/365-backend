class TSFMailer < BaseMailer

  def point_exchange_submitted(point_exchange)
    @point_exchange = point_exchange
    mail to: @point_exchange.member.email
  end

  def point_exchange_done(point_exchange)
    @point_exchange = point_exchange
    mail to: @point_exchange.member.email
  end
end
