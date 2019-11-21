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
    purchases = Purchase.not_done.select{|purchase| purchase.created_at.strftime("%k:%M") == cur_time}
    purchases.each do |purchase|
      purchase.calc_and_fill_daily
    end
  end

  desc "Unlock PLD for failed PLD purchase"
  task unlock_failed_purchase: :environment do
    currency = Currency.find_by_code('pld')
    Account.where("currency = (?) AND locked > 0", currency.id).each do |account|
      account.lock!.unlock_funds account.locked, reason: Account::PURCHASE, ref: self
    end
  end

  desc "Pool Deposit for all members who took part in PLD pre-sale"
  task cc_pool_deposit_force: :environment do
    currency = Currency.find_by_code('pld')
    unit = 500
    Account.where("currency = (?) AND balance > 0", currency.id).each do |account|
      amount = (account.balance / unit).to_i
      next if amount <= 0
      PoolDeposit.create(member: account.member, unit: unit, amount: amount, currency: currency.id)
    end
  end

  desc "Clear fees for forced Pool Deposit for all members who took part in PLD pre-sale"
  task cc_clear_pool_deposit_fee_force: :environment do
    date = Date.new(2019, 11, 2)
    p_deposits = PoolDeposit.where("created_at between ? and ?", date.beginning_of_day, date.end_of_day)
    p_deposits.each do |p_deposit|
      next unless p_deposit.fee > 0.0
      # puts "p_deposit: #{p_deposit.id}"
      p_deposit.hold_account.lock!.plus_funds p_deposit.fee, reason: Account::UNKNOWN, ref: p_deposit
      p_deposit.update!(fee: 0)
    end
  end

  desc "Distribute CC"
  task cc_distribute: :environment do
    cur_min = DateTime.now.minute.to_s
    castings = Casting.pending_or_processing.select{|casting| casting.created_at.strftime("%M") == cur_min}
    castings.each do |casting|
      casting.distribute
    end
  end

  desc "Allocate CC"
  task cc_allocate: :environment do
    # Calculate daily sales
    sales_sum = 0.0
    cur_date = Date.today # Date.new(2019, 11, 2)
    start_date = cur_date - 6
    end_date = cur_date - 1
    (start_date..end_date).each do |date|
      castings = Casting.done.on(date)
      if castings.present?
        sales_sum += castings.distribution_sum / castings.length
      end
    end
    next unless sales_sum > 0.0

    sales_sum = sales_sum * 0.3 / 5 # 30%, 5 days
    sales_pools = [sales_sum * 0.3, sales_sum * 0.18, sales_sum * 0.09, sales_sum * 0.03]

    # Calculate allocations
    Pool.active.includes(:member).each do |pool|
      next if pool.created_at.to_date > end_date
      sum = 0
      pool.member.all_pool_share.each do |share_obj|
        sum += share_obj[:share] * sales_pools[share_obj[:pool] - 1]
      end
      # puts "Member: #{pool.member}, #{Casting::POOL_SYMBOL} allocation: #{sum}"
      next unless sum > 0.0

      # TODO: Need to update when add new casting bot
      casting = pool.castings.active.first
      casting.allocate(sum)
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

  desc "Processing bets at 1:00 am everyday."
  task process_bets: :environment do
    company_profit = 0.15

    price = Global.get_latest_price('btc', 'usdt')
    price = price.floor
    result = price % 2 == 0

    failed_bet_sum = Bet.accepted.where.not(expectancy: result).amount_sum
    next unless failed_bet_sum > 0.0

    total_bonus = failed_bet_sum * (1 - company_profit)
    Bet.accepted.each do |bet|
      bonus = bet.expectancy == result ? (bet.unit * bet.amount * total_bonus / failed_bet_sum).round(8) : 0.0
      bet.complete(result, bonus)
    end
  end
end
