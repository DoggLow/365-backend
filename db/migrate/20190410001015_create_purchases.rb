class CreatePurchases < ActiveRecord::Migration
  def change
    create_table :purchases do |t|
      t.integer  :member_id, null: false
      t.integer  :currency, null: false
      t.integer  :unit, null: false, default: 0
      t.integer  :amount, null: false, default: 0
      t.decimal  :price, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal  :total, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal  :fee, precision: 32, scale: 16, null: false, default: 0.0
      t.timestamps
    end

    add_index :purchases, :member_id, using: :btree
  end
end
