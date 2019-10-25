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
      @data = []
      @pool = current_user.fetch_pool(currency)
      if @pool.present?
        @data = (@pool.castings.done + @pool.pool_deposits).sort_by { |t| -t.created_at.to_i }
      end
      @data = Kaminari.paginate_array(@data).page(params[:page]).per(20)
    end

    def accounts
      @accounts = current_user.accounts.select { |account| account.currency != 'pld' && account.currency_obj.coin? }
    end

    def dashboard
      currency = 'pld'
      pool = current_user.fetch_pool(currency)
      @wallet_balance = 0
      @cc_balance = 0
      if @pool.present?
        @wallet_balance = current_user.get_account(currency).balance
        @cc_balance = pool.castings.sum(:distribution)
      end
      @other_balance = pool.balance - @cc_balance
      @info = {
          wallet_balance: @wallet_balance,
          cc_balance: @cc_balance,
          other_balance: @other_balance,
          exp: current_user.exp,
          level: current_user.cc_level,
          exp_to_up: CcLevel.to_up(current_user.exp)
      }
    end
  end
end
