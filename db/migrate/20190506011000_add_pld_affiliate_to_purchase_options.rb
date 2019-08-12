class AddPldAffiliateToPurchaseOptions < ActiveRecord::Migration
  def change
    rename_column :purchase_options, :affiliate_fee, :tsf_aff_fee
    add_column :purchase_options, :pld_aff_fee, :decimal, precision: 32, scale: 2, default: 5, null: false
    add_column :purchase_options, :pld_completion_date, :datetime
  end
end
