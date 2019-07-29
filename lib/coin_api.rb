module CoinAPI
  Error                  = Class.new(StandardError) # TODO: Rename to Exception.
  ConnectionRefusedError = Class.new(StandardError) # TODO: Remove this.

  class << self
    #
    # Returns API client for given currency code.
    #
    # @param code [String, Symbol]
    #   The currency code. May be uppercase or lowercase.
    # @return [BaseAPI]
    def [](code)
      currency = Currency.find_by_code(code.to_s)
      raise Error, "Couldn't find currency with code #{code.inspect}." unless currency

      if currency.try(:api_client).present?
        "CoinAPI::#{currency.api_client.camelize}"
      else
        "CoinAPI::#{code.upcase}"
      end.constantize.new(currency)
    end
  end

  class BaseAPI
    extend Memoist

    #
    # Returns the currency.
    #
    # @return [Currency]
    attr_reader :currency

    def initialize(currency)
      @currency = currency
    end

    #
    # Returns hot wallet balance.
    #
    # @abstract Derived API clients must implement it.
    # @return [BigDecimal]
    def load_balance!
      method_not_implemented
    end

    def load_balance_of!(address)
      method_not_implemented
    end

    #
    # TODO: Docs.
    #
    # @abstract Derived API clients must implement it.
    # @return [Array<Hash>]
    def each_deposit
      method_not_implemented
    end

    #
    # TODO: Docs.
    #
    # @abstract Derived API clients must implement it.
    # @return [Array<Hash>]
    def each_deposit!
      method_not_implemented
    end

    #
    # Returns transaction details.
    #
    # TODO: Docs.
    #
    # @param txid [String]
    # @return [Hash]
    #   The deposit details.
    def load_deposit!(txid)
      method_not_implemented
    end

    #
    # Created new address.
    #
    # TODO: Doc.
    #
    def new_address!(options = {})
      method_not_implemented
    end

    #
    # Creates new withdrawal and returns transaction ID.
    #
    # TODO: Doc.
    #
    def create_withdrawal!(issuer, recipient, amount, options = {})
      method_not_implemented
    end

    # TODO: Doc.
    def validate_address!(address)
      method_not_implemented
    end

    #
    # get block height.
    #
    def local_block_height
      latest_block_number
    end

    def convert_to_base_unit!(value)
      x = value.to_d * currency.base_factor
      unless (x % 1).zero?
        raise CoinAPI::Error, "Failed to convert value to base (smallest) unit because it exceeds the maximum precision: " +
            "#{value.to_d} - #{x.to_d} must be equal to zero."
      end
      x.to_i
    end

    def convert_from_base_unit(value)
      value.to_d / currency.base_factor
    end

    def normalize_address(address)
      currency.case_sensitive? ? address : address.downcase
    end

    def normalize_txid(txid)
      currency.case_sensitive? ? txid : txid.downcase
    end

    %i[ load_balance load_deposit new_address create_withdrawal validate_address ].each do |method|
      class_eval <<-RUBY
        def #{method}(*args, &block)
          silencing_exception { #{method}!(*args, &block) }
        end
      RUBY
    end

    protected

    #
    # cached local block height.
    #
    # TODO: Doc.
    #
    def latest_block_number
      method_not_implemented
    end

    def silencing_exception
      yield
    rescue StandardError => e
      Rails.logger.info e.inspect
      nil
    end
  end
end
