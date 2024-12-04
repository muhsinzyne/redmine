class WorkProof < ActiveRecord::Base
  self.table_name = 'work_proofs' # Explicitly define the table name

  belongs_to :project
  belongs_to :issue, class_name: 'Issue'
  belongs_to :user, class_name: 'User'

  validates :project_id, :issue_id, :user_id, :date, :image_url, presence: true
end