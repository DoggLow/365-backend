class AddSettings < ActiveRecord::Migration
  def change
    create_table :settings do |t|
      t.integer  :maintenance_margin, limit: 1, null: false, default: 20
      t.integer  :initial_margin, limit: 1, null: false, default: 40
    end
  end
end
