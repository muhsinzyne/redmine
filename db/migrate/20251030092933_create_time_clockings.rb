class CreateTimeClockings < ActiveRecord::Migration[6.1]
  def change
    create_table :time_clockings do |t|
      t.integer :project_id, null: false
      t.integer :issue_id, null: false
      t.integer :user_id, null: false
      t.date :date, null: false
      t.integer :activity_id
      t.decimal :time_hours, precision: 5, scale: 2
      t.text :description
      t.string :status, default: 'pending'
      t.boolean :consolidated, default: false
      t.datetime :consolidated_at
      t.integer :time_entry_id

      t.timestamps
    end
    
    add_index :time_clockings, :project_id
    add_index :time_clockings, :issue_id
    add_index :time_clockings, :user_id
    add_index :time_clockings, :date
    add_index :time_clockings, :activity_id
    add_index :time_clockings, :status
    add_index :time_clockings, :consolidated
    add_index :time_clockings, :time_entry_id
  end
end
