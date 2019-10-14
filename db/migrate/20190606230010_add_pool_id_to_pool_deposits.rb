class AddPoolIdToPoolDeposits < ActiveRecord::Migration
  def change
    add_column :pool_deposits, :pool_id, :integer, :after => :remained
  end
end
