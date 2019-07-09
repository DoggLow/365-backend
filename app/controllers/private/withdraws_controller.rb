module Private
  class WithdrawsController < BaseController

    # before_action :two_factor_activated!

    def create
      @withdraw = Withdraw.new(withdraw_params)

      # if two_factor_auth_verified?
        unless current_user.id_document and current_user.id_document_verified? and current_user.activated?
          withdraws_h24 = current_user.withdraws.done.h24
          if withdraws_h24.present?
            sum = 0
            withdraws_h24.each do |withdraw|
              sum += Global.estimate(withdraw.currency_obj.code, ENV['WITHDRAW_H24_LIMIT_CURRENCY'], withdraw.sum)
            end
            if sum + @withdraw.sum > ENV['WITHDRAW_H24_LIMIT_AMOUNT'].to_d
              render text: "You've exceed 24h withdrawal limit.", status: 403 and return
            end
          end
        end
        if @withdraw.save
          @withdraw.submit!
          render nothing: true
        else
          render text: @withdraw.errors.full_messages.join(', '), status: 403
        end
      # else
      #   render text: I18n.t('private.withdraws.create.two_factors_error'), status: 403
      # end
    end

    def destroy
      Withdraw.transaction do
        @withdraw = current_user.withdraws.find(params[:id]).lock!
        @withdraw.cancel
        @withdraw.save!
      end
      render nothing: true
    end

    private

    def withdraw_params
      params[:withdraw][:member_id] = current_user.id
      params.require(:withdraw).permit(:fund_source, :member_id, :currency, :sum)
    end

  end
end
