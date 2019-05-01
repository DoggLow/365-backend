class AddRefIdToMembers < ActiveRecord::Migration
  def change
    add_column :members, :ref_id, :string
  end
end
