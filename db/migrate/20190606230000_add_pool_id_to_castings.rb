class AddPoolIdToCastings < ActiveRecord::Migration
  def change
    add_column :castings, :pool_id, :integer, :after => :distribution
  end
end
