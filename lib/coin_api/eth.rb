module CoinAPI
  class ETH < BaseAPI
    def initialize(*)
      super
      @json_rpc_call_id  = 0
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def new_address!(options = {})
      password = Passgen.generate(length: 64, symbols: true)
      { address: normalize_address(json_rpc(:personal_newAccount, [password]).fetch('result')),
        secret:  password }
    end

    def load_balance_of!(address)
      balance = 0

      begin
        balance = json_rpc(:eth_getBalance, [address, 'latest']).fetch('result').hex.to_d unless address.nil?
      rescue StandardError => e
        Rails.logger.unknown e.inspect
      end

      convert_from_base_unit(balance)
    end

    def load_balance!
      total = 0

      PaymentAddress.where(currency: currency.id).each do |a|
        total += load_balance_of!(a.address)
      end

      total
    end

    def validate_address!(address)
      { address:  normalize_address(address),
        is_valid: valid_address?(normalize_address(address)) }
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      permit_transaction(issuer, recipient)

      txid = json_rpc(
          :eth_sendTransaction,
          [{
               from:  normalize_address(issuer.fetch(:address)),
               to:    normalize_address(recipient.fetch(:address)),
               value: '0x' + convert_to_base_unit!(amount).to_s(16),
               gas:   options.key?(:gas_limit) ? '0x' + options[:gas_limit].to_s(16) : nil
           }.reject { |_, v| v.nil? }]
      ).fetch('result')
      unless valid_txid?(normalize_txid(txid))
        raise CoinAPI::Error, \
              "#{currency.code.upcase} withdrawal from #{normalize_address(issuer[:address])} to #{normalize_address(recipient[:address])} failed."
      end
      normalize_txid(txid)
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
      tx = json_rpc(:eth_getTransactionByHash, [txid]).fetch('result')
      return if tx.blank?

      block = block_information(tx.fetch('blockNumber'))
      {
          id:            normalize_txid(tx.fetch('hash')),
          confirmations: calculate_confirmations(tx.fetch('blockNumber').hex),
          received_at:   Time.at(block.fetch('timestamp').hex),
          entries:       [{ amount:  convert_from_base_unit(tx.fetch('value').hex),
                            address: normalize_address(tx.fetch('to')) }]
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
        { 'Accept'       => 'application/json',
          'Content-Type' => 'application/json' }
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise Error, error.inspect if error }
      response
    end

    # See important links:
    # https://ethereum.stackexchange.com/questions/25389/getting-transaction-history-for-a-particular-account
    # https://github.com/ethereum/go-ethereum/issues/2104#issuecomment-168748944
    # https://github.com/ethereum/web3.js/issues/580
    def batch_deposit(raise:, **options)
      blocks_limit       = options.fetch(:blocks_limit) { 0 }
      collected       = []
      last_checked = Rails.cache.read "last_checked_#{currency.code}_block"

      current_block_number = if last_checked
                               last_checked
                             else
                               earliest_block
                             end

      limit_block_number = if latest_block_number > current_block_number + blocks_limit
                             current_block_number + blocks_limit
                           else
                             latest_block_number
                           end
      # current_block_number = 6_462_400 if currency.code == 'skb' || currency.code == 'eth'
      # Rails.logger.info "current_#{currency.code}_block_number: #{current_block_number}"
      while current_block_number <= limit_block_number
        begin
          deposits = nil
          block          = json_rpc(:eth_getBlockByNumber, ["0x#{current_block_number.to_s(16)}", true]).fetch('result')
          deposits = collect_deposits(block)
        rescue StandardError => e
          Rails.logger.unknown e.inspect
          raise e if raise
        end
        collected       += deposits unless deposits.nil?
        current_block_number += 1
      end
      Rails.cache.write("last_checked_#{currency.code}_block", current_block_number, force: true)

      yield collected
    end

    def collect_deposits(current_block)
      txs = current_block.fetch('transactions')
      txs.map do |tx|
        # Skip contract creation transactions.
        # Skip outcomes (less than zero) and contract transactions (zero).
        next if tx.fetch('to').blank? || tx.fetch('value').hex.to_d <= 0
        next unless PaymentAddress.where(address: tx.fetch('to')).exists? # filter received

        {
            id:            tx.fetch('hash'),
            confirmations: calculate_confirmations(current_block.fetch('number').hex),
            received_at:   Time.at(current_block.fetch('timestamp').hex),
            entries:       [{ amount:  convert_from_base_unit(tx.fetch('value').hex),
                              address: normalize_address(tx['to']) }]
        }
      end.compact
    end

    def block_information(index)
      json_rpc(:eth_getBlockByNumber, [index, false]).fetch('result')
    end

    def permit_transaction(issuer, recipient)
      json_rpc(:personal_unlockAccount, [normalize_address(issuer.fetch(:address)), issuer.fetch(:secret), '0x' + 5.to_s(16)]).tap do |response|
        unless response.fetch('result')
          raise CoinAPI::Error, "ETH withdrawal from #{issuer.fetch(:address)} to #{recipient.fetch(:address)} failed."
        end
      end
    end

    def abi_encode(method, *args)
      '0x' + args.each_with_object(Digest::SHA3.hexdigest(method, 256)[0...8]) do |arg, data|
        data.concat(arg.gsub(/\A0x/, '').rjust(64, '0'))
      end
    end

    def abi_explode(data)
      data = data.gsub(/\A0x/, '')
      { method:    '0x' + data[0...8],
        arguments: data[8..-1].chars.in_groups_of(64, false).map { |group| '0x' + group.join } }
    end

    def valid_address?(address)
      # address.to_s.match?(/\A0x[A-F0-9]{40}\z/i)
      address.to_s =~ /\A0x[A-F0-9]{40}\z/i
    end

    def valid_txid?(txid)
      # txid.to_s.match?(/\A0x[A-F0-9]{64}\z/i)
      txid.to_s =~ /\A0x[A-F0-9]{64}\z/i
    end

    def calculate_confirmations(block_number)
      return 0 unless block_number.present?

      latest_block_number - block_number
    end

    def latest_block_number
      Rails.cache.fetch "latest_#{currency.code}_block_number".to_sym, expires_in: 5.seconds do
        json_rpc(:eth_blockNumber).fetch('result').hex
      end
    rescue StandardError => e
      0
    end

    def earliest_block
      7_733_385 # start blocknumber : 10th, May, 19
    end
  end
end
