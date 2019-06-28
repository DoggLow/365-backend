class UpdatePurchaseOptions < ActiveRecord::Migration
  def change
    add_column :purchase_options, :tsfp_usd, :decimal, precision: 32, scale: 2, default: 1, null: false
    add_column :purchase_options, :tsfp_fee, :integer, default: 1, limit: 1, null: false
  end
end
