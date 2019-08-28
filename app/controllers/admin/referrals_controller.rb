module Admin
  class ReferralsController < BaseController
    # load_and_authorize_resource

    def index
      @search_field = params[:search_field]
      @search_term = params[:search_term]
      @members = Member.search(field: @search_field, term: @search_term).page params[:page]
    end

    def show
      @member = Member.find params[:id]
      rewards = @member.all_rewards
      @ref_summaries = []
      Currency.all.each do |currency|
        @ref_summaries << {currency: currency.code.upcase, rewards: rewards[currency.code]}
      end
    end

    def tree
      @type = params[:type]
      @member = Member.find params[:id]
      @data = @type == 'referrers' ? @member.ref_uplines_admin : @member.ref_downlines(true)
    end
  end
end
