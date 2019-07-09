module Private
  class MarketsController < BaseController
    layout false

    skip_before_action :auth_member!, only: [:index, :show]
    before_action :visible_market?

    layout false

    def index
      @market_list = Market.all.sort.map(&:for_notify)
      render json: {markets: @market_list}.to_json, status: :ok
    end

    def show
      @market = current_market
      set_member_data if current_user
      data = {}
      if @member
        data[:my_trades] = @trades_done.map(&:for_notify)
        data[:my_orders] = @orders_wait.map(&:for_notify)
        data[:my_margin_orders] = @margin_orders_wait.map(&:for_notify)
        data[:my_24h_orders] = @orders_24h.map(&:for_notify)
        data[:my_position] = @position
        data[:margin_info] = @margin_info
      end

      render json: data.to_json, status: :ok
    end

    private

    def visible_market?
      redirect_to market_path(Market.first) if not current_market.visible?
    end

    def set_member_data
      @member = current_user
      @orders_wait = @member.orders.with_currency(@market).with_state(:wait)
      @margin_orders_wait = @member.trigger_orders.with_currency(@market).with_state(:wait)
      @orders_24h = @member.orders.with_currency(@market).h24
      @trades_done = Trade.for_member(@market.id, current_user, limit: 100, order: 'id desc')
      @position = @member.positions.find_by(currency: @market.code, state: 100) # Position::OPEN
      @margin_info = @member.get_margin_info('btc')
    end

  end
end
