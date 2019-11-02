class MembersController < ApplicationController
  layout false

  skip_before_action :verify_authenticity_token
  before_filter :auth_member!

  def show
    data = {
        id: current_user.id,
        email: current_user.email,
        activation_status: current_user.activated?,
        verification_status: current_user.id_document_verified?,
        sms_status: current_user.sms_two_factor.activated?,
        tfa_status: current_user.app_two_factor.activated?,
        is_admin: current_user.admin?,
        commission_status: current_user.commission_status,
        level: current_user.level_obj.key,
        logins: current_user.signup_histories.last(10)
    }

    render json: data.to_json, status: :ok
  end

  def update
    if current_user.update_attributes member_params
      render_json(MemberUpdateSuccess.new)
    else
      render_json(MemberUpdateError.new)
    end
  end

  private

  def member_params
    params.required(:member).permit(:commission_status)
  end
end
