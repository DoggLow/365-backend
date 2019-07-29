module CoinAPI
  class BTC < BaseAPI
    def initialize(*)
      super
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def load_balance!
      json_rpc(:getbalance).fetch('result').to_d
    end

    def load_balance_of!(address)
      json_rpc(:getbalance).fetch('result').to_d
    end

    def each_deposit!(options = {})
      batch_deposit do |deposits|
        deposits.each { |deposit| yield deposit if block_given? }
      end
    end

    def each_deposit(options = {})
      batch_deposit false do |deposits|
        deposits.each { |deposit| yield deposit if block_given? }
      end
    end

    def load_deposit!(txid)
      tx = json_rpc(:gettransaction, [normalize_txid(txid)]).fetch('result')
      build_deposit(tx)
    end

    def new_address!(options = {})
      { address: normalize_address(json_rpc(:getnewaddress).fetch('result')) }
    end

    def create_withdrawal!(_issuer, recipient, amount, options = {})
      json_rpc(:settxfee, [options[:fee]]) if options.key?(:fee)
      json_rpc(:sendtoaddress, [normalize_address(recipient.fetch(:address)), amount]).fetch('result')
    end

    def validate_address!(address)
      x = json_rpc(:validateaddress, [normalize_address(address)]).fetch('result')
      {
        address: normalize_address(address),
        is_valid: !!x['isvalid']
      }
    end

    def local_block_height
      json_rpc(:getblockcount).fetch('result')
    rescue StandardError => e
      0
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
        { jsonrpc: '1.0', method: method, params: params }.to_json,
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise Error, error.inspect if error }
      response
    end

    def batch_deposit(raise = true)
      offset    = 0
      collected = []
      loop do
        begin
          batch_deposits = nil
          response       = json_rpc(:listtransactions, ['*', 100, offset])
          offset        += 100
          batch_deposits = collect_deposits(response.fetch('result'))
        rescue StandardError => e
          Rails.logger.unknown e.inspect
          raise e if raise
        end
        yield batch_deposits if batch_deposits
        collected += batch_deposits unless batch_deposits.nil?
        break if batch_deposits.nil? || batch_deposits.empty?
      end
      collected
    end

    def build_deposit(tx)
      entries = tx.fetch('details').map do |item|
        next unless item.fetch('category') == 'receive'
        { amount: item.fetch('amount').to_d, address: normalize_address(item.fetch('address')) }
      end.compact
      { id:            normalize_txid(tx.fetch('txid')),
        confirmations: tx.fetch('confirmations').to_i,
        received_at:   Time.at(tx.fetch('timereceived')),
        entries:       entries }
    end

    def collect_deposits(txs)
      txs.map do |tx|
        next unless tx.fetch('category') == 'receive'
        { id:            normalize_txid(tx.fetch('txid')),
          confirmations: tx.fetch('confirmations').to_i,
          received_at:   Time.at(tx.fetch('timereceived')),
          entries:       [{ amount: tx.fetch('amount').to_d, address: normalize_address(tx.fetch('address')) }] }
      end.compact.reverse
    end
  end
end
