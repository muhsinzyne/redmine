class WorkProof < ActiveRecord::Base
  self.table_name = 'work_proofs' # Explicitly define the table name

  belongs_to :project
  belongs_to :issue, class_name: 'Issue'
  belongs_to :user, class_name: 'User'

  validates :project_id, :issue_id, :user_id, :date, :image_url, presence: true
  validates :work_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes for common queries
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_date, ->(date) { where(date: date) }
  scope :date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }
  
  # Helper methods for API responses
  def user_name
    "#{user.firstname} #{user.lastname}".strip
  end
  
  def issue_subject
    issue.subject
  end
  
  def project_name
    project.name
  end
  
  # API-friendly representation
  def as_json(options = {})
    merge_options = { methods: [:user_name, :issue_subject, :project_name] }
    merge_options[:except] = [:created_at, :updated_at] unless options[:include_timestamps]
    super(options.merge(merge_options))
  end
end