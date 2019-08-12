class AddPldToPurchaseOptions < ActiveRecord::Migration
  def change
    remove_column :purchase_options, :lot_unit
    add_column :purchase_options, :pld_usd, :decimal, precision: 32, scale: 16, default: 0, null: false
    add_column :purchase_options, :pldp_usd, :decimal, precision: 32, scale: 2, default: 0.15, null: false
  end
end
