class UpdateIdDocuments < ActiveRecord::Migration
  def change
    add_column :id_documents, :gender, :integer, :after => :birth_date, default: 1
    add_column :id_documents, :state,    :string, :after => :city
  end
end
