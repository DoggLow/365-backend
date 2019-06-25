class UpdateMembers < ActiveRecord::Migration
  def change
    add_column :members, :level, :integer, default: 0, limit: 1, null: false
    add_column :members, :commission_status, :boolean, default: false, null: false
  end
end
