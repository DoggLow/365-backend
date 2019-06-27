class CreateInvests < ActiveRecord::Migration
  def change
    create_table :invests do |t|
      t.integer  :member_id, null: false
      t.integer  :currency, null: false
      t.integer  :unit, null: false, default: 0
      t.integer  :count, null: false, default: 0
      t.decimal  :profit, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal  :paid_profit, precision: 32, scale: 16, null: false, default: 0.0
      t.string :aasm_state
      t.timestamps
    end

    add_index :invests, :member_id, using: :btree
  end
end
