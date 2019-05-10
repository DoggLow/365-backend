module CoinAPI
  class NEO < BaseAPI
    BLOCKS_LIMIT = 20

    # 3_730_100: Mainnet: 11th, May
    # 2_549_400: Testnet: 16th, Apr
    START_BLOCK = 3_730_100

    def initialize(*)
      super
      @json_rpc_call_id  = 0
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def claim_gas(address = nil)
      params = address.blank? ? nil : [address]
      json_rpc(:claimgas)#.fetch('result')
    end

    def unclaimed_gas
      json_rpc(:getunclaimedgas).fetch('result')
    end

    def load_balance!
      json_rpc(:getbalance, [currency.asset_id]).fetch('result').fetch('balance').to_d
    end

    def load_balance_of!(address)
      load_balance!
    end

    def each_deposit!(options = {})
      batch_deposit raise: true, **options do |deposits|
        deposits.each { |deposit| yield deposit if block_given? }
      end
    end

    def each_deposit(options = {})
      batch_deposit raise: false, **options do |deposits|
        deposits.each { |deposit| yield deposit if block_given? }
      end
    end

    def load_deposit!(txid)
      tx = json_rpc(:getrawtransaction, [normalize_txid(txid), 1]).fetch('result')
      build_deposit(tx)
    end

    def new_address!(options = {})
      { address: normalize_address(json_rpc(:getnewaddress).fetch('result')) }
    end

    def create_withdrawal!(_issuer, recipient, amount, options = {})
      json_rpc(:sendtoaddress, [currency.asset_id, normalize_address(recipient.fetch(:address)), amount]).fetch('result').fetch('txid')
    end

    def validate_address!(address)
      x = json_rpc(:validateaddress, [normalize_address(address)]).fetch('result')
      {
        address: normalize_address(address),
        is_valid: !!x['isvalid']
      }
    end

    protected

    def connection
      Faraday.new(@json_rpc_endpoint).tap do |connection|
        unless @json_rpc_endpoint.user.blank?
          connection.basic_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
        end
      end
    end
    memoize :connection

    def json_rpc(method, params = [])
      response = connection.post \
        '/',
        { jsonrpc: '2.0', id: @json_rpc_call_id += 1, method: method, params: params }.to_json,
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise Error, error.inspect if error }
      response
    end

    def batch_deposit(raise = true, **options)
      blocks_limit = options.fetch(:blocks_limit) { BLOCKS_LIMIT }
      collected = []
      last_checked = Rails.cache.read "last_checked_#{currency.code}_block"
      current_block = last_checked.blank? ? START_BLOCK : last_checked
      limit_block_number = if latest_block_number > current_block + blocks_limit
                             current_block + blocks_limit
                           else
                             latest_block_number
                           end
Rails.logger.info "current_#{currency.code}_block_number: #{current_block}"
      while current_block <= limit_block_number
        begin
          block = json_rpc(:getblock, [current_block, 1]).fetch('result')
          deposits = collect_deposits(block)
        rescue StandardError => e
          Rails.logger.unknown e.inspect
          raise e if raise
        end
        collected += deposits unless deposits.nil?
        current_block += 1
      end

      Rails.cache.write("last_checked_#{currency.code}_block", current_block, force: true)
      yield collected
    end

    def collect_deposits(block_data)
      block_data.fetch('tx').map do |tx|
        next unless tx.fetch('type') == 'ContractTransaction'
        build_deposit(tx, block_data['confirmations'], block_data['time'])
      end.compact
    end

    def build_deposit(tx, confirmations = nil, block_time = nil)
      entries = tx.fetch('vout').map do |item|
        next unless item.fetch('asset') == currency.asset_id
        {
            amount: item.fetch('value').to_d,
            address: normalize_address(item.fetch('address'))
        }
      end.compact
      {
          id:            normalize_txid(tx.fetch('txid')),
          confirmations: confirmations || tx['confirmations'],
          received_at:   Time.at(block_time || tx['blocktime']),
          entries:       entries
      }
    end

    def latest_block_number
      Rails.cache.fetch "latest_#{currency.code}_block_number".to_sym, expires_in: 5.seconds do
        json_rpc(:getblockcount).fetch('result')
      end
    rescue StandardError => e
      0
    end

  end
end
