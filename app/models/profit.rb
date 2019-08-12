class Profit < ActiveRecord::Base
  include Currencible

  belongs_to :modifiable, polymorphic: true
  belongs_to :member

end
