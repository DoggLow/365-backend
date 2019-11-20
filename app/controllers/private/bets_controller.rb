module Private
  class BetsController < BaseController
    layout false

    def index
      @bets = current_user.bets
      render json: {
          total_length: @bets.length,
          bets: @bets.page(params[:page]).per(params[:perPage])
      }
    end

    def create
      new_evenodd = current_user.bets.new credit: params[:credit], fee: params[:fee], even_odd: params[:even_odd]
      if new_evenodd.save
        new_evenodd.make_payment
        render json: new_evenodd, status: :ok
      else
        render json: new_evenodd.errors.full_messages.join(', '), status: :bad_request
      end
    end

    def bet_params
      params.require(:casting).permit(:unit, :amount, :currency, :market_id)
    end

    def test
      date = DateTime.parse('2019-11-21 01:00:00')
      result = Bet.task_bet(0, date)
      result = 0
    end

    def fees
      if params[:credit]
        render json: current_user.withdraws.where(currency: params[:currency])
      else
        render json: current_user.withdraws
      end
    end

  end
end
