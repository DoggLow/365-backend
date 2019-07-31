#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "development"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

HEIGHTS_URL = 'https://min-api.cryptocompare.com/data/coin/generalinfo'

# Status of coin nodes that don't know full blockchain status.
# BTC, BCH, LTC, DASH, NEO, XMR, BTG, BCD
COINS_WITH_3RD_PARTY = ['BTC', 'BCH', 'LTC', 'DASH', 'XMR', 'BTG', 'BCD', 'NEO']

# Coins that know full blockchain status with block height.
# ADA, ETH, ETC, XEM
COINS_WITHOUT_3RD_PARTY = ['ADA', 'ETH', 'ETC', 'XEM']

def get_coin_data_3rd_party
  coin_data = {}
  url = "#{HEIGHTS_URL}?fsyms=#{COINS_WITH_3RD_PARTY.join(",")}&tsym=USD"
  response = Net::HTTP.get(URI(url))
  data = JSON.parse(response).fetch('Data')
  data.each do |item|
    info = item['CoinInfo']
    coin_data.merge!("#{info['Name']}": info['BlockNumber'])
  end
  coin_data
rescue => e
  Rails.logger.fatal e.inspect
  coin_data
end

def check_status(values)
  chain_height, local_height = values
  if local_height <= 0
    "Stopped." # TODO: send email to admin
  elsif local_height < chain_height
    "Syncing. (Total: #{chain_height} / Synced: #{local_height})"
  elsif chain_height <= 0
    "Check official site. (Total: #{chain_height} / Synced: #{local_height})"
  else
    "Full. (Total: #{chain_height} / Synced: #{local_height})"
  end
end

while($running) do
  nodes_status = {}
  begin
    COINS_WITHOUT_3RD_PARTY.each do |coin|
      nodes_status[coin.downcase] = check_status(CoinAPI[coin.downcase].sync_status)
    end

    # XRP
    nodes_status['xrp'] = CoinAPI['xrp'].node_status

    coin_data = get_coin_data_3rd_party
    COINS_WITH_3RD_PARTY.each do |coin|
      symbol = coin == 'BCH' ? 'bchabc' : coin.downcase
      highest_block = coin_data[coin.to_sym] || 0
      local_height = CoinAPI[symbol].local_block_height
      nodes_status[symbol] = check_status([highest_block, local_height])
    end
  rescue => e
    Rails.logger.fatal e.inspect
  end

  nodes_status.each do |key, value|
    Rails.cache.write("exchange:nodes:#{key}:status", value)
  end

  Rails.cache.write('exchange:nodes:last_checked', Time.now.to_i)

  sleep 600
end
