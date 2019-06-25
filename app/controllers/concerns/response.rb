module Concerns
  module Response

    def render_json(result)
      render json: result.message, status: result.status
    end

    class Result
      attr :code, :text, :message, :status

      # code: result code defined by Exchange
      # text: human readable result message
      # status: http status code
      def initialize(opts={})
        @code    = opts[:code]   || 2000
        @text    = opts[:text]   || ''

        @status  = opts[:status] || :ok
        @message = {code: @code, message: @text}
      end
    end

    class SignInSuccess < Result
      def initialize
        super code: 2000, text: 'Successfully signed in.', status: :ok
      end
    end

    class SetupPasswordSuccess < Result
      def initialize(text)
        super code: 2001, text: text, status: :ok
      end
    end

    class ResetPasswordSuccess < Result
      def initialize(text)
        super code: 2002, text: text, status: :ok
      end
    end

    class SignOutSuccess < Result
      def initialize
        super code: 2003, text: 'Successfully logged out.', status: :ok
      end
    end

    class GoogleAuthSuccess < Result
      def initialize(text)
        super code: 2010, text: text, status: :ok
      end
    end

    class MemberUpdateSuccess < Result
      def initialize
        super code: 2011, text: 'Member update success', status: :ok
      end
    end

    class TFAVerified < Result
      def initialize
        super code: 2012, text: 'Two-factor authentication success', status: :ok
      end
    end

    class APITokenSuccess < Result
      def initialize(text)
        super code: 2013, text: text, status: :ok
      end
    end

    class IDDocumentSubmitted < Result
      def initialize
        super code: 2014, text: I18n.t("private.id_documents.update.notice"), status: :ok
      end
    end

    class TicketSuccess < Result
      def initialize(text)
        super code: 2015, text: text, status: :ok
      end
    end

    class MoveFundsSuccess < Result
      def initialize
        super code: 2016, text: 'move funds success!', status: :ok
      end
    end

    class AuthError < Result
      def initialize
        super code: 4000, text: I18n.t("sessions.failure.error"), status: :bad_request
      end
    end

    class IdentityUpdateError < Result
      def initialize(text)
        super code: 4001, text: text, status: :bad_request
      end
    end

    class MemberUpdateError < Result
      def initialize
        super code: 4002, text: "Member update Failed", status: :bad_request
      end
    end

    class MemberDisabled < Result
      def initialize
        super code: 4003, text: I18n.t("sessions.create.error"), status: :bad_request
      end
    end

    class SignUpFailure < Result
      def initialize(reason)
        super code: 4004, text: reason, status: :bad_request
      end
    end

    class ResetPasswordFailure < Result
      def initialize(reason)
        super code: 4005, text: reason, status: :bad_request
      end
    end

    class LogInRequired < Result
      def initialize
        super code: 4010, text: 'Login required!', status: :unauthorized
      end
    end

    class SettingsAlert < Result
      def initialize(text)
        super code: 4011, text: text, status: :unauthorized
      end
    end

    class AdminRoleRequired < Result
      def initialize
        super code: 4014, text: 'You have no admin role.', status: :unauthorized
      end
    end

    class GoogleAuthError < Result
      def initialize(text)
        super code: 4020, text: text, status: :bad_request
      end
    end

    class TFAError < Result
      def initialize(text)
        super code: 4021, text: text, status: :unauthorized
      end
    end

    class APITokenError < Result
      def initialize(text)
        super code: 4023, text: text, status: :bad_request
      end
    end

    class IDDocumentSubmitFailure < Result
      def initialize
        super code: 4024, text: 'ID document submit failure', status: :bad_request
      end
    end

    class TicketFailure < Result
      def initialize(text)
        super code: 4025, text: text, status: :bad_request
      end
    end

    class MoveFundsFailure < Result
      def initialize(text)
        super code: 4026, text: text, status: :bad_request
      end
    end

  end
end