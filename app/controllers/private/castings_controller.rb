module Private
  class CastingsController < BaseController
    layout false

    def index
    end

    def info
      currency = params[:currency] || 'pld'
      if currency.blank?
        render json: 'INVALID_PARAMS', status: :bad_request
      else
        pool = current_user.fetch_pool(currency)
        wallet_balance = 0
        cc_balance = 0
        other_balance = 0
        if pool.present?
          wallet_balance = current_user.get_account(currency).balance
          cc_balance = pool.castings.done.sum(:distribution)
          other_balance = pool.balance - cc_balance
        end
        info = {
            wallet_balance: wallet_balance,
            cc_balance: cc_balance,
            other_balance: other_balance,
            exp: current_user.exp,
            level: current_user.cc_level,
            exp_to_up: CcLevel.to_up(current_user.exp)
        }
        render json: info, status: :ok
      end
    end

    def create
      new_casting = current_user.castings.new casting_params

      if new_casting.save
        render json: new_casting, status: :ok
      else
        render json: new_casting.errors.full_messages.join(', '), status: :bad_request
      end
    end

    def history
      history = AccountVersion.where(modifiable_type: Casting.name, member_id: current_user.id).sort_by {|t| -t.created_at.to_i }.map(&:for_cc)
      render json: history, status: :ok
    end

    def exp_history
      render json: current_user.exp_logs.map(&:for_api), status: :ok
    end

    private

    def casting_params
      params.require(:casting).permit(:unit, :amount, :currency, :market_id)
    end
  end
end

