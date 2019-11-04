class ExpMailer < BaseMailer

  def increase(member, reason, amount)
    @amount = amount
    @reason = reason
    @time = Time.now
    mail to: member.email
  end
end

