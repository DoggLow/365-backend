module Private
  class ReferralsController < BaseController
    layout false

    def index
      render json: current_user.referral_info, status: :ok
    end

    def list
      @type = params[:type]
      referrals = current_user.referrals
      if @type.present?
        referrals = referrals.select { |referral| referral.modifiable_type == @type }
      end
      if params[:page].present? && params[:perPage].present?
        render json: {
            total_length: referrals.length,
            referrals:  Kaminari.paginate_array(referrals).page(params[:page]).per(params[:perPage])
        }
      else
        render json: {
            referrals:  Kaminari.paginate_array(referrals)
        }
      end
    end

    def purchase
      @currency = params[:currency]
      referrals = Referral.all.includes(:member)

      if @currency.present?
        @currency = @currency.downcase
        referrals = referrals.select { |referral| referral.modifiable_type == Purchase.name && referral.currency.include?(@currency) && referral.member.referrer_id == current_user.id }
      else
        referrals = referrals.select { |referral| referral.modifiable_type == Purchase.name && referral.member.referrer_id == current_user.id }
      end
      if params[:page].present? && params[:perPage].present?
        render json: {
            total_length: referrals.length,
            referrals:  Kaminari.paginate_array(referrals).page(params[:page]).per(params[:perPage]).map(&:for_purchase)
        }
      else
        render json: {
            referrals:  Kaminari.paginate_array(referrals).map(&:for_purchase)
        }
      end
    end
  end
end

