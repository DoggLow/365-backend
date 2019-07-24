class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  helper_method :current_user, :is_admin?, :current_market, :current_loan_market
  before_action :set_timezone
  after_action :allow_iframe
  # after_action :set_csrf_cookie_for_ng
  rescue_from CoinAPI::ConnectionRefusedError, with: :coin_rpc_connection_refused

  private

  include SimpleCaptcha::ControllerHelpers
  include TwoFactorHelper
  include Concerns::Response

  def currency
    "#{params[:ask]}#{params[:bid]}".to_sym
  end

  def current_market
    @current_market ||= Market.find_by_id(params[:market]) || Market.find_by_id(cookies[:market_id]) || Market.first
  end

  def current_loan_market
    @current_loan_market ||= LoanMarket.find_by_id(params[:loan_market_id]) || LoanMarket.find_by_id(params[:id]) ||
        LoanMarket.find_by_id(cookies[:loan_market_id]) || LoanMarket.first
  end

  # def redirect_back_or_settings_page
  #   render_json(SignInSuccess.new)
  # end

  def current_user
    @current_user ||= Member.current = Member.enabled.where(id: session[:member_id]).first
  end

  def auth_member!
    unless current_user
      set_redirect_to
      render_json(LogInRequired.new)
    end
  end

  def auth_activated!
    render_json(SettingsAlert.new(t('private.settings.index.auth-activated'))) unless current_user.activated?
  end

  def auth_verified!
    unless current_user and current_user.id_document and current_user.id_document_verified?
      render_json(SettingsAlert.new(t('private.settings.index.auth-verified')))
    end
  end

  def auth_no_initial!
  end

  def auth_anybody!
    render_json(LogInRequired.new) if current_user
  end

  def auth_admin!
    render_json(AdminRoleRequired.new) unless is_admin?
  end

  def is_admin?
    current_user && current_user.admin?
  end

  def two_factor_activated!
    render_json(TFAError.new(t('two_factors.auth.please_active_two_factor'))) unless current_user.two_factors.activated?
  end

  def two_factor_auth_verified?
    return false unless current_user.two_factors.activated?
    two_factor_verified?
  end

  def two_factor_auth_passed!
    # temporary method
    render_json(TFAError.new(t('private.withdraws.create.two_factors_error'))) unless two_factor_auth_passed?
  end

  def two_factor_auth_passed?
    # temporary method
    return true unless current_user.two_factors.activated?
    two_factor_verified?
  end

  def two_factor_verified?
    return false if two_factor_failed_locked?# && !simple_captcha_valid?

    two_factor = current_user.two_factors.by_type(params[:two_factor][:type])
    return false if not two_factor

    two_factor.assign_attributes params.require(:two_factor).permit(:otp)
    if two_factor.verify?
      clear_two_factor_auth_failed
      true
    else
      increase_two_factor_auth_failed
      false
    end
  end

  def two_factor_failed_locked?
    failed_two_factor_auth > 10
  end

  def failed_two_factor_auth
    Rails.cache.read(failed_two_factor_auth_key) || 0
  end

  def failed_two_factor_auth_key
    "exchange:session:#{request.ip}:failed_two_factor_auths"
  end

  def increase_two_factor_auth_failed
    Rails.cache.write(failed_two_factor_auth_key, failed_two_factor_auth + 1, expires_in: 1.month)
  end

  def clear_two_factor_auth_failed
    Rails.cache.delete failed_two_factor_auth_key
  end

  def set_timezone
    Time.zone = ENV['TIMEZONE'] if ENV['TIMEZONE']
  end

  def coin_rpc_connection_refused
    render 'errors/connection'
  end

  def save_session_key(member_id, key)
    Rails.cache.write "exchange:sessions:#{member_id}:#{key}", 1, expire_after: ENV['SESSION_EXPIRE'].to_i.minutes
  end

  def clear_all_sessions(member_id)
    if redis = Rails.cache.instance_variable_get(:@data)
      redis.keys("exchange:sessions:#{member_id}:*").each { |k| Rails.cache.delete k.split(':').last }
    end

    Rails.cache.delete_matched "exchange:sessions:#{member_id}:*"
  end

  def allow_iframe
    response.headers.except! 'X-Frame-Options' if Rails.env.development?
  end

  # def set_csrf_cookie_for_ng
  #   cookies['XSRF-TOKEN'] = form_authenticity_token if protect_against_forgery?
  # end

  # def verified_request?
  #   super || form_authenticity_token == request.headers['X-XSRF-TOKEN']
  # end

end
