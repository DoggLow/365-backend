class PurchaseMailer < BaseMailer

  def purchase(purchase)
    @purchase = purchase
    @product = purchase.product
    mail to: @purchase.member.email
  end

  def affiliate(referral, purchase)
    @purchase = purchase
    @product = purchase.product
    @referral = referral
    mail to: @purchase.member.referrer.email
  end
end
