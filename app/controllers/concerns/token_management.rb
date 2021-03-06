module Concerns
  module TokenManagement
    extend ActiveSupport::Concern

    def token_required
      if not @token = Token.available.with_token(params[:token] || params[:id]).first
        render_json(Response::ResetPasswordFailure.new(t('.alert')))
        # redirect_to root_path, :alert => t('.alert')
      end
    end

    alias :'token_required!' :'token_required'
  end
end
