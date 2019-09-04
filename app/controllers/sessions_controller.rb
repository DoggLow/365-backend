class SessionsController < ApplicationController

  layout false

  skip_before_action :verify_authenticity_token #, only: [:create]

  before_action :auth_member!, only: :destroy
  before_action :auth_anybody!, only: [:new, :failure]
  before_action :check_member!, only: :google_auth_verify

  helper_method :require_captcha?

  def new
    @identity = Identity.new
  end

  def create
    # if !require_captcha? || simple_captcha_valid?
      @member = Member.from_auth(auth_hash)
    # end

    if @member
      if @member.disabled?
        increase_failed_logins
        render_json(MemberDisabled.new)
      else
        clear_failed_logins
        reset_session rescue nil
        session[:member_id] = @member.id
        save_session_key @member.id, cookies['_exchange_session']

        if @member.app_two_factor.activated?
          render_json(TFARequired.new)
        else
          login_success(@member)
        end
      end
    else
      increase_failed_logins
      render_json(AuthError.new)
    end
  end

  def failure
    increase_failed_logins
    render_json(AuthError.new)
  end

  def destroy
    clear_current_user_session
    render_json(SignOutSuccess.new)
  end

  def google_auth_verify
    if two_factor_failed_locked?
      clear_current_user_session
      clear_two_factor_auth_failed
      render_json(LogInRequired.new)
    elsif google_auth_verified?
      unlock_two_factor!
      login_success(current_user)
    else
      render_json(TFAError.new(t('two_factors.update.alert')))
    end
  end

  private

  def require_captcha?
    failed_logins > 3
  end

  def failed_logins
    Rails.cache.read(failed_login_key) || 0
  end

  def increase_failed_logins
    Rails.cache.write(failed_login_key, failed_logins+1)
  end

  def clear_failed_logins
    Rails.cache.delete failed_login_key
  end

  def failed_login_key
    "exchange:session:#{request.ip}:failed_logins"
  end

  def auth_hash
    @auth_hash ||= env["omniauth.auth"]
    @auth_hash['ref_id'] = params[:refId] if params[:refId]
    @auth_hash
  end

  def login_success(member)
    save_signup_history member.id
    MemberMailer.notify_signin(member.id).deliver if member.activated?
    render_json(SignInSuccess.new)
  end

  def clear_current_user_session
    clear_all_sessions current_user.id
    reset_session
  end

  def check_member!
    if current_user.blank? || params[:email].blank? || params[:email] != current_user.email
      render_json(LogInRequired.new)
    end
  end

  def google_auth_verified?
    google_auth = current_user.app_two_factor
    google_auth.assign_attributes params.require(:google_auth).permit(:otp)
    if google_auth.verify?
      clear_two_factor_auth_failed
      true
    else
      increase_two_factor_auth_failed
      false
    end
  end

  def save_signup_history(member_id)
    SignupHistory.create(
      member_id: member_id,
      ip: request.remote_ip || request.ip,
      accept_language: request.headers["Accept-Language"],
      ua: request.headers["User-Agent"]
    )
  end
end
