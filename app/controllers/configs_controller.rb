class ConfigsController < ApplicationController

  layout false

  def currencies
    configs = Currency.all.sort.map(&:as_json)
    render json: {currencies: configs}.to_json, status: :ok
  end

  def levels
    configs = Level.all.sort
    render json: {levels: configs}.to_json, status: :ok
  end

  def markets
    configs = Market.all.sort
    render json: {markets: configs}.to_json, status: :ok
  end

  def purchase
    configs = PurchaseOption.get_all
    render json: {purchase: configs}.to_json, status: :ok
  end
end
