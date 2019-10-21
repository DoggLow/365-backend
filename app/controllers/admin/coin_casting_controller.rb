module Admin
  class CoinCastingController < BaseController
    # load_and_authorize_resource

    def index
      @members = Member.page params[:page]
    end

    def cc_history
      @data = AccountVersion.where(modifiable_type: Casting.name, member_id: params[:id])
      @data = Kaminari.paginate_array(@data).page(params[:page]).per(20)
    end

    def pool_history
      currency = 'pld'
      @pool = current_user.get_pool(currency)
      @data = (@pool.castings.done + @pool.pool_deposits).sort_by { |t| -t.created_at.to_i }
      @data = Kaminari.paginate_array(@data).page(params[:page]).per(20)
    end

    def accounts
      @accounts = current_user.accounts.select { |account| account.currency != 'pld' && account.currency_obj.coin? }
    end

    def dashboard
      currency = 'pld'
      pool = current_user.get_pool(currency)
      @wallet_balance = current_user.get_account(currency).balance
      @cc_balance = pool.castings.sum(:distribution)
      @other_balance = pool.balance - @cc_balance
      @info = {
          wallet_balance: @wallet_balance,
          cc_balance: @cc_balance,
          other_balance: @other_balance
      }
    end
  end
end
