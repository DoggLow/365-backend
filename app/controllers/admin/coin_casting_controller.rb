module Admin
  class CoinCastingController < BaseController
    # load_and_authorize_resource

    def index
      @pool_sum = Pool.balance_sum('pld')
      @cc_sum = Casting.done.distribution_sum

      sales = []
      commissions = []
      Currency.coins.each do |currency|
        sale = AccountVersion.where(reason: 4100, currency: currency.id).sum(:balance).abs
        sales << "#{sale} #{currency.code.upcase}" if sale > 0.0
        commission = AccountVersion.where(reason: 4800, currency: currency.id).sum(:balance)
        commissions << "#{commission} #{currency.code.upcase}" if commission > 0.0
      end
      @all_sales = sales.join(', ')
      @all_commission = commissions.join(', ')

      @search_field = params[:search_field]
      @search_term = params[:search_term]
      @members = Member.search(field: @search_field, term: @search_term)
      @members = @members.includes(:pools)
      @members = @members.select {|member| member.pools.present?}
      @members = Kaminari.paginate_array(@members).page(params[:page]).per(20)
    end

    def cc_history
      #@data = AccountVersion.where(modifiable_type: Casting.name, member_id: params[:id]).sort_by {|t| -t.created_at.to_i }
      @data = AccountVersion.where('member_id = ? AND (modifiable_type = ? OR reason = 4800 OR (modifiable_type = ? AND reason = 700))', params[:id], Casting.name, Pool.name)
                  .sort_by {|t| -t.created_at.to_i }
      #@data = AccountVersion.where('member_id = ? AND (reason > 4000 AND reason < 4600)', params[:id]).sort_by {|t| -t.created_at.to_i }
      @data = Kaminari.paginate_array(@data).page(params[:page]).per(20)
    end

    def pool_history
      member = Member.find_by(id: params[:id])
      currency = 'pld'
      @data = []
      pool = member.fetch_pool(currency)
      if pool.present?
        @data = (pool.castings.done + pool.pool_deposits).sort_by { |t| -t.created_at.to_i }
      end
      @data = Kaminari.paginate_array(@data).page(params[:page]).per(20)
    end

    def commissions
      member = Member.find_by(id: params[:id])
      @commissions = AccountVersion.where(reason: 4800, member_id: member.id).sort_by {|t| -t.created_at.to_i }
      #@commissions = AccountVersion.where('member_id = ? AND (reason = 4800 OR ((modifiable_type = ? OR modifiable_type = ?) AND reason = 700))', current_user.id, Casting.name, Pool.name)
      #              .sort_by {|t| -t.created_at.to_i }
      @commissions = Kaminari.paginate_array(@commissions).page(params[:page]).per(20)
    end

    def accounts
      member = Member.find_by(id: params[:id])
      @accounts = member.accounts.select { |account| account.currency != 'pld' && account.currency != 'tsf' && account.currency_obj.coin? }
    end

    def dashboard
      member = Member.find_by(id: params[:id])
      currency = 'pld'
      pool = member.fetch_pool(currency)
      @wallet_balance = 0
      @cc_balance = 0
      @other_balance = 0
      @share = 0.0
      if pool.present?
        @wallet_balance = member.get_account(currency).balance
        @cc_balance = pool.castings.done.sum(:distribution)
        @other_balance = pool.balance - @cc_balance
      end

      @info = {
          wallet_balance: @wallet_balance,
          cc_balance: @cc_balance,
          other_balance: @other_balance,
          exp: member.exp,
          level: member.cc_level,
          exp_to_up: CcLevel.to_up(member.exp),
          total: Global.pool_sum(1),
          pools: member.all_pool_share
      }

      if Global.pool_sum(1) > 0
        @share =((@cc_balance + @other_balance) / Global.pool_sum(1) * 100).round(2)
      end
    end
  end
end
