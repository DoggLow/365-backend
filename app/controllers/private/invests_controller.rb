module Private
  class InvestsController < BaseController

    before_action :auth_activated!
    before_action :auth_verified!
    # before_action :two_factor_activated!
    before_action :two_factor_auth_passed!,    only: :create

    def index
      render json: current_user.invests.map(&:for_notify)
    end

    def create
      @invest = current_user.invests.new invest_params

      # if two_factor_auth_verified?
        if @invest.save
          render nothing: true
        else
          render text: @invest.errors.full_messages.join(', '), status: 403
        end
      # else
      #   render text: I18n.t('private.withdraws.create.two_factors_error'), status: 403
      # end
    end

    private

    def invest_params
      params.require(:invest).permit(:member_id, :currency, :unit, :count)
    end

  end
end
