module Private
  class BetsController < BaseController
    layout false

    def index
      @bets = current_user.bets
      render json: {
          total: @bets.length,
          data: @bets.page(params[:page]).per(params[:perPage]).map(&:for_notify)
      }
    end

    def create
      new_bet = current_user.bets.new unit: params[:unit], amount: params[:amount], expectancy: params[:expectancy]
      if new_bet.save
        render json: new_bet, status: :ok
      else
        render json: new_bet.errors.full_messages.join(', '), status: :bad_request
      end
    end
  end
end
