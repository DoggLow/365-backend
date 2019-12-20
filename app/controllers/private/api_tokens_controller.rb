module Private
  class APITokensController < BaseController
    layout false

    before_action :auth_activated!
    before_action :auth_verified!
    before_action :two_factor_activated!

    def index
      @tokens = current_user.api_tokens.user_requested
      render json: @tokens, status: :ok
    end

    def create
      @token = current_user.api_tokens.build api_token_params
      @token.scopes = 'all'

      if !two_factor_auth_verified?
        render_json(APITokenError.new(t('.alert_two_factor')))
        return
      end

      if @token.save
        render json: @token
      else
        render_json(APITokenError.new(t('.failed')))
      end
    end

    def update
      @token = current_user.api_tokens.user_requested.find params[:id]

      if !two_factor_auth_verified?
        render_json(APITokenError.new(t('.alert_two_factor')))
        return
      end

      if @token.update_attributes(api_token_params)
        render_json(APITokenSuccess.new(t('.success')))
      else
        render_json(APITokenError.new(t('.failed')))
      end
    end

    def destroy
      @token = current_user.api_tokens.user_requested.find params[:id]
      if @token.destroy
        render_json(APITokenSuccess.new(t('.success')))
      else
        render_json(APITokenError.new(t('.failed')))
      end
    end

    private

    def api_token_params
      params.require(:api_token).permit(:label, :ip_whitelist)
    end

  end
end
