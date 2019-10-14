module Private
  class CastingsController < BaseController
    layout false

    def index
    end

    def create
      new_casting = current_user.castings.new casting_params

      if new_casting.save
        render json: new_casting, status: :ok
      else
        render json: new_casting.errors.full_messages.join(', '), status: 403
      end
    end

    def history
      history = AccountVersion.where(modifiable_type: Casting.name, member_id: current_user.id).map(&:for_cc)
      render json: history, status: :ok
    end

    private

    def casting_params
      params.require(:casting).permit(:unit, :amount, :currency, :market_id)
    end
  end
end

