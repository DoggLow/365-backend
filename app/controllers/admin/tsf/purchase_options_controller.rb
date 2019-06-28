module Admin
  module Tsf
    class PurchaseOptionsController < BaseController
      load_and_authorize_resource

      def index
        @purchase_options = @purchase_options.order(:id)
      end

      def update
        if @purchase_option.update_attributes purchase_option_params
          flash[:info] = I18n.t('admin.settings.purchase_options.update.success')
          redirect_to admin_tsf_purchase_options_path
        else
          flash[:alert] = I18n.t('admin.settings.purchase_options.update.invalid_data')
          render :edit
        end
      end

      private

      def purchase_option_params
        params.require(:purchase_option).permit(:lot_unit, :tsf_usd, :affiliate_fee, :tsfp_usd, :tsfp_fee)
      end
    end
  end
end
