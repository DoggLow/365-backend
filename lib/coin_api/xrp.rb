module CoinAPI
  class XRP < BaseAPI
    def initialize(*)
      super
      @json_rpc_call_id  = 0
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def new_address!(options = {})
      if options.key?(:is_admin) && options[:is_admin]
        gen_address!
      else
        admin_address = Member.admin_member.get_account(:xrp).payment_address
        if admin_address.address.nil?
          address  = gen_address!
          admin_address.update(address)
        end
        {
            address: admin_address.address,
            secret: admin_address.secret,
            tag: gen_tag
        }
      end
    end

    def load_balance_of!(address)
      balance = 0

      begin
        balance = json_rpc(:account_info, [account: normalize_address(address), ledger_index: 'validated', strict: true])
                      .fetch('result')
                      .fetch('account_data')
                      .fetch('Balance').to_d unless address.nil?
      rescue StandardError => e
        Rails.logger.debug e.inspect
      end

      convert_from_base_unit(balance)
    end

    def load_balance!
      admin_address = Member.admin_member.get_account(:xrp).payment_address
      admin_address.address.nil? ? 0 : load_balance_of!(admin_address.address)
    end

    def validate_address!(address)
      { address:  normalize_address(address),
        is_valid: valid_address?(normalize_address(address)) }
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      destination_tag = recipient.fetch(:tag)
      tx_json = {
          Account:         normalize_address(issuer.fetch(:address)),
          Amount:          convert_to_base_unit!(amount).to_s,
          Destination:     normalize_address(recipient.fetch(:address)),
          TransactionType: 'Payment'
      }
      tx_json[:DestinationTag] = destination_tag unless destination_tag.nil?

      result = json_rpc(
          :sign,
          [{
               seed:       issuer.fetch(:secret),
               key_type:   'secp256k1',
               fee_mult_max: 1000,
               tx_json:      tx_json
           }]
      ).fetch('result')
      if result.present? && result['status'].to_s == 'success'
        tx_blob =  result['tx_blob']
        if tx_blob.present?
          result = json_rpc(
              :submit,
              [{
                   tx_blob: tx_blob
               }]
          ).fetch('result')

          if result['engine_result'].to_s == 'tesSUCCESS' && result['status'].to_s == 'success'
            normalize_txid(result.fetch('tx_json').fetch('hash'))
          else
            raise CoinAPI::Error, "#{currency.code.upcase} withdrawal from #{normalize_address(issuer[:address])} to #{normalize_address(recipient[:address])} failed: #{result}."
          end
        else
          raise CoinAPI::Error, "#{currency.code.upcase} transaction signing failed. #{result}."
        end
      else
        raise CoinAPI::Error, "#{currency.code.upcase} transaction signing failed. #{result}."
      end
    end

    def each_deposit!(options = {})
      batch_deposit raise: true do |deposits|
        deposits.each { |deposit| yield deposit if block_given? }
      end
    end

    def each_deposit(options = {})
      batch_deposit raise: false do |deposits|
        deposits.each { |deposit| yield deposit if block_given? }
      end
    end

    def load_deposit!(txid)
      tx = json_rpc(:tx, [transaction: txid]).fetch('result')
      return unless tx['status'].to_s == 'success'
      return unless tx['validated']
      return unless valid_address?(normalize_address(tx['Destination'].to_s))
      return unless tx['TransactionType'].to_s == 'Payment'
      return unless tx.fetch('meta').fetch('TransactionResult').to_s == 'tesSUCCESS'
      return unless tx['DestinationTag'].present?
      return unless String === tx['Amount']

      { id:            normalize_txid(tx.fetch('hash')),
        confirmations: calculate_confirmations(tx.fetch('ledger_index')),
        received_at:   Time.at(tx.fetch('date') + 946_684_800), # from 01/01/2000
        entries:       [{ amount:  convert_from_base_unit(tx.fetch('Amount')),
                          address: normalize_address(tx['Destination']),
                          tag: tx['DestinationTag']}] }
    end

    def node_status
      result = json_rpc(:server_info, []).fetch('result')
      status = result.fetch('info').fetch('server_state')

      if status == 'disconnected' ||  status == 'connected' ||  status == 'syncing'
        status.camelize
      else
        'Full synced.'
      end
    rescue StandardError => e
      'Stopped.'
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
        { jsonrpc: '1.0', id: @json_rpc_call_id += 1, method: method, params: params }.to_json,
        { 'Accept'       => 'application/json',
          'Content-Type' => 'application/json' }
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise Error, error.inspect if error }
      response
    end

    def batch_deposit(raise = true)
      collected = []
      pa = PaymentAddress.find_by_currency(currency.id)
      unless pa.nil? || pa.address.nil?
        loop do
          begin
            deposits = nil
            marker = Rails.cache.read 'xrp_marker'
            params = {
                account: pa.address,
                forward: true,
                ledger_index_min: -1,
                ledger_index_max: -1
            }
            params[:marker] = marker unless marker.nil?

            result = json_rpc(:account_tx, [params]).fetch('result')

            break if result.blank? || result.fetch('transactions').nil?
            deposits = collect_deposits(result.fetch('transactions'))
          rescue StandardError => e
            Rails.logger.unknown e.inspect
            raise e if raise
          end

          collected += deposits unless deposits.nil?

          if result.key?(:marker) && result.fetch('marker').nil?
            Rails.cache.write('xrp_marker', result.fetch('marker'), force: true)
          else
            break
          end
        end
      end

      yield collected
    end

    def collect_deposits(txs)
      txs.map do |tx_data|
        tx = tx_data.fetch('tx')
        next unless tx['TransactionType'].to_s == 'Payment'
        next unless valid_address?(normalize_address(tx['Destination'].to_s))
        next unless tx['DestinationTag'].present?
        next unless String === tx['Amount']

        { id:            normalize_txid(tx.fetch('hash')),
          confirmations: calculate_confirmations(tx.fetch('ledger_index')),
          received_at:   Time.at(tx.fetch('date') + 946_684_800), # from 01/01/2000
          entries:       [{ amount:  convert_from_base_unit(tx.fetch('Amount')),
                            address: normalize_address(tx['Destination']),
                            tag: tx['DestinationTag'] }] }
      end.compact
    end

    def gen_address!
      password = Passgen.generate(length: 64, symbols: true)
      result = json_rpc(:wallet_propose, [{ passphrase: password }]).fetch('result')
      { address: normalize_address(result.fetch('account_id')), secret: result.fetch('master_seed'), tag: gen_tag }
    end

    def ledger_current_index
      Rails.cache.fetch :xrp_ledger_current_index, expires_in: 5.seconds do
        json_rpc(:ledger_current,[{}] ).fetch('result').fetch('ledger_current_index')
      end
    rescue StandardError => e
      0
    end

    def calculate_confirmations(ledger_index)
      return 0 unless ledger_index.present?

      ledger_current_index - ledger_index
    end

    def gen_tag
      SecureRandom.random_number(4294967295).to_s # TODO: repeat processing
    end

    def valid_address?(address)
      address =~ /\Ar[0-9a-zA-Z]{33}(:?\?dt=[1-9]\d*)?\z/
    end

    def normalize_address(address)
      super(address.gsub(/\?dt=\d*\Z/, ''))
    end
  end
end
