class AddTimeTrackingToWorkProofs < ActiveRecord::Migration[6.1]
  def change
    add_column :work_proofs, :activity_id, :integer
    add_column :work_proofs, :clocked_in_at, :datetime
    add_column :work_proofs, :clocked_out_at, :datetime
    add_column :work_proofs, :consolidated, :boolean
    add_column :work_proofs, :consolidated_at, :datetime
    add_column :work_proofs, :time_entry_id, :integer
  end
end
