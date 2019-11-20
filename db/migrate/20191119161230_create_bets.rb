class CreateBets < ActiveRecord::Migration
  def change
    create_table :bets do |t|
      t.integer :member_id
      t.decimal :credit, precision: 32, scale: 16, null: false, default: 0.0
      t.decimal :fee, precision: 32, scale: 16, null: false, default: 0.0
      t.boolean :even_odd
      t.boolean :result
      t.decimal :bonus, precision: 32, scale: 16, null: false, default: 0.0
      t.timestamps
    end
  end
end
