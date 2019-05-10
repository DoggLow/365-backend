module CoinAPI
  class XEM < BaseAPI
    TIME_NEMESIS = Time.utc(2015, 3, 29, 0, 6, 25, 0)
    TRANSFER_V1 = 1744830465 # -1744830463: Testnet, 1744830465: Mainnet
    TRANSFER_V2 = 1744830466 # -1744830462: Testnet, 1744830466: Mainnet

    # 2_146_400: Mainnet: 11th, May
    # 1_935_680: Testnet: 11th, Apr
    START_BLOCK = 2_146_400

    def initialize(*)
      super
      @json_rpc_endpoint = URI.parse(currency.rpc)
    end

    def load_balance!
      total = 0

      PaymentAddress.where(currency: currency.id).each do |a|
        total += load_balance_of!(a.address)
      end

      total
    end

    def load_balance_of!(address)
      balance = 0
      begin
        balance = account_info(normalize_address(address)).fetch('balance').to_d unless address.blank?
      rescue StandardError => e
        Rails.logger.unknown e.inspect
      end

      convert_from_base_unit(balance)
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
      tx_object = json_rpc('get', 'transaction/get', {hash: tx_id})
      meta_data = tx_object.fetch('meta')
      tx = tx_object.fetch('transaction')
      version = tx.fetch('version')
      if version == TRANSFER_V1
        amount = convert_from_base_unit(tx.fetch('amount'))
      else # version == TRANSFER_V2
        mosaic_obj = tx.fetch('mosaics').find{|mosaic| mosaic.fetch('mosaicId').fetch('name') == currency.code}
        amount = convert_from_base_unit(mosaic_obj.fetch('quantity'))
      end

      {
          id:            normalize_txid(meta_data.fetch('hash').fetch('data')),
          confirmations: calculate_confirmations(meta_data.fetch('height')),
          received_at:   TIME_NEMESIS + tx.fetch('timeStamp'),
          entries:       [{
                              amount: amount,
                              address: normalize_address(tx.fetch('recipient'))
                          }]
      }
    end

    def new_address!(options = {})
      response = json_rpc('get', 'account/generate')
      {
          address: normalize_address(response.fetch('address')),
          secret: response.fetch('privateKey'),
          tag: response.fetch('publicKey'),
      }
    end

    def create_withdrawal!(_issuer, recipient, amount, options = {})
      timestamp = (Time.now.utc - TIME_NEMESIS).to_i
      fee = calc_fee(amount)
      post_body = {
          transaction: {
              amount: convert_to_base_unit!(amount),
              fee: convert_to_base_unit!(fee),
              recipient: normalize_address(recipient.fetch(:address)),
              signer: _issuer.fetch(:tag),
              type: 257, # 0x101: Transfer of NEM
              timeStamp: timestamp - 30, # within 1 Min
              deadline: timestamp + 3600, # Expire after 1 Hr
              version: TRANSFER_V1
          },
          privateKey: _issuer.fetch(:secret)
      }

      response = json_rpc('post', 'transaction/prepare-announce', post_body)

      if response.fetch('code') == 1 # success
        response.fetch('transactionHash').fetch('data')
      else
        raise Error, response.fetch('message')
      end
    end

    def validate_address!(address)
      {
          address:  normalize_address(address),
          is_valid: valid_address?(normalize_address(address))
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

    def json_rpc(request, path, params = {})
      response = connection.send(request) do |req|
        req.url path
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
      response['error'].tap { |error| raise Error, error.inspect if error }
      response
    end

    def batch_deposit(raise = true)
      collected       = []
      last_checked = Rails.cache.read "last_checked_#{currency.code}_block"

      start_block = last_checked ? last_checked : START_BLOCK
      start_block = latest_block_number if latest_block_number < start_block

      blocks = json_rpc('post', 'local/chain/blocks-after', {height: start_block}).fetch('data')
      unless blocks.blank?
        blocks.each do |block|
          confirmations = calculate_confirmations(block.fetch('block').fetch('height'))
          deposits = collect_deposits(block.fetch('txes'), confirmations)
          collected += deposits unless deposits.blank?
        end

        Rails.cache.write("last_checked_#{currency.code}_block", start_block + blocks.length, force: true)
      end

      yield collected
    end

    def collect_deposits(txes, confirmations)
      txes.map do |tx_object|
        tx = tx_object.fetch('tx')
        version = tx.fetch('version')
        next unless (version == TRANSFER_V1 || version == TRANSFER_V2)
        recipient = tx['recipient']
        next if recipient.blank?
        recipient = normalize_address(recipient)
        next unless PaymentAddress.where(address: recipient).exists? # not incoming transaction

        if version == TRANSFER_V1
          amount = convert_from_base_unit(tx.fetch('amount'))
        else # version == TRANSFER_V2
          mosaic_obj = tx.fetch('mosaics').find{|mosaic| mosaic.fetch('mosaicId').fetch('name') == currency.code}
          next if mosaic_obj.blank?
          amount = convert_from_base_unit(mosaic_obj.fetch('quantity'))
        end
        {
            id:            normalize_txid(tx_object.fetch('hash')),
            confirmations: confirmations,
            received_at:   TIME_NEMESIS + tx.fetch('timeStamp'),
            entries:       [{
                                amount: amount,
                                address: recipient
                            }]
        }
      end.compact
    end

    def account_info(address)
      json_rpc('get', 'account/get',{address: address}).fetch('account')
    end

    def calc_fee(amount)
      fee = amount / 10_000
      fee = 1 if fee < 1
      fee = 25 if fee > 25
      fee * 0.05
    end

    def valid_address?(address)
      address.to_s =~ /\AN[A-Z0-9]{39}\z/ # Mainnet address format
      # address.to_s =~ /\AT[A-Z0-9]{39}\z/ # Testnet address format
    end

    def calculate_confirmations(block_number)
      return 0 unless block_number.present?

      latest_block_number - block_number
    end

    def latest_block_number
      Rails.cache.fetch "latest_#{currency.code}_block_number".to_sym, expires_in: 5.seconds do
        json_rpc('get', 'chain/height').fetch('height')
      end
    rescue StandardError => e
      0
    end
  end
end
