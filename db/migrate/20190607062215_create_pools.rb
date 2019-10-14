class CreatePools < ActiveRecord::Migration
  def change
    create_table :pools do |t|
      t.integer :member_id, null: false
      t.integer :account_id, null: false
      t.integer :currency, null: false
      t.integer :kind, null: false, default: 1
      t.decimal :balance, precision: 32, scale: 16, null: false, default: 0.0
      t.timestamps
    end

    add_index :pools, [:member_id, :currency]
    add_index :pools, :member_id, using: :btree
  end
end
