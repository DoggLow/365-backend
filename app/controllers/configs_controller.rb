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

end
