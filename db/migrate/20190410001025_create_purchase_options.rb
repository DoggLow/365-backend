class CreatePurchaseOptions < ActiveRecord::Migration
  def change
    create_table :purchase_options do |t|
      t.integer  :lot_unit, null: false, default: 500
      t.decimal  :tsf_usd, precision: 32, scale: 2, null: false, default: 0.15
      t.decimal  :affiliate_fee, precision: 5, scale: 2, null: false, default: 20.0
    end
  end
end
