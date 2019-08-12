class PurchaseOption < ActiveRecord::Base
  class << self
    def get(option)
      find_or_create_by(id: 1).instance_eval(option)
    rescue StandardError => e
      0
    end

    def set(option, value)
      find_or_create_by(id: 1).update!("#{option}": value)
    rescue StandardError => e
      puts e
    end
  end
end
