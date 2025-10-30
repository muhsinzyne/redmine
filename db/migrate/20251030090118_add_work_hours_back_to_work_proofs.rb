class AddWorkHoursBackToWorkProofs < ActiveRecord::Migration[6.1]
  def change
    add_column :work_proofs, :work_hours, :decimal, precision: 5, scale: 2
  end
end
