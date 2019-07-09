#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= "development"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

def get_interval(string)
  case string
  when '5m'
    return 5
  when '15m'
    return 15
  when '30m'
    return 30
  when '1h'
    return 60
  when '2h'
    return 120
  when '4h'
    return 240
  when '6h'
    return 360
  when '12h'
    return 720
  when '1d'
    return 1440
  when '3d'
    return 4320
  when '1w'
    return 10080
  else
    return 1
  end
end

def process_depth(data)
  # first_updated = data.fetch('U')
  last_updated = data.fetch('u')
  market_id = data.fetch('s').downcase

  cached_last_update_id = Rails.cache.read "exchange:#{market_id}:last_update_id"
  last_update_id = if cached_last_update_id
                     cached_last_update_id
                   else
                     0
                   end


  if last_update_id <= last_updated
    AMQPQueue.enqueue :binance_processor, {event: 'depth_update', data: {market: market_id, bids: data.fetch('b'), asks: data.fetch('a')}}
  end
end

def process_ticker(data)
  market_id = data.fetch('s').downcase
  low = data.fetch('l').to_f
  high = data.fetch('h').to_f
  open = data.fetch('o').to_f
  volume = data.fetch('q').to_f
  # timestamp = data.fetch('E')

  last = Rails.cache.read "exchange:#{market_id}:ticker_last"

  ticker = {
      low:  low   || ::Trade::ZERO,
      high: high  || ::Trade::ZERO,
      last: last || ::Trade::ZERO
  }
  Rails.cache.write "exchange:#{market_id}:ticker", ticker
  Rails.cache.write "exchange:#{market_id}:ticker:open", open

  # seconds  = Time.now.to_i
  # time_key = seconds - (seconds % 5)
  # Rails.cache.write "exchange:#{market_id}:h24_volume:#{time_key}", volume, expires_in: 24.hours
  Rails.cache.write "exchange:#{market_id}:h24_volume:latest", volume, expires_in: 24.hours

  Rails.cache.write "exchange:#{market_id}:h24:low", low, expires_in: 24.hours
  Rails.cache.write "exchange:#{market_id}:h24:high", high, expires_in: 24.hours
end

def process_kline(data)
  market_id = data.fetch('s').downcase
  k = data.fetch('k')
  start = k.fetch('t') / 1000
  interval = k.fetch('i')
  open = k.fetch('o').to_f
  close = k.fetch('c').to_f
  high = k.fetch('h').to_f
  low = k.fetch('l').to_f
  volume = k.fetch('q').to_f.round(4)

  key = "exchange:#{market_id}:k:#{get_interval(interval)}"
  point_json = @r.lindex(key, -1)
  if point_json.present?
    point = JSON.parse point_json
    if point[0] == start
      @r.rpop key
    end
  end
  point = [start, open, high, low, close, volume]
  @r.rpush key, point.to_json
end

def process_trade(data)
  AMQPQueue.enqueue :binance_processor, {event: 'trade', data: data}
end

def process_message(message_data)
  data = JSON.parse(message_data)
  event = data.fetch('e')
  return unless event

  case event
    when 'trade'
      process_trade data
    when 'depthUpdate'
      process_depth data
    when '24hrMiniTicker'
      process_ticker data
    when 'kline'
      process_kline data
  end
end

socket_client = Binance::Client::WebSocket.new
@r ||= KlineDB.redis

EM.run do

  # Create event handlers
  open    = proc { puts 'connected' }
  on_message = proc { |e| process_message e.data}
  on_error   = proc { |e| puts "error in socket: #{e}" }
  close   = proc { puts 'closed' }

  # Bundle our event handlers into Hash
  methods = { open: open, message: on_message, error: on_error, close: close }

  Market.from_binance.each do |market|
    socket_client.trade symbol: market.id.upcase, methods: methods
    socket_client.diff_depth symbol: market.id.upcase, methods: methods
    socket_client.single stream: { type: 'miniTicker', symbol: market.id.upcase}, methods: methods
    ['1m', '5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d', '3d', '1w'].each do |period|
      socket_client.kline symbol: market.id.upcase, interval: period, methods: methods
    end
  end
end
