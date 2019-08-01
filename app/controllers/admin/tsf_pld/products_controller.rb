module Admin
  module TsfPld
    class ProductsController < BaseController
      load_and_authorize_resource

      def index
        @products = @products.order(:id)
      end

      def new
      end

      def create
        if @product.save
          redirect_to admin_tsf_pld_products_path
        else
          render :new
        end
      end

      def show
      end

      def update
        if @product.update_attributes product_params
          flash[:info] = I18n.t('admin.settings.products.update.success')
          redirect_to admin_tsf_pld_products_path
        else
          flash[:alert] = I18n.t('admin.settings.products.update.invalid_data')
          render :edit
        end
      end

      def destroy
        @product.destroy!
        redirect_to :back, notice: t('.notice')
      end

      private

      def product_params
        params.require(:product).permit(:name, :currency, :sales_unit, :sales_price)
      end
    end
  end
end
