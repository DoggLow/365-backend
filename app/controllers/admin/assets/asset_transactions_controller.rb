module Admin
  module Assets
    class AssetTransactionsController < BaseController
      load_and_authorize_resource

      def index
        @asset_transactions = @asset_transactions.order('id desc').page params[:page]
      end
    end
  end
end
