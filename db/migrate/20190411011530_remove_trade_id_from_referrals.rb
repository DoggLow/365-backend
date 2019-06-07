class RemoveTradeIdFromReferrals < ActiveRecord::Migration
  def change
    remove_column :referrals, :trade_id
  end
end
