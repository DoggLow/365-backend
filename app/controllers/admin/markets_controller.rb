module Admin
  class MarketsController < BaseController
    # load_and_authorize_resource

    def index
      # add records to price table from markets
      Market.all_with_invisible.each do |market|
        Price.find_or_create_by(market_id: market.id.to_sym)
      end

      @prices = Price.all

      @market_field = params[:market_field]
      @type_field = params[:type_field]
      @input_term = params[:input_term]

      unless @market_field.nil?
        Price.update(@market_field, @type_field, @input_term)
        @input_term = nil
      end
    end

  end
end
