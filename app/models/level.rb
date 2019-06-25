class Level < ActiveYamlBase

  def self.enumerize
    all.inject({}) {|hash, i| hash[i.id] = i.id; hash}
  end

end
