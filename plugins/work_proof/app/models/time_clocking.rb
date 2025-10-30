class TimeClocking < ActiveRecord::Base
  self.table_name = 'time_clockings'

  # Status constants
  STATUS_PENDING = 'pending'
  STATUS_CONSOLIDATED = 'consolidated'

  belongs_to :project
  belongs_to :issue, class_name: 'Issue'
  belongs_to :user, class_name: 'User'
  belongs_to :activity, class_name: 'TimeEntryActivity', optional: true
  belongs_to :time_entry, class_name: 'TimeEntry', optional: true

  validates :project_id, :issue_id, :user_id, :date, presence: true
  validates :time_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, inclusion: { in: [STATUS_PENDING, STATUS_CONSOLIDATED] }, allow_nil: true
  
  # Scopes for common queries
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_issue, ->(issue_id) { where(issue_id: issue_id) }
  scope :for_date, ->(date) { where(date: date) }
  scope :date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }
  scope :pending, -> { where(status: STATUS_PENDING).or(where(status: nil)) }
  scope :not_consolidated, -> { where(consolidated: [false, nil]) }
  scope :needs_auto_consolidation, -> { 
    # Time clockings older than 4 hours that haven't been consolidated
    where('created_at < ?', 4.hours.ago)
      .where(consolidated: [false, nil])
      .where(status: [STATUS_PENDING, nil])
  }
  
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
  
  def activity_name
    activity&.name
  end
  
  def consolidated?
    status == STATUS_CONSOLIDATED || consolidated == true
  end
  
  # API-friendly representation
  def as_json(options = {})
    merge_options = { 
      methods: [:user_name, :issue_subject, :project_name, :activity_name],
      except: []
    }
    merge_options[:except] = [:created_at, :updated_at] unless options[:include_timestamps]
    super(options.merge(merge_options))
  end
end

