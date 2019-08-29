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

  desc "Add profits to CC Purchase"
  task pay_profit_cc_purchase: :environment do
    # define constants
    yearly_pld_count = 10_500_000.0
    daily_pld_count = yearly_pld_count / 365 * 65 / 100
    cur_date = Date.today.prev_day # Date.strptime('2019-08-25', '%Y-%m-%d')
    period = (PurchaseOption.get('pld_completion_date').to_date - cur_date).to_i + 1
    break if period < 0

    # get PLD price of 1 day before
    last_price = PurchaseOption.get('pld_usd') || 0

    # calculate sum of purchase in a day
    daily_sum = 0
    Purchase.where(created_at: cur_date.beginning_of_day..cur_date.end_of_day).each do |purchase|
      daily_sum += purchase.product_count * purchase.product.sales_price * get_return_rate(purchase)
    end

    # calculate PLD price and update DB
    price = last_price + daily_sum / period / daily_pld_count
    PurchaseOption.set('pld_usd', price)

    # add daily profit of pending or processing purchase
    Purchase.not_done.each do |purchase|
      next if purchase.created_at.to_date > cur_date
      p_period = (PurchaseOption.get('pld_completion_date').to_date - purchase.created_at.to_date).to_i
      purchase.fill_volume(get_return_rate(purchase) * purchase.amount / p_period / price)
      # puts purchase.id
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
