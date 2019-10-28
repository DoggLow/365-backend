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
      member_id = params[:id]
      member = Member.enabled.where(id: member_id).first
      currency = 'pld'
      @data = []
      pool = member.fetch_pool(currency)
      if pool.present?
        @data = (pool.castings.done + pool.pool_deposits).sort_by { |t| -t.created_at.to_i }
      end
      @data = Kaminari.paginate_array(@data).page(params[:page]).per(20)
    end

    def accounts
      member_id = params[:id]
      member = Member.enabled.where(id: member_id).first
      @accounts = member.accounts.select { |account| account.currency != 'pld' && account.currency_obj.coin? }
    end

    def dashboard
      member_id = params[:id]
      member = Member.enabled.where(id: member_id).first
      currency = 'pld'
      pool = member.fetch_pool(currency)
      @wallet_balance = 0
      @cc_balance = 0
      @other_balance = 0
      @level = member.cc_level
      @exp = member.exp
      @exp_to_up = CcLevel.to_up(member.exp)
      if pool.present?
        @wallet_balance = member.get_account(currency).balance
        @cc_balance = pool.castings.sum(:distribution)
        @other_balance = pool.balance - @cc_balance
      end

      @info = {
          wallet_balance: @wallet_balance,
          cc_balance: @cc_balance,
          other_balance: @other_balance,
          exp: member.exp,
          level: member.cc_level,
          exp_to_up: CcLevel.to_up(member.exp)
      }
    end
  end
end
