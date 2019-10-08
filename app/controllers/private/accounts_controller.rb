module Private
  class AccountsController < BaseController
    layout false

    def index
      accounts = current_user.accounts.map(&:for_notify)
      lending_accounts = current_user.lending_accounts.map(&:for_notify)
      summaries = []

      Currency.all.each do |currency|
        code = currency.code
        main_balance = current_user.get_account(code).balance
        margin_balance = currency.coin? ? current_user.get_margin_account(code).balance : 0
        lending_balance = currency.coin? ? current_user.get_lending_account(code).balance : 0
        total = main_balance + margin_balance + lending_balance
        summaries << {currency: currency, main: main_balance, margin: margin_balance, lending: lending_balance, total: total}
      end

      render json: {summaries: summaries, accounts: accounts, lending_accounts: lending_accounts}.to_json, status: :ok
    end

    def main
      if params[:simple].blank? # default flow
        accounts = current_user.accounts.map(&:for_notify)
        render json: {accounts: accounts}.to_json, status: :ok
      else
        accounts = {}
        current_user.accounts.each do |account|
          accounts[account.currency.to_sym] = account.balance
        end
        render json: accounts.to_json, status: :ok
      end
    end

    def lending
      lending_accounts = current_user.lending_accounts.map(&:for_notify)
      render json: {lending_accounts: lending_accounts}.to_json, status: :ok
    end
  end
end
