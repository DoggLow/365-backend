class AddRewardsToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :rewards, :decimal, precision: 32, scale: 16, default: 0, null: false
    add_column :accounts, :rewarded_at, :datetime
  end
end
