module CoinAPI
  class ERC20 < ETH

    TRANSFER_IDENTIFIER = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'

    def contract_address
      normalize_address(currency.erc20_contract_address)
    end

    def new_address!
      MethodNotImplemented
    end

    def load_balance_of!(address)
      balance = 0

      begin
        return total if address.nil?

        data = abi_encode('balanceOf(address)', address)
        balance = json_rpc(:eth_call, [{ to: contract_address, data: data }, 'latest']).fetch('result').hex.to_d
      rescue StandardError => e
        Rails.logger.unknown e.inspect
      end

      convert_from_base_unit(balance)
    end

    def load_balance!
      total = 0

      PaymentAddress.where(currency: Currency.find_by_code('eth').id).each do |a|
        begin
          next if a.address.nil?

          total += load_balance_of!(a.address)
        rescue StandardError => e
          Rails.logger.unknown e.inspect
          next
        end
      end

      total
    end

    def load_deposit!(txid)
      tx = json_rpc(:eth_getTransactionReceipt, [txid]).fetch('result')
      return {} unless tx['status'] == '0x1'

      entries = tx['logs'].each_with_object([]) do |log, result|
        next unless log['topics'].first == TRANSFER_IDENTIFIER
        next unless normalize_address(log.fetch('address')) == contract_address

        result << {
            amount: convert_from_base_unit(log.fetch('data').hex),
            address: normalize_address('0x' + log.fetch('topics').last[-40..-1])
        }
      end

      {
          id: normalize_txid(tx.fetch('transactionHash')),
          confirmations: calculate_confirmations(tx.fetch('blockNumber').hex),
          entries: entries
      }
    end

    protected

    def send_transaction(issuer, recipient, amount, options = {})
      data = abi_encode(
          'transfer(address,uint256)',
          normalize_address(recipient.fetch(:address)),
          '0x' + convert_to_base_unit!(amount).to_s(16)
      )
      response = json_rpc(
          :eth_sendTransaction,
          [{
               from: normalize_address(issuer.fetch(:address)),
               to:    contract_address,
               data:  data
           }.reject { |_, v| v.nil? }]
      )
      if response['error'] # ERROR
        raise CoinAPI::ETH::TransactionError
      else
        response.fetch('result')
      end
    end

    def collect_deposits(current_block)
      txs = current_block.fetch('transactions')
      txs.map do |tx|
        # Skip contract creation transactions.
        next if tx['to'].blank?
        next unless normalize_address(tx['to']) == contract_address

        # Skip transactions without data.
        next if tx['input'].blank? || tx['input'].hex <= 0

        input_data = abi_explode(tx['input'])
        next if input_data.nil?
        next unless input_data[:method] == '0xa9059cbb' # ERC20 transfer

        arguments = input_data[:arguments]
        next if arguments[1].blank?
        {
            id: normalize_txid(tx.fetch('hash')),
            confirmations: calculate_confirmations(current_block.fetch('number').hex),
            received_at:   Time.at(current_block.fetch('timestamp').hex),
            entries: [{ amount:  convert_from_base_unit(arguments[1].hex),
                        address: normalize_address('0x' + arguments[0][26..-1]) }]
        }
      end.compact
    end
  end
end
