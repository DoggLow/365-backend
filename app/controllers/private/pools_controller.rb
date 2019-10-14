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
    end

    private

    def deposit_params
      params.require(:pool_deposit).permit(:unit, :amount, :currency)
    end
  end
end

