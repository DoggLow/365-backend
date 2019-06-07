class AddModifiableToReferrals < ActiveRecord::Migration
  def change
    change_table :referrals do |t|
      t.references :modifiable, polymorphic: true
      t.index [:modifiable_id, :modifiable_type]
    end
  end
end
