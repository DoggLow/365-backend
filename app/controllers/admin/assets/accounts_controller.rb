module Admin
  module Assets
    class AccountsController < BaseController
      load_and_authorize_resource

      def index
        @accounts = @accounts.select {|account| account.payment_address.present? && account.payment_address.address.present? && !(account.currency_obj.api_client.casecmp('BTC').zero?)}
        @accounts = Kaminari.paginate_array(@accounts).page(params[:page])
      end

      def show
        @proofs = Proof.where(currency: @account.currency_obj.id)
        @amount = params[:amount]
        @to_address = params[:to_address]

        return unless params[:commit].present?

        if @amount.blank? || @to_address.blank?
          redirect_to :back, alert: 'Invalid input data'
        else
          begin
            redirect_to :back, alert: 'Invalid address' and return if @account.payment_address.blank? || @account.payment_address.address.blank? || @account.currency_obj.blank?

            payment_address = @account.payment_address
            currency_obj = @account.currency_obj
            balance = currency_obj.api.load_balance_of!(payment_address.address)
            @account.update! real_balance: balance

            redirect_to :back, alert: 'Insufficient balance!' and return if balance < @amount.to_d

            recipient = { address: @to_address }
            # recipient[:tag]= @tag unless @tag.nil?

            txid = currency_obj.api.create_withdrawal!(
                { address: payment_address.address, secret: payment_address.secret, tag: payment_address.tag },
                recipient,
                @amount.to_d
            )

            if txid
              balance = currency_obj.api.load_balance_of!(payment_address.address)
              @account.update! real_balance: balance

              redirect_to admin_assets_accounts_path, notice: "Transfer succeed! Txid: #{txid}"
            else
              redirect_to :back, alert: 'Transfer failed!'
            end
          rescue StandardError => e
            notification = "Failed to transfer #{@amount}#{@account.currency}: #{e.inspect}."
            Rails.logger.info notification

            redirect_to :back, alert: notification
          ensure
          end
        end
      end

      private

      def proof_params
        params.required(:proof).permit(:balance)
      end

    end
  end
end
