class CreateBets < ActiveRecord::Migration
  def change
    create_table :bets do |t|
      t.integer :member_id
      t.decimal :unit, precision: 32, scale: 16, null: false, default: 0.0
      t.integer :amount, null: false
      t.integer :expectancy
      t.integer :result
      t.decimal :fee, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :bonus, precision: 32, scale: 16, null: false, default: 0.0
      t.string :aasm_state
      t.timestamps
    end

    add_index :bets, :member_id, using: :btree
  end
end
