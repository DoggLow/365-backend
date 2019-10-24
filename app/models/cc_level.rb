class CcLevel < ActiveYamlBase

  def self.enumerize
    all.inject({}) {|hash, i| hash[i.id] = i.id; hash}
  end

  def self.get_level(exp, lvl = 1)
    level = lvl
    last = all.last
    if exp >= last[:exp]
      last.id
    else
      all.each do |cc_level|
        if exp < cc_level[:exp]
          level = cc_level.id
          break
        end
      end
      level > 1 ? level - 1 : level
    end
  end

  def self.to_up(exp)
    current = get_level(exp)
    next_level = find_by_id(current + 1)
    if next_level.present?
      next_level[:exp] - exp
    else
      0
    end
  end
end
