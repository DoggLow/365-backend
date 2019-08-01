module Admin
  module TsfPld
    class PointExchangesController < BaseController

      def index
        @point_exchanges = PointExchange.all
        @pending_point_exchanges = @point_exchanges.where(aasm_state: 'submitted').order("id DESC")
        @other_point_exchanges = @point_exchanges.where.not(aasm_state: 'submitted').order("id DESC")
      end

      def show
        @point_exchange = PointExchange.find_by(id: params[:id])
      end

      def update
        @point_exchange = PointExchange.find_by(id: params[:id])
        @point_exchange.accept!
        redirect_to :back, notice: t('.notice')
      end

      def destroy
        @point_exchange = PointExchange.find_by(id: params[:id])
        @point_exchange.reject!
        redirect_to :back, notice: t('.notice')
      end
    end
  end
end
