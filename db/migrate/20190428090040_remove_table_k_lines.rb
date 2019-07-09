class RemoveTableKLines < ActiveRecord::Migration
  def change
    drop_table :k_lines
  end
end
