module Private
  class PoolsController < BaseController
    layout false

    def deposit
      new_pool_deposit = current_user.pool_deposits.new deposit_params

      if new_pool_deposit.save
        render json: new_pool_deposit, status: :ok
      else
        render json: new_pool_deposit.errors.full_messages.join(', '), status: :bad_request
      end
    end

    def history
      currency = params[:currency]
      if currency.blank?
        render json: 'INVALID_PARAMS', status: :bad_request
      else
        pool = current_user.get_pool(currency)
        data = (pool.castings + pool.pool_deposits).sort_by {|t| -t.created_at.to_i }
        render json: data.map(&:for_pool), status: :ok
      end
    end

    private

    def deposit_params
      params.require(:pool_deposit).permit(:unit, :amount, :currency)
    end
  end
end

