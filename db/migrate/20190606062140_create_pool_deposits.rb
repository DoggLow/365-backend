class CreatePoolDeposits < ActiveRecord::Migration
  def change
    create_table :pool_deposits do |t|
      t.integer :member_id, null: false
      t.integer :unit, null: false
      t.integer :amount, null: false, default: 0
      t.integer :currency, null: false
      t.decimal :org_total, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :fee, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :remained, precision: 32, scale: 16, null: false, default: 0.0
      t.timestamps
    end

    add_index :pool_deposits, :member_id, using: :btree
  end
end
