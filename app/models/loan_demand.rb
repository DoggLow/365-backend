class LoanDemand < OpenLoan

  has_many :active_loans, foreign_key: 'demand_id'
  belongs_to :trigger_order

  scope :matching_rule, -> { order('rate ASC, created_at ASC') }

  def compute_locked
    0
  end

end