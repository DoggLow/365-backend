module Admin
  class SettingsController < BaseController
    load_and_authorize_resource

    def index
      @settings = @settings.order(:id)
    end

    def update
      if @setting.update_attributes setting_params
        flash[:info] = I18n.t('admin.settings.settings.update.success')
        redirect_to admin_settings_path
      else
        flash[:alert] = I18n.t('admin.settings.settings.update.invalid_data')
        render :edit
      end
    end

    private

    def setting_params
      params.require(:setting).permit(:initial_margin, :maintenance_margin)
    end
  end
end
