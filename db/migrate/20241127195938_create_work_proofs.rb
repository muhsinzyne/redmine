class CreateWorkProofs < ActiveRecord::Migration[5.2]
  def change
    create_table :work_proofs do |t|
      t.integer :project_id, null: false
      t.integer :issue_id, null: false
      t.integer :user_id, null: false
      t.date :date, null: false
      t.string :image_url, null: false

      t.timestamps
    end

    add_index :work_proofs, :project_id
    add_index :work_proofs, :issue_id
    add_index :work_proofs, :user_id
    add_index :work_proofs, :date
  end
end