class WorkProof < ActiveRecord::Base
  self.table_name = 'work_proofs' # Explicitly define the table name

  # Status constants
  STATUS_PENDING = 'pending'
  STATUS_CLOCKED_IN = 'clocked_in'
  STATUS_CLOCKED_OUT = 'clocked_out'
  STATUS_CALCULATED = 'calculated'
  STATUS_CONSOLIDATED = 'consolidated'

  belongs_to :project
  belongs_to :issue, class_name: 'Issue'
  belongs_to :user, class_name: 'User'
  belongs_to :activity, class_name: 'TimeEntryActivity', optional: true
  belongs_to :time_entry, class_name: 'TimeEntry', optional: true

  validates :project_id, :issue_id, :user_id, :date, :image_url, presence: true
  validates :work_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, inclusion: { in: [STATUS_PENDING, STATUS_CLOCKED_IN, STATUS_CLOCKED_OUT, STATUS_CALCULATED, STATUS_CONSOLIDATED] }
  
  # Scopes for common queries
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_date, ->(date) { where(date: date) }
  scope :date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }
  scope :pending, -> { where(status: [STATUS_PENDING, STATUS_CLOCKED_IN]) }
  scope :not_consolidated, -> { where(consolidated: false) }
  scope :needs_auto_consolidation, -> { 
    where(status: [STATUS_PENDING, STATUS_CLOCKED_IN])
      .where('clocked_in_at < ?', 4.hours.ago)
      .not_consolidated
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
  
  # Time tracking methods
  def clocked_in?
    status == STATUS_CLOCKED_IN
  end
  
  def clocked_out?
    status == STATUS_CLOCKED_OUT || status == STATUS_CALCULATED
  end
  
  def consolidated?
    status == STATUS_CONSOLIDATED || consolidated == true
  end
  
  def clock_duration
    return 0 unless clocked_in_at
    end_time = clocked_out_at || Time.current
    ((end_time - clocked_in_at) / 3600.0).round(2) # Convert seconds to hours
  end
  
  def needs_auto_consolidation?
    (status == STATUS_PENDING || status == STATUS_CLOCKED_IN) && 
    clocked_in_at.present? && 
    clocked_in_at < 4.hours.ago &&
    !consolidated?
  end
  
  # API-friendly representation
  def as_json(options = {})
    merge_options = { 
      methods: [:user_name, :issue_subject, :project_name, :activity_name, :clock_duration],
      except: []
    }
    merge_options[:except] = [:created_at, :updated_at] unless options[:include_timestamps]
    super(options.merge(merge_options))
  end
end