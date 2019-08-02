class UpdatePurchases < ActiveRecord::Migration
  def change
    change_column :purchases, :amount, :integer, after: :member_id
    rename_column :purchases, :amount, :product_count
    rename_column :purchases, :price, :rate
    rename_column :purchases, :total, :amount
    add_column :purchases, :product_id, :integer, null: false, after: :member_id
    add_column :purchases, :sale_rate, :decimal, precision: 32, scale: 16, default: 0.0, null: false, after: :product_count
    add_column :purchases, :fiat, :string, limit: 10, null: false, after: :member_id
    remove_column :purchases, :unit
  end
end
