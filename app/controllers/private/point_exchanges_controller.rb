module Private
  class PointExchangesController < BaseController

    before_action :auth_activated!
    before_action :auth_verified!
    before_action :two_factor_activated!

    def index
      render json: current_user.invests
    end

    def create
      @point_exchange = current_user.point_exchanges.new(point_exchange_params)

      if two_factor_auth_verified?
        if @point_exchange.save
          @point_exchange.submit!
          render json: @point_exchange, status: :ok
        else
          render text: @point_exchange.errors.full_messages.join(', '), status: 403
        end
      else
        render text: I18n.t('private.point_exchanges.create.two_factors_error'), status: 403
      end
    end

    private

    def point_exchange_params
      params.require(:point_exchange).permit(:member_id, :currency, :amount, :fee)
    end

  end
end
