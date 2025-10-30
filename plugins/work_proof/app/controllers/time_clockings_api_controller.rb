class TimeClockingsApiController < ApplicationController
  accept_api_auth :index, :show, :create, :update, :destroy, :consolidate_by_issue
  
  before_action :find_project
  before_action :find_time_clocking, only: [:show, :update, :destroy]
  before_action :authorize_global, only: [:create, :update, :destroy]
  before_action :check_permissions
  before_action :check_consolidate_permissions, only: [:consolidate_by_issue]
  
  # GET /projects/:project_id/time_clockings.json
  def index
    @time_clockings = if @can_monitor
      TimeClocking.where(project_id: @project.id)
    elsif @can_view_self
      TimeClocking.where(project_id: @project.id, user_id: User.current.id)
    else
      TimeClocking.none
    end
    
    # Apply filters
    @time_clockings = @time_clockings.where(user_id: params[:user_id]) if params[:user_id].present? && @can_monitor
    @time_clockings = @time_clockings.where(issue_id: params[:issue_id]) if params[:issue_id].present?
    @time_clockings = @time_clockings.where(date: params[:date]) if params[:date].present?
    @time_clockings = @time_clockings.where('date >= ?', params[:start_date]) if params[:start_date].present?
    @time_clockings = @time_clockings.where('date <= ?', params[:end_date]) if params[:end_date].present?
    
    # Pagination
    @limit = params[:limit].to_i > 0 ? params[:limit].to_i : 25
    @offset = params[:offset].to_i >= 0 ? params[:offset].to_i : 0
    
    @total_count = @time_clockings.count
    @time_clockings = @time_clockings.order(date: :desc, created_at: :desc)
                                     .limit(@limit)
                                     .offset(@offset)
    
    respond_to do |format|
      format.json { render json: time_clockings_to_json(@time_clockings) }
      format.xml { render xml: @time_clockings.to_xml(methods: [:user_name, :issue_subject]) }
    end
  end
  
  # GET /projects/:project_id/time_clockings/:id.json
  def show
    respond_to do |format|
      format.json { render json: time_clocking_to_json(@time_clocking) }
      format.xml { render xml: @time_clocking.to_xml(methods: [:user_name, :issue_subject]) }
    end
  end
  
  # POST /projects/:project_id/time_clockings.json
  def create
    @time_clocking = TimeClocking.new
    @time_clocking.project_id = params[:project_id] || @project.id
    @time_clocking.issue_id = params[:issue_id] || params.dig(:time_clocking, :issue_id)
    @time_clocking.user_id = User.current.id
    @time_clocking.date = params[:date] || params.dig(:time_clocking, :date) || Date.today
    @time_clocking.description = params[:description] || params.dig(:time_clocking, :description)
    @time_clocking.activity_id = params[:activity_id] || params.dig(:time_clocking, :activity_id)
    @time_clocking.time_hours = params[:time_hours] || params.dig(:time_clocking, :time_hours)
    @time_clocking.status = TimeClocking::STATUS_PENDING
    
    if @time_clocking.save
      respond_to do |format|
        format.json { render json: time_clocking_to_json(@time_clocking), status: :created }
        format.xml { render xml: @time_clocking.to_xml, status: :created }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @time_clocking.errors.full_messages }, status: :unprocessable_entity }
        format.xml { render xml: @time_clocking.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # PUT /projects/:project_id/time_clockings/:id.json
  def update
    if @time_clocking.update(time_clocking_params)
      respond_to do |format|
        format.json { render json: time_clocking_to_json(@time_clocking) }
        format.xml { render xml: @time_clocking.to_xml }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @time_clocking.errors.full_messages }, status: :unprocessable_entity }
        format.xml { render xml: @time_clocking.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # DELETE /projects/:project_id/time_clockings/:id.json
  def destroy
    @time_clocking.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.xml { head :no_content }
    end
  end
  
  # POST /projects/:project_id/time_clockings/consolidate_by_issue.json
  def consolidate_by_issue
    issue_id = params[:issue_id] || params.dig(:time_clocking, :issue_id)
    user_id = params[:user_id] || User.current.id
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    
    unless issue_id
      render json: { errors: ['issue_id is required'] }, status: :bad_request
      return
    end
    
    time_entry = TimeClockingConsolidationService.consolidate_by_issue(issue_id, user_id, date)
    
    if time_entry
      time_clockings = TimeClocking.where(time_entry_id: time_entry.id)
      respond_to do |format|
        format.json do
          render json: {
            time_entry: {
              id: time_entry.id,
              hours: time_entry.hours,
              spent_on: time_entry.spent_on,
              activity_id: time_entry.activity_id,
              comments: time_entry.comments,
              issue_id: time_entry.issue_id,
              user_id: time_entry.user_id
            },
            time_clockings_consolidated: time_clockings.count,
            calculation: {
              entries: time_clockings.count,
              total_hours: time_entry.hours
            }
          }, status: :ok
        end
        format.xml { render xml: { time_entry: time_entry, time_clockings_count: time_clockings.count }.to_xml, status: :ok }
      end
    else
      respond_to do |format|
        format.json { render json: { message: 'No time clockings to consolidate' }, status: :ok }
        format.xml { render xml: { message: 'No time clockings to consolidate' }.to_xml, status: :ok }
      end
    end
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_time_clocking
    @time_clocking = TimeClocking.find(params[:id])
    
    # Check if user can access this time clocking
    unless @can_monitor || (@can_view_self && @time_clocking.user_id == User.current.id)
      render_403
      return false
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def check_permissions
    @can_monitor = User.current.admin? || User.current.allowed_to?(:view_work_proof, @project)
    @can_view_self = User.current.allowed_to?(:view_self_work_proof, @project)
    
    render_403 unless @can_monitor || @can_view_self
  end
  
  def authorize_global
    unless User.current.admin? || User.current.allowed_to?(:manage_work_proof, @project)
      render_403
    end
  end
  
  def check_consolidate_permissions
    unless @can_monitor || @can_view_self
      render_403
    end
  end
  
  def time_clocking_params
    params.require(:time_clocking).permit(
      :issue_id,
      :date,
      :description,
      :time_hours,
      :activity_id,
      :status
    )
  end
  
  def time_clockings_to_json(time_clockings)
    {
      time_clockings: time_clockings.map { |tc| time_clocking_hash(tc) },
      total_count: @total_count,
      limit: @limit,
      offset: @offset
    }
  end
  
  def time_clocking_to_json(time_clocking)
    {
      time_clocking: time_clocking_hash(time_clocking)
    }
  end
  
  def time_clocking_hash(time_clocking)
    {
      id: time_clocking.id,
      project_id: time_clocking.project_id,
      project_name: time_clocking.project.name,
      issue_id: time_clocking.issue_id,
      issue_subject: time_clocking.issue.subject,
      user_id: time_clocking.user_id,
      user_name: "#{time_clocking.user.firstname} #{time_clocking.user.lastname}",
      user_login: time_clocking.user.login,
      date: time_clocking.date,
      time_hours: time_clocking.time_hours,
      description: time_clocking.description,
      activity_id: time_clocking.activity_id,
      activity_name: time_clocking.activity_name,
      status: time_clocking.status,
      consolidated: time_clocking.consolidated,
      time_entry_id: time_clocking.time_entry_id,
      created_at: time_clocking.created_at,
      updated_at: time_clocking.updated_at
    }
  end
end

