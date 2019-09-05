class AddDistributedPldToPurchaseOptions < ActiveRecord::Migration
  def change
    add_column :purchase_options, :distributed_pld, :decimal, precision: 32, scale: 16, default: 0, null: false
  end
end
