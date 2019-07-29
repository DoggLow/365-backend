module CoinAPI
  class XMR < BaseAPI
    def initialize(*)
      super
      @json_rpc_call_id  = 0
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def load_balance!
      result = json_rpc(:get_balance, {account_index: account_id}).fetch('result')
      convert_from_base_unit(result.fetch('unlocked_balance').to_d)
    end

    def load_balance_of!(address)
      result = json_rpc(:get_balance, {account_index: account_id}).fetch('result')
      balance = 0
      result.fetch('per_subaddress').each do |addr_data|
        if addr_data.fetch('address') == address
          balance = addr_data.fetch('unlocked_balance')
          break
        end
      end
      balance
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
      tx = get_transaction(txid)

      build_deposit(tx)
    end

    def get_fee(txid)
      tx = get_transaction(txid)
      convert_from_base_unit(tx.fetch('fee').to_d)
    end

    def get_transaction(txid)
      tx = json_rpc(:get_transfer_by_txid, {txid: normalize_txid(txid)}).fetch('result')
      return if tx.blank?

      tx.fetch('transfer')
    end

    def new_address!(options = {})
      result = json_rpc(:create_address, {account_index: account_id}).fetch('result')
      { address: normalize_address(result.fetch('address')) }
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      params = {
          account_index: account_id,
          destinations: [{
                          amount: convert_to_base_unit!(amount),
                          address: normalize_address(recipient.fetch(:address))
                      }]
      }
      json_rpc(:transfer, params).fetch('result').fetch('tx_hash')
    end

    def validate_address!(address)
      {
          address:  normalize_address(address),
          is_valid: valid_address?(normalize_address(address))
      }
    end

    def local_block_height
      json_rpc(:get_height).fetch('result').fetch('height')
    rescue StandardError => e
      Rails.logger.info e
      0
    end

    protected

    def connection
      Faraday.new(@json_rpc_endpoint).tap do |connection|
        unless @json_rpc_endpoint.user.blank?
          # connection.request :digest, @json_rpc_endpoint.user, @json_rpc_endpoint.password
          connection.digest_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
          connection.adapter  Faraday.default_adapter
        end
      end
    end
    memoize :connection

    def json_rpc(method, params = {})
      #####
      # Used curl temporary, because Faraday digest-auth not working
      #
      # response = connection.post \
      #   '/json_rpc',
      #   { jsonrpc: '2.0', id: 0, method: method, params: params }.to_json,
      #   'Accept' => 'application/json',
      #   'Content-Type' => 'application/json'
      #
      # response.assert_success!
      # response = JSON.parse(response.body)
      #
      data = {jsonrpc: '2.0', id: 0, method: method, params: params }.to_json

      args = ""
      args << " -s"
      args << " -u #{@json_rpc_endpoint.user}:#{@json_rpc_endpoint.password} --digest"
      args << " -X POST #{@json_rpc_endpoint}/json_rpc"
      args << " -d '#{data}'"
      args << " -H 'Content-Type: application/json'"

      response = JSON.parse(`curl #{args}`)
      # Rails.logger.info "XMR response : #{response}"
      #
      #####

      response['error'].tap { |error| raise Error, error.inspect if error }
      response
    end

    def batch_deposit(raise = true)
      collected = []
      begin
        response = json_rpc(:get_transfers, {in: true, account_index: account_id})
        result = response.fetch('result')
        if result.has_key?('in')
          txs = result.fetch('in')
          txs.each do |tx|
            collected << build_deposit(tx)
          end
        end
      rescue StandardError => e
        Rails.logger.unknown e.inspect
        raise e if raise
      end
      yield collected
    end

    def build_deposit(tx)
      {
          id:            normalize_txid(tx.fetch('txid')),
          confirmations: tx.fetch('confirmations').to_i,
          received_at:   Time.at(tx.fetch('timestamp')),
          entries:       [{ amount: convert_from_base_unit(tx.fetch('amount').to_d), address: normalize_address(tx.fetch('address')) }]
      }
    end

    def account_id
      account_info.fetch('account_index')
    end

    def account_info
      response = json_rpc(:get_accounts,{})
      accounts = response.fetch('result').fetch('subaddress_accounts')

      if accounts != nil &&  accounts.length > 0
        accounts[0]
      else # create account
        response = json_rpc(:create_account,{})
        response.fetch('result')
      end
    end

    def valid_address?(address)
      address.to_s.length == 95 && address.to_s[0,1] == '4'
    end

  end
end
