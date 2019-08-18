module Admin
  module Assets

    class ProofsController < BaseController
      load_and_authorize_resource

      def index
        @proofs = @proofs.order('id desc').page params[:page]
      end

      def show
        @amount = params[:amount]
        @dest_address = params[:dest_address]
        @dest_tag = params[:dest_tag]

        return unless params[:commit].present?

        if @amount.blank? || @dest_address.blank?
          redirect_to :back, alert: 'Invalid input data'
        else
          begin
            redirect_to :back, alert: 'Invalid address' and return if @proof.address.blank? || @proof.currency_obj.blank?

            balance = @proof.currency_obj.api.load_balance_of!(@proof.address)
            @proof.update! balance: balance

            redirect_to :back, alert: 'Insufficient balance!' and return if balance < @amount.to_d

            recipient = { address: @dest_address}
            recipient[:tag]= @dest_tag if @proof.currency == 'xrp'

            txid = @proof.currency_obj.api.create_withdrawal!(
                { address: @proof.address, secret: @proof.secret, tag: @proof.tag },
                recipient,
                @amount.to_d
            )

            if txid
              AssetTransaction.create!(tx_id: txid, currency: @proof.currency, amount: @amount)
              redirect_to admin_assets_proofs_path, notice: "Transfer succeed! Txid: #{txid}"
            else
              redirect_to :back, alert: 'Transfer failed!'
            end
          rescue StandardError => e
            notification = "Failed to transfer #{@amount}#{@proof.currency}: #{e.inspect}."
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
