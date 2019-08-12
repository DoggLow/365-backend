module Admin
  module TsfPld
    class PurchaseOptionsController < BaseController
      load_and_authorize_resource

      def index
        @purchase_options = @purchase_options.order(:id)
      end

      def update
        if @purchase_option.update_attributes purchase_option_params
          flash[:info] = I18n.t('admin.settings.purchase_options.update.success')
          redirect_to admin_tsf_pld_purchase_options_path
        else
          flash[:alert] = I18n.t('admin.settings.purchase_options.update.invalid_data')
          render :edit
        end
      end

      private

      def purchase_option_params
        params.require(:purchase_option).permit(:tsf_usd, :tsf_aff_fee, :tsfp_usd, :tsfp_fee, :pld_aff_fee, :pldp_usd, :pld_completion_date)
      end
    end
  end
end
