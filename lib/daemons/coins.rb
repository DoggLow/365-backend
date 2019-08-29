#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= "development"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

running = true
Signal.trap(:TERM) { running = false }


def check_transactions(currency)
  Rails.logger.debug {"Processing #{currency.code.upcase} deposits."}
  client = currency.api
  processed = 0
  options = client.is_a?(CoinAPI::ETH) ? {blocks_limit: 40} : {}
  client.each_deposit options do |deposit|
    # Ignore deposits from admin addresses
    # next if AssetTransaction.where(tx_id: deposit[:id]).exists?
    # Skip if transaction is processed.
    # next if PaymentTransaction::Normal.where(txid: deposit[:id]).exists?
    # Skip zombie transactions (for which all addresses don't exist).
    # next if deposit[:entries].all? {|entry| PaymentAddress.get_with(currency, entry).nil?}
    next if Global.is_cached_tx?(deposit[:id])
    if client.is_a?(CoinAPI::ETH) || client.is_a?(CoinAPI::ERC20)
      sym = currency.code == 'etc' ? 'etc' : 'eth'
      next if deposit[:entries].all? {|entry| !Global.is_cached_address?(sym, entry[:address])}
    end

    received_at = deposit[:received_at]
    Rails.logger.debug {"Processing deposit received at #{received_at.to_s('%Y-%m-%d %H:%M %Z')}."} if received_at
    Rails.logger.info "Missed #{currency.code.upcase} transaction: #{deposit[:id]}."

    # Immediately enqueue job.
    AMQPQueue.enqueue :deposit_coin, {txid: deposit[:id], currency: currency.code}

    break if (processed += 1) >= 1000
    Rails.logger.debug {"Processed #{processed} #{currency.code.upcase} #{'deposit'.pluralize(processed)}."}
    # break if processed >= 100 || (received_at && received_at <= 1.hour.ago)
  end
  Rails.logger.debug {"Finished processing #{currency.code.upcase} deposits."}
rescue => e
  Rails.logger.fatal e.inspect
end

def create_thread currency
  Thread.new do
    loop do
      check_transactions currency
      sleep 30
    end
  end
end

threads = []
Currency.all.each do |currency|
  next if currency.fiat?
  thread = create_thread currency
  threads << thread
  sleep 5
end

while running
  unless running
    threads.each {|thread| thread.join}
  end
  sleep 5
end
