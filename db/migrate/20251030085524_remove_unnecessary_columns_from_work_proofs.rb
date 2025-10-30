class RemoveUnnecessaryColumnsFromWorkProofs < ActiveRecord::Migration[6.1]
  def change
    # Remove time tracking columns - not needed
    # We calculate time by counting work_proofs per issue
    remove_column :work_proofs, :clocked_in_at, :datetime if column_exists?(:work_proofs, :clocked_in_at)
    remove_column :work_proofs, :clocked_out_at, :datetime if column_exists?(:work_proofs, :clocked_out_at)
    remove_column :work_proofs, :work_hours, :decimal if column_exists?(:work_proofs, :work_hours)
    
    # Keep these - they're useful:
    # - activity_id: needed for time_entries
    # - time_entry_id: links to consolidated time_entry
    # - consolidated: flag to show it's been processed
    # - consolidated_at: when it was processed
    # - status: pending or consolidated
    # - description: optional note
  end
end
