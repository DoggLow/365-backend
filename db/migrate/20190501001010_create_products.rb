class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name, limit: 50
      t.integer :currency, null: false
      t.string :sales_unit, limit: 10, null: false
      t.integer :sales_price, null: false, default: 0
      t.timestamps
      t.datetime :deleted_at
    end
  end
end
