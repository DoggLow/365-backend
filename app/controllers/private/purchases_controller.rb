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
        render json: new_purchase.errors.full_messages.join(', '), status: 403
      end
    end

    def prepare
      new_purchase_params = purchase_params
      new_purchase = current_user.purchases.new new_purchase_params
      if new_purchase.valid?
        render json: new_purchase, status: :ok
      else
        render json: new_purchase.errors.full_messages.join(', '), status: 403
      end
    end

    def options
      fiat = params[:fiat] || 'USD'
      currency = params[:currency]
      product_currency = params[:product_currency].downcase
      rate = Price.get_rate(currency, fiat)
      product_rate = Price.get_rate(product_currency, fiat)
      products = Product.where(currency: Currency.find_by_code(product_currency).id)

      render json: {rate: rate, product_rate: product_rate, products: products}.to_json
    end

    private

    def purchase_params
      params.require(:purchase).permit(:product_id, :product_count, :currency)
    end
  end
end

