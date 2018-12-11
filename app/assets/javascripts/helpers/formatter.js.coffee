class Formatter
  round: (str, fixed) ->
    BigNumber(str).round(fixed, BigNumber.ROUND_HALF_UP).toF(fixed)

  fix: (type, str) ->
    str = '0' unless $.isNumeric(str)
    if type is 'ask'
      @.round(str, gon.market.ask.fixed)
    else if type is 'bid'
      @.round(str, gon.market.bid.fixed)

  fixAsk: (str) ->
    @.fix('ask', str)

  fixBid: (str) ->
    @.fix('bid', str)

  fixPriceGroup: (str) ->
    if gon.market.price_group_fixed
      str = '0' unless $.isNumeric(str)
      @.round(str, gon.market.price_group_fixed)
    else
      @fixBid(str)

  check_trend: (type) ->
    if type == 'up' or type == 'buy' or type == 'bid' or type == true
      true
    else if type == 'down' or type == "sell" or type == 'ask' or type == false
      false
    else
      throw "unknown trend symbol #{type}"

  market: (base, quote) ->
    "#{base.toUpperCase()}/#{quote.toUpperCase()}"

  market_url: (market, order_id) ->
    if order_id?
      "/markets/#{market}/orders/#{order_id}"
    else
      "/markets/#{market}"

  margin_market_url: (market, order_id) ->
    if order_id?
      "/margin_markets/#{market}/trigger_orders/#{order_id}"
    else
      "/margin_markets/#{market}"

  trade: (ask_or_bid) ->
    gon.i18n[ask_or_bid]

  short_trade: (type) ->
    if type == 'buy' or type == 'bid'
      gon.i18n['bid']
    else if type == "sell" or type == 'ask'
      gon.i18n['ask']
    else
      'n/a'

  trade_time: (timestamp) ->
    m = moment.unix(timestamp)
    "#{m.format("HH:mm")}#{m.format(":ss")}"

  fulltime: (timestamp) ->
    m = moment.unix(timestamp)
    "#{m.format("MM/DD HH:mm")}"

  mask_price: (price) ->
    price.replace(/\..*/, "<g>$&</g>")

  mask_fixed_price: (price) ->
    @mask_price @fixPriceGroup(price)

  ticker_fill: ['', '0', '00', '000', '0000', '00000', '000000', '0000000', '00000000']
  ticker_price: (price, fillTo=6) ->
    price = price.toString()
    [left, right] = price.split('.')
    if fill = @ticker_fill[fillTo-right.length]
      "#{left}.<g>#{right}</g><span class='fill'>#{fill}</span>"
    else
      "#{left}.<g>#{right.slice(0,fillTo)}</g>"

  price_change: (p1, p2) ->
    percent = if p1
                @round(100*(p2-p1)/p1, 2)
              else
                '0.00'
    "#{if p1 > p2 then '' else '+'}#{percent}"

  long_time: (timestamp) ->
    m = moment.unix(timestamp)
    "#{m.format("YYYY/MM/DD HH:mm")}"

  mask_fixed_volume: (volume) ->
    @.fixAsk(volume).replace(/\..*/, "<g>$&</g>")

  fix_ask: (volume) ->
    @.fixAsk volume

  fix_bid: (price) ->
    @.fixBid price

  amount: (amount, price) ->
    val = (new BigNumber(amount)).times(new BigNumber(price))
    @.fixAsk(val).replace(/\..*/, "<g>$&</g>")

  rate: (rate) ->
    if rate?
      rate
    else
      '-'

  trend: (type) ->
    if @.check_trend(type)
      "text-up"
    else
      "text-down"

  trend_icon: (type) ->
    if @.check_trend(type)
      "<i class='fa fa-caret-up text-up'></i>"
    else
      "<i class='fa fa-caret-down text-down'></i>"

  check_direction: (direction) ->
    if direction == 'long' or direction == 'Long' or direction == true
      "text-up"
    else if direction == 'short' or direction == 'Short' or direction == false
      "text-down"
    else
      throw "unknown direction symbol #{direction}"

  direction: (direction) ->
    if direction == 'long' or direction == 'Long' or direction == true
      @.t('position')['long']
    else if direction == 'short' or direction == 'Short' or direction == false
      @.t('position')['short']
    else
      'n/a'
  round: (str, fixed) ->
    BigNumber(str).round(fixed, BigNumber.ROUND_HALF_UP).toF(fixed)

  fix: (type, str) ->
    str = '0' unless $.isNumeric(str)
    if type is 'ask'
      @.round(str, gon.market.ask.fixed)
    else if type is 'bid'
      @.round(str, gon.market.bid.fixed)

  check_sign: (str) ->
    throw "Not numerical value: #{str}" unless $.isNumeric(str)
    if BigNumber(str).greaterThanOrEqualTo(BigNumber(0))
      "text-up"
    else if BigNumber(str).lessThan(BigNumber(0))
      "text-down"
    else
      throw "Not numerical value #{direction}"

  position_url: (position_id) ->
    "/positions/#{position_id}"

  t: (key) ->
    gon.i18n[key]

window.formatter = new Formatter()
