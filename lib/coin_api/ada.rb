module CoinAPI
  class ADA < BaseAPI
    def initialize(*)
      super
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def load_balance!
      account_info.nil?? 0 : convert_from_base_unit(account_info.fetch('amount'))
    end

    def load_balance_of!(address)
      load_balance!
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

    def load_deposit!(tx_id)
      query_params = {
          wallet_id: wallet_id,
          id: "EQ[#{tx_id}]"
      }
      txs = json_rpc('get', 'transactions', query_params).fetch('data')
      tx = txs[0]
      entries = tx.fetch('outputs').map do |output|
        amount = convert_from_base_unit(output.fetch('amount'))
        next unless amount >= 0
        {
            amount: amount,
            address: normalize_address(output.fetch('address'))
        }
      end.compact
      {
          id:            normalize_txid(tx.fetch('id')),
          confirmations: tx.fetch('confirmations'),
          received_at:   DateTime.parse(tx.fetch('creationTime')).to_time,
          entries:       entries
      }
    end

    def new_address!(options = {})
      return nil if wallet_id.nil? || account_id.nil?

      post_body = {
          walletId: wallet_id,
          accountIndex: account_id,
          spendingPassword: currency.spending_password
      }
      response = json_rpc('post', 'addresses', post_body)

      {
          address: normalize_address(response['data']['id'])
      }
    end

    def create_withdrawal!(_issuer, recipient, amount, options = {})
      return nil if wallet_id.nil? || account_id.nil?

      post_body = {
          source: {
              accountIndex: account_id,
              walletId: wallet_id
          },
          destinations: [{
                             address: normalize_address(recipient.fetch(:address)),
                             amount: convert_to_base_unit!(amount)
                         }],
          groupingPolicy: 'OptimizeForSecurity',
          spendingPassword: currency.spending_password
      }

      json_rpc('post', 'transactions', post_body).fetch('data').fetch('id')
    end

    def validate_address!(address)
      {
          address:  normalize_address(address),
          is_valid: true # TODOs
      }
    end

    def local_block_height
      node_info.fetch('localBlockchainHeight').fetch('quantity')
    end

    def sync_status
      n_info = node_info
      blockchain_height = n_info.fetch('blockchainHeight').fetch('quantity')
      local_height = n_info.fetch('localBlockchainHeight').fetch('quantity')
      return blockchain_height, local_height
    rescue StandardError => e
      return 0, 0
    end

    protected

    def connection
      ssl_options = {
          verify: true,
          verify_mode: OpenSSL::SSL::VERIFY_NONE,
          ca_file: currency.ca_cert,
          client_cert: OpenSSL::X509::Certificate.new(File.read(currency.cert)),
          client_key: OpenSSL::PKey::RSA.new(File.read(currency.p_key))
      }

      Faraday.new @json_rpc_endpoint, :ssl => ssl_options do |con|
        con.adapter  Faraday.default_adapter
      end
    end
    memoize :connection

    def json_rpc(request, path, params = {})
      response = connection.send(request) do |req|
        req.url "/api/v1/#{path}"
        req.headers['Accept'] = 'application/json; charset=UTF-8'
        req.headers['Content-Type'] = 'application/json; charset=UTF-8'
        if request == 'get'
          params.keys.each do |key|
            req.params[key] = params.fetch(key)
          end
        else # 'post'
          req.body = params.to_json
        end
      end
      response.assert_success!
      response = JSON.parse(response.body)
      response['status'].tap { |status| raise Error, response.inspect if status=='error' }
      response
    end

    def batch_deposit(raise = true)
      collected = []
      loop do
        begin
          deposits = nil
          last_page = Rails.cache.read "last_checked_#{currency.code}_page"
          query_params = {
              wallet_id: wallet_id
          }
          query_params[:page] = last_page + 1 if last_page.present?

          response = json_rpc('get', 'transactions', query_params)

          break if response.blank? || response.fetch('data').nil?

          deposits = collect_deposits(response.fetch('data'))
        rescue StandardError => e
          Rails.logger.unknown e.inspect
          raise e if raise
        end

        collected += deposits unless deposits.nil?

        page = response.fetch('meta').fetch('pagination').fetch('page')
        total_pages = response.fetch('meta').fetch('pagination').fetch('totalPages')
        if page < total_pages
          Rails.cache.write("last_checked_#{currency.code}_page", page, force: true)
        else
          Rails.cache.write("last_checked_#{currency.code}_page", nil, force: true)
          break
        end
      end

      yield collected
    end

    def collect_deposits(txs)
      txs.map do |tx|
        next unless tx['direction'].to_s == 'incoming'
        entries = tx.fetch('outputs').map do |output|
          amount = convert_from_base_unit(output.fetch('amount'))
          next unless amount >= 0
          {
              amount: amount,
              address: normalize_address(output.fetch('address'))
          }
        end
        {
            id:            normalize_txid(tx.fetch('id')),
            confirmations: tx.fetch('confirmations'),
            received_at:   DateTime.parse(tx.fetch('creationTime')).to_time,
            entries:       entries
        }
      end.compact
    end

    def wallet_id
      wallet_info.fetch('id')
    end

    def account_id
      account_info.fetch('index')
    end

    def wallet_info
      wallet_path = 'wallets'
      response = json_rpc('get',wallet_path)

      if response['meta']['pagination']['totalEntries'] > 0
        response['data'][0]
      else
        post_body = {
            operation: 'create',
            name: 'payment',
            spendingPassword: currency.spending_password,
            backupPhrase: currency.backup_phrase,
            assuranceLevel: 'strict'
        }
        response = json_rpc('post', wallet_path, post_body)
        response.fetch('data')
      end
    end

    def account_info
      return nil if wallet_info.nil?

      account_path = "wallets/#{wallet_id}/accounts"
      response = json_rpc('get', account_path)

      if response['meta']['pagination']['totalEntries'] > 0
        response['data'][0]
      else
        post_body = {
            name: 'payment',
            spendingPassword: currency.spending_password
        }
        response = json_rpc('post', account_path, post_body)
        response.fetch('data')
      end
    end

    def node_info
      json_rpc('get', 'node-info' ).fetch('data')
    end
  end
end
