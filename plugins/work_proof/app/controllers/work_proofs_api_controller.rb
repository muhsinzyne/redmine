class WorkProofsApiController < ApplicationController
  accept_api_auth :index, :show, :create, :update, :destroy
  
  before_action :find_project
  before_action :find_work_proof, only: [:show, :update, :destroy]
  before_action :authorize_global, only: [:create, :update, :destroy]
  before_action :check_permissions
  
  # GET /projects/:project_id/work_proofs.json
  # GET /projects/:project_id/work_proofs.xml
  def index
    @work_proofs = if @can_monitor_work_proof
      # Admins and managers see all work proofs
      WorkProof.where(project_id: @project.id)
    elsif @can_view_self_work_proof
      # Regular users see only their own
      WorkProof.where(project_id: @project.id, user_id: User.current.id)
    else
      WorkProof.none
    end
    
    # Apply filters
    @work_proofs = @work_proofs.where(user_id: params[:user_id]) if params[:user_id].present? && @can_monitor_work_proof
    @work_proofs = @work_proofs.where(issue_id: params[:issue_id]) if params[:issue_id].present?
    @work_proofs = @work_proofs.where(date: params[:date]) if params[:date].present?
    
    # Date range filter
    @work_proofs = @work_proofs.where('date >= ?', params[:start_date]) if params[:start_date].present?
    @work_proofs = @work_proofs.where('date <= ?', params[:end_date]) if params[:end_date].present?
    
    # Pagination
    @limit = params[:limit].to_i > 0 ? params[:limit].to_i : 25
    @offset = params[:offset].to_i >= 0 ? params[:offset].to_i : 0
    
    @total_count = @work_proofs.count
    @work_proofs = @work_proofs.order(date: :desc, created_at: :desc)
                                .limit(@limit)
                                .offset(@offset)
    
    respond_to do |format|
      format.json { render json: work_proofs_to_json(@work_proofs) }
      format.xml { render xml: @work_proofs.to_xml(methods: [:user_name, :issue_subject]) }
    end
  end
  
  # GET /projects/:project_id/work_proofs/:id.json
  def show
    respond_to do |format|
      format.json { render json: work_proof_to_json(@work_proof) }
      format.xml { render xml: @work_proof.to_xml(methods: [:user_name, :issue_subject]) }
    end
  end
  
  # POST /projects/:project_id/work_proofs.json
  def create
    @work_proof = WorkProof.new(work_proof_params)
    @work_proof.project_id = @project.id
    @work_proof.user_id = User.current.id
    
    if @work_proof.save
      respond_to do |format|
        format.json { render json: work_proof_to_json(@work_proof), status: :created }
        format.xml { render xml: @work_proof.to_xml, status: :created }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @work_proof.errors.full_messages }, status: :unprocessable_entity }
        format.xml { render xml: @work_proof.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # PUT /projects/:project_id/work_proofs/:id.json
  def update
    if @work_proof.update(work_proof_params)
      respond_to do |format|
        format.json { render json: work_proof_to_json(@work_proof) }
        format.xml { render xml: @work_proof.to_xml }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @work_proof.errors.full_messages }, status: :unprocessable_entity }
        format.xml { render xml: @work_proof.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # DELETE /projects/:project_id/work_proofs/:id.json
  def destroy
    @work_proof.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.xml { head :no_content }
    end
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_work_proof
    @work_proof = WorkProof.find(params[:id])
    
    # Check if user can access this work proof
    unless @can_monitor_work_proof || (@can_view_self_work_proof && @work_proof.user_id == User.current.id)
      render_403
      return false
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def check_permissions
    @can_monitor_work_proof = User.current.admin? || User.current.allowed_to?(:view_work_proof, @project)
    @can_view_self_work_proof = User.current.allowed_to?(:view_self_work_proof, @project)
    
    render_403 unless @can_monitor_work_proof || @can_view_self_work_proof
  end
  
  def authorize_global
    # For create/update/delete, require appropriate permissions
    unless User.current.admin? || User.current.allowed_to?(:manage_work_proof, @project)
      render_403
    end
  end
  
  def work_proof_params
    params.require(:work_proof).permit(
      :issue_id,
      :date,
      :image_url,
      :description,
      :work_hours,
      :status
    )
  end
  
  def work_proofs_to_json(work_proofs)
    {
      work_proofs: work_proofs.map { |wp| work_proof_hash(wp) },
      total_count: @total_count,
      limit: @limit,
      offset: @offset
    }
  end
  
  def work_proof_to_json(work_proof)
    {
      work_proof: work_proof_hash(work_proof)
    }
  end
  
  def work_proof_hash(work_proof)
    {
      id: work_proof.id,
      project_id: work_proof.project_id,
      project_name: work_proof.project.name,
      issue_id: work_proof.issue_id,
      issue_subject: work_proof.issue.subject,
      user_id: work_proof.user_id,
      user_name: "#{work_proof.user.firstname} #{work_proof.user.lastname}",
      user_login: work_proof.user.login,
      date: work_proof.date,
      image_url: work_proof.image_url,
      description: work_proof.description,
      work_hours: work_proof.work_hours,
      status: work_proof.status,
      created_at: work_proof.created_at,
      updated_at: work_proof.updated_at
    }
  end
end

