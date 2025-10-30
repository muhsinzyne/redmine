class AddFieldsToWorkProofs < ActiveRecord::Migration[6.1]
  def change
    add_column :work_proofs, :description, :text
    add_column :work_proofs, :work_hours, :decimal, precision: 5, scale: 2
    add_column :work_proofs, :status, :string, default: 'pending'
  end
end
