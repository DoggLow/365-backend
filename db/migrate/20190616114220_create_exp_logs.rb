class CreateExpLogs < ActiveRecord::Migration
  def change
    create_table :exp_logs do |t|
      t.integer :member_id, null: false
      t.integer :reason
      t.integer :amount, null: false, default: 0
      t.integer :value, null: false, default: 0
      t.references :modifiable, polymorphic: true
      t.timestamps

      t.index [:modifiable_id, :modifiable_type]
    end

    add_index :exp_logs, :member_id, using: :btree
  end
end
