module APIv2
  class PrizeCenter < Grape::API
    helpers ::APIv2::NamedParams

    desc 'Get account info of a member for a currency.'
    params do
      use :auth
      requires :member,  type: Integer, desc: "ID of a user."
      requires :currency,  type: String, values: Currency.coin_codes, desc: "Currency value contains  #{Currency.coin_codes.join(',')}"
    end
    get "/account" do
      authenticate!
      raise PrizeCenterError unless current_user.admin?
      get_account
    end

    desc 'Get account info of a member for a currency.'
    params do
      use :auth
      requires :member,  type: Integer, desc: "ID of a user."
      requires :currency,  type: String, values: Currency.coin_codes, desc: "Currency value contains  #{Currency.coin_codes.join(',')}"
      requires :amount,  type: String,  desc: "Amount to increase or decrease. Precision limit: 8, If you want to increase, please input positive number.If you want to decrease, please input negative number. "
      optional :reason,  type: String,  values: %w(lend lend_profit), desc: "Available values are 'lend' or 'lend_profit'"
    end
    post "/account/change" do
      authenticate!
      raise PrizeCenterError unless current_user.admin?
      change_account
    end
  end
end
