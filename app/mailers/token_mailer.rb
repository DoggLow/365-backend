class TokenMailer < BaseMailer

  def reset_password(email, token)
    # @token_url = edit_reset_password_url(token)
    @token_url = "#{ENV['URL_SCHEMA']}://#{ENV['URL_UI']}/reset-password/#{token}"
    mail to: email
  end

  def activation(email, token)
    @token_url = edit_activation_url token
    mail to: email
  end

end
