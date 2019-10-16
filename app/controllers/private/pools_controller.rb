module Private
  class PoolsController < BaseController
    layout false

    def info
      currency = params[:currency] || 'pld'
      if currency.blank?
        render json: 'INVALID_PARAMS', status: :bad_request
      else
        pool = current_user.get_pool(currency)
        wallet_balance = current_user.get_account(currency).balance
        cc_balance = pool.castings.sum(:distribution)
        other_balance = pool.balance - cc_balance
        info = {
            wallet_balance: wallet_balance,
            cc_balance: cc_balance,
            other_balance: other_balance
        }
        render json: info, status: :ok
      end
    end

    def deposit
      new_pool_deposit = current_user.pool_deposits.new deposit_params

      if new_pool_deposit.save
        render json: new_pool_deposit, status: :ok
      else
        render json: new_pool_deposit.errors.full_messages.join(', '), status: :bad_request
      end
    end

    def withdraw
      new_pool_withdraw = current_user.pool_withdraws.new withdraw_params

      if new_pool_withdraw.save
        render json: new_pool_withdraw, status: :ok
      else
        render json: new_pool_withdraw.errors.full_messages.join(', '), status: :bad_request
      end
    end

    def history
      currency = params[:currency] || 'pld'
      if currency.blank?
        render json: 'INVALID_PARAMS', status: :bad_request
      else
        pool = current_user.get_pool(currency)
        data = (pool.castings.done + pool.pool_deposits).sort_by {|t| -t.created_at.to_i }
        render json: data.map(&:for_pool), status: :ok
      end
    end

    private

    def deposit_params
      params.require(:pool_deposit).permit(:unit, :amount, :currency)
    end

    def withdraw_params
      params.require(:pool_withdraw).permit(:amount, :currency, :modifiable_id, :modifiable_type)
    end
  end
end

