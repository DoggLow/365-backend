class ExpMailer < BaseMailer

  def increase(member_id, reason, data)
    @data = data
    @amount = @data.amount
    @reason = reason
    @date = @data.created_at
    set_mail(member_id)
  end

  def set_mail(member_id)
    @member = Member.find member_id
    mail to: @member.email
  end
end

