class AddTimestampsToReferrals < ActiveRecord::Migration
  def change
    add_column :referrals, :created_at, :datetime, null: false
    add_column :referrals, :updated_at, :datetime, null: false
  end
end
