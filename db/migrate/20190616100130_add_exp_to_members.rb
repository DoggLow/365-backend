class AddExpToMembers < ActiveRecord::Migration
  def change
    add_column :members, :exp, :integer, null: false, default: 0
    add_column :members, :cc_level, :integer, null: false, default: 1
  end
end
