class CreatePoolWithdraws < ActiveRecord::Migration
  def change
    create_table :pool_withdraws do |t|
      t.integer :member_id, null: false
      t.integer :account_id, null: false
      t.integer :currency, null: false
      t.decimal :amount, precision: 32, scale: 16, null: false, default: 0.0
      t.references :modifiable, polymorphic: true
      t.string :aasm_state
      t.timestamps

      t.index [:modifiable_id, :modifiable_type]
    end

    add_index :pool_withdraws, :member_id, using: :btree
  end
end
