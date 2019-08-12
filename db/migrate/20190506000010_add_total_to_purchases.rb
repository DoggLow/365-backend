class AddTotalToPurchases < ActiveRecord::Migration
  def change
    add_column :purchases, :product_rate, :decimal, precision: 32, scale: 16, default: 0.0, null: false
    add_column :purchases, :volume, :decimal, precision: 32, scale: 16, default: 0.0, null: false
    add_column :purchases, :filled_volume, :decimal, precision: 32, scale: 16, default: 0.0, null: false
    add_column :purchases, :aasm_state, :string
  end
end
