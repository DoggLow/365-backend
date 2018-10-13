@MemberData = flight.component ->
  @after 'initialize', ->
    return if not gon.current_user
    channel = @attr.pusher.subscribe("private-#{gon.current_user.sn}")

    channel.bind 'account', (data) =>
      gon.accounts[data.currency] = data
      @trigger 'account::update', gon.accounts

    channel.bind 'lending_account', (data) =>
      gon.lending_accounts[data.currency] = data
      @trigger 'lending_account::update', gon.lending_accounts

    channel.bind 'order', (data) =>
      @trigger "order::#{data.state}", data

    channel.bind 'trade', (data) =>
      @trigger 'trade', data

    channel.bind 'open_loan', (data) =>
      @trigger "loan::#{data.state}", data

    channel.bind 'active_loan', (data) =>
      @trigger 'active_loan', data

    # Initializing at bootstrap
    @trigger 'account::update', gon.accounts
    @trigger 'lending_account::update', gon.lending_accounts
    @trigger 'order::wait::populate', orders: gon.my_orders if gon.my_orders
    @trigger 'trade::populate', trades: gon.my_trades if gon.my_trades
    @trigger 'loan::wait::populate', loans: gon.my_open_loans if gon.my_open_loans
    @trigger 'active_loan::populate', active_loans: gon.my_active_loans if gon.my_active_loans
