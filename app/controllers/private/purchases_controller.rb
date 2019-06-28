module Private
  class PurchasesController < BaseController
    layout false

    def index
      render json: current_user.purchases
    end

    def create
      new_purchase = current_user.purchases.new purchase_params

      if new_purchase.save
        render json: new_purchase, status: :ok
      else
        head :bad_request
      end
    end

    def prepare
      new_purchase_params = purchase_params
      new_purchase_params[:unit] = PurchaseOption.get(lot_unit)

      new_purchase = current_user.purchases.new new_purchase_params
      if new_purchase.valid?
        render json: new_purchase, status: :ok
      else
        head :bad_request
      end
    end

    def options
      currency = params[:currency]
      price = Price.latest_price_3rd_party(currency, 'USD')
      render json: {price: price, tsf_price: PurchaseOption.get(tsf_usd), lot_unit: PurchaseOption.get(lot_unit)}.to_json
    end

    private

    def purchase_params
      params.require(:purchase).permit(:currency, :unit, :amount, :currency, :fee)
    end
  end
end

