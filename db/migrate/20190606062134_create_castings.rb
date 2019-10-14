class CreateCastings < ActiveRecord::Migration
  def change
    create_table :castings do |t|
      t.integer :member_id, null: false
      t.integer :unit, null: false
      t.integer :amount, null: false, default: 0
      t.integer :currency, null: false
      t.decimal :paid_amount, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :paid_fee, precision: 32, scale: 16, null: false, default: 0.0
      t.integer :market_id, null: false
      t.integer :ask
      t.integer :bid
      t.decimal :ask_locked, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :bid_locked, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :ask_org_locked, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :bid_org_locked, precision: 32, scale: 16, null: false, default: 0.0
      t.text :ask_distributions, null: false
      t.text :bid_distributions, null: false
      t.decimal :org_distribution, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :distribution, precision: 32, scale: 16, null: false, default: 0.0
      t.integer :distribution_times, null: false, default: 0
      t.string :aasm_state
      t.timestamps
    end

    add_index :castings, :member_id, using: :btree
  end
end
