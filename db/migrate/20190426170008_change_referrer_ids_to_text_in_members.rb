class ChangeReferrerIdsToTextInMembers < ActiveRecord::Migration
  def change
    change_column :members, :referrer_ids, :text, default: nil
  end
end
