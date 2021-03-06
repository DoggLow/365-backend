module Private
  class MarginMarketsController < BaseController
    skip_before_action :auth_member!, only: [:show]
    before_action :visible_market?
    after_action :set_default_market

    layout false

    def show
      @bid = params[:bid]
      @ask = params[:ask]

      @market        = current_market
      @markets       = Market.margin_markets.sort
      @market_groups = @markets.map(&:quote_unit).uniq

      @bids   = @market.bids
      @asks   = @market.asks
      @trades = @market.trades

      # default to limit order
      @rate = 0
      @trigger_bid = TriggerBid.new ord_type: 'limit'
      @trigger_ask = TriggerAsk.new ord_type: 'limit'

      set_member_data if current_user
      gon.jbuilder
    end

    private

    def visible_market?
      redirect_to margin_market_path(Market.margin_markets.first) if not (current_market.visible? && current_market.is_margin?)
    end

    def set_default_market
      cookies[:market_id] = @market.id
    end

    def set_member_data
      @member = current_user
      @orders_wait = @member.orders.with_currency(@market).with_state(:wait)
      @margin_orders_wait = @member.trigger_orders.with_currency(@market).with_state(:wait)
      @trades_done = Trade.for_member(@market.id, current_user, limit: 100, order: 'id desc')
      @position = @member.positions.find_by(currency: @market.code, state: 100) # Position::OPEN
    end

  end
end
