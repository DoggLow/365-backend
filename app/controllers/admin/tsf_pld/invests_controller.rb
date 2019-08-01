module Admin
  module TsfPld
    class InvestsController < BaseController
      # load_and_authorize_resource

      def index
        @units = [250000, 700000, 1200000]

        @created_at = params[:date]
        @unit = params[:unit]
        @total_profit = params[:total_profit]
        @percent = params[:percent]

        @invests = Invest.where(aasm_state: 'pending')
        if @unit.present?
          @invests = @invests.where(unit: @unit)
        end
        if @created_at.present?
          @invests = @invests.with_year_and_month(@created_at)
        end

        if @total_profit.present? && @percent.present?
          @total = @total_profit.to_d * @percent.to_d / 100 * PurchaseOption.get('tsfp_usd')
        else
          @total = 0
        end

        if params[:commit] == 'Check' || params[:commit] == 'Confirm'
          @count = @invests.sum(:count)
        else
          @count = 0
        end
        @profit = @count == 0 ? 0 : @total / @count

        if params[:commit] == 'Confirm' && @profit != 0
          @invests.each do |invest|
            invest.update!(profit: @profit * invest.count, aasm_state: :processing)
          end
        end
      end
    end
  end
end
