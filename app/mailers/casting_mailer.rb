class CastingMailer < BaseMailer

  def bet_accepted(bet)
    @bet = bet
    @date = @bet.created_at
    mail to: @bet.member.email
  end

  def bet_succeed(bet)
    @bet = bet
    @date = @bet.created_at
    mail to: @bet.member.email
  end

  def bet_failed(bet)
    @bet = bet
    @date = @bet.created_at
    mail to: @bet.member.email
  end

  def coin_casting_submitted(casting)
    mail to: casting.member.email
  end

  def pool_deposit_completed(pool_deposit)
    @time = pool_deposit.created_at
    @amount = pool_deposit.org_total
    @fee = pool_deposit.fee
    mail to: pool_deposit.member.email
  end
end
