namespace :coin do
  desc "Add new accounts for new currency to already existing Members"
  task new_accounts: :environment do
    Member.all.each do |member|
      member.touch_accounts
    end
  end

  desc "Add new margin_accounts for new currency to already existing Members"
  task new_margin_accounts: :environment do
    Member.all.each do |member|
      member.touch_margin_accounts
    end
  end

  desc "Add new lending_accounts for new currency to already existing Members"
  task new_lending_accounts: :environment do
    Member.all.each do |member|
      member.touch_lending_accounts
    end
  end

  desc "Write addresses to redis (for deposit)"
  task cache_addresses: :environment do
    Global.cache_addresses('eth')
    Global.cache_addresses('etc')
  end

  desc "Write tx_ids to redis"
  task cache_txs: :environment do
    Global.cache_txs
  end

  desc "Add profits to TSF invests"
  task pay_profit_invests: :environment do
    Invest.processing.each do |invest|
      invest.check!
    end
  end

  def get_return_rate(purchase)
    case purchase.product.sales_price
    when 1000
      return 1
    when 3000
      return 1.1
    when 10000
      return 1.2
    else
      return 1
    end
  end

  def daily_paid(purchase, p_period)
    get_return_rate(purchase) * purchase.amount / p_period
  end

  def all_seconds(datetime)
    datetime.hour * 3600 + datetime.min * 60 + datetime.sec
  end

  desc "Re-calculate profits to CC Purchase"
  task recalc_profit_cc_purchase: :environment do
    purchases = Purchase.not_done.sort_by{|purchase| all_seconds(purchase.created_at)}
    start_date = Date.new(2019, 8, 20)
    end_date = Date.yesterday
    (start_date..end_date).each do |date|
      # puts date
      purchases.each do |purchase|
        next if purchase.created_at.to_date > date
        # puts purchase.id
        purchase.calc_and_fill_daily
      end
    end
    current_sec = all_seconds(DateTime.now)
    purchases.each do |purchase|
      next if all_seconds(purchase.created_at) > current_sec
      # puts purchase.id
      purchase.calc_and_fill_daily
    end
  end

  desc "Add profits to CC Purchase"
  task pay_profit_cc_purchase: :environment do
    cur_time = Time.new.strftime("%k:%M")
    purchases = Purchase.not_done.select{|purchase| purchase.created_at.strftime("%k:%M") == cur_time.strftime("%k:%M")}
    purchases.each do |purchase|
      purchase.calc_and_fill_daily
    end
  end

  desc "Claim neo gas and divide into per member."
  task claim_neo_gas: :environment do
    total = Account.locked_sum('neo') + Account.balance_sum('neo')
    next if total <= 0

    gas = CoinAPI['neo'].unclaimed_gas
    available_gas = gas.fetch('available').to_d
    next if available_gas <= 0

    result = CoinAPI['neo'].claim_gas
    puts result

    Member.all.each do |member|
      neo_account = member.get_account('neo')
      amount = neo_account.balance + neo_account.locked
      next if amount <= 0

      gas_account = member.get_account('gas')
      gas_account.plus_funds(available_gas * amount / total, reason: Account::CLAIM_GAS)
    end
  end

end
