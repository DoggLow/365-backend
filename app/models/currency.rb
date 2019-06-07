class Currency < ActiveYamlBase
  include International
  include ActiveHash::Associations

  field :visible, default: true

  self.singleton_class.send :alias_method, :all_with_invisible, :all

  def self.all
    all_with_invisible.select &:visible
  end

  def self.enumerize
    all_with_invisible.inject({}) {|memo, i| memo[i.code.to_sym] = i.id; memo}
  end

  def self.codes
    @codes ||= all.map &:code
  end

  def self.coin_codes
    @coin_codes ||= coins.map &:code
  end

  def self.ids
    @ids ||= all.map &:id
  end

  def self.coins
    find_all_by_type('coin')
  end

  def self.assets(code)
    find_by_code(code)[:assets]
  end

  def blacklist
    self[:blacklist]
  end

  def precision
    self[:precision]
  end

  def api
    raise unless coin?
    CoinAPI[code]
  end

  def coin?
    type.casecmp('coin').zero?
  end

  def fiat?
    not coin?
  end

  def erc20?
    api_client.casecmp('ERC20').zero?
  end

  def neo_gas_or_nep5?
    api_client.casecmp('NEP5').zero? || code.casecmp('gas').zero?
  end

  def balance_cache_key
    "exchange:hotwallet:#{code}:balance"
  end

  def balance
    Rails.cache.read(balance_cache_key) || 0
  end

  def confirmation
    self.try(:max_confirmation) || 3
  end

  def decimal_digit
    self.try(:default_decimal_digit) || (fiat? ? 2 : 4)
  end

  def upcase_code
    code.upcase
  end

  def refresh_balance
    Rails.cache.write(balance_cache_key, api.load_balance || 'N/A') if coin?
  end

  def blockchain_url(txid)
    raise unless coin?
    blockchain.gsub('#{txid}', txid.to_s)
  end

  def address_url(address)
    raise unless coin?
    self[:address_url].try :gsub, '#{address}', address
  end

  def quick_withdraw_max
    @quick_withdraw_max ||= BigDecimal.new(self.withdraw['quick_max'], 8)
  end

  def as_json(options = {})
    {
        id: id,
        name: name,
        code: code,
        symbol: symbol,
        coin: coin?,
        info_url: info_url,
        precision: precision,
        confirmation: confirmation,
        case_sensitive: case_sensitive,
        withdraw: withdraw,
        visible: visible
    }
  end

  def summary
    locked = Account.locked_sum(code)
    balance = Account.balance_sum(code)
    sum = locked + balance

    coinable = self.coin?
    hot = coinable ? self.balance : nil

    {
        name: self.code.upcase,
        sum: sum,
        balance: balance,
        locked: locked,
        coinable: coinable,
        hot: hot
    }
  end
end
