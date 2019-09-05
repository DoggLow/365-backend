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

  desc "Add profits to CC Purchase"
  task pay_profit_cc_purchase: :environment do
    # define constants
    T = 52_500_000 # USD
    K = 1.02 # 2%
    N = 10_500_000.0 # all PLD
    U = 10000 # block unit
    X = T / U * (K - 1) / (K ** (N / U) - 1)

    # get PLD price of 1 day before
    last_price = PurchaseOption.get('pld_usd') || 0
    total_distributed = PurchaseOption.get('distributed_pld') || 0
    last_price = X unless last_price > 0

    # cur_date = Date.strptime('2019-09-04', '%Y-%m-%d')
    cur_date = Date.today.prev_day
    Purchase.not_done.all.group_by{|p| p.created_at.to_date}.each do |key_date, purchases|
      next if key_date > cur_date

      p_period = (PurchaseOption.get('pld_completion_date').to_date - key_date).to_i

      daily_sum = 0
      purchases.each do |purchase|
        next if purchase.is_tsf_purchase?
        daily_sum += daily_paid(purchase, p_period)
      end

      daily_distributed = U * Math.log(daily_sum * (K - 1) / (U * last_price) + 1) / Math.log(K) + 1

      purchases.each do |purchase|
        next if purchase.is_tsf_purchase?
        purchase.fill_volume(daily_paid(purchase, p_period) / daily_sum * daily_distributed)
      end

      total_distributed += daily_distributed
      # calculate PLD price
      last_price = X * (K ** ((total_distributed.to_i - 1) / U))
    end

    # update DB
    PurchaseOption.set('pld_usd', last_price)
    PurchaseOption.set('distributed_pld', total_distributed)
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
