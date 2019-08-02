module Admin
  module TsfPld
    class PurchasesController < BaseController
      load_and_authorize_resource

      def index
        @currency = params[:currency]
        @purchases = @purchases.includes(:product)
        if params[:format] == 'csv'
          export(@purchases)
        else # search
          if @currency.present?
            @purchases = @purchases.select { |purchase| purchase.product.currency.upcase == @currency }
          end
          @purchases = Kaminari.paginate_array(@purchases).page(params[:page]).per(20)
        end
      end

      private

      def export(purchases)
        respond_to do |format|
          format.html
          format.csv { send_data purchases.to_csv, filename: "purchases-#{Date.today}.csv" }
        end
      end
    end
  end
end
