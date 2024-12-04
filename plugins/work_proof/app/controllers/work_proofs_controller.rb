class WorkProofsController < ApplicationController
  menu_item :work_proof 
  before_action :find_project, only: [:index]
  before_action :check_permissions, only: [:index]



  def index
    
    if @can_monitor_work_proof
      # Users with `view_work_proof` permission can see all Work Proofs for the project
      @work_proofs = WorkProof.where(project_id: @project.id)
    elsif @can_view_self_work_proof
      # Users with `view_self_work_proof` permission can see only their own entries
      @work_proofs = WorkProof.where(project_id: @project.id, user_id: User.current.id)
    else
      # Shouldn't reach here due to before_action; fallback for safety
      render_403
    end

    # Apply filters if parameters are provided
    if params[:user_id].present? && @can_monitor_work_proof
      @work_proofs = @work_proofs.where(user_id: params[:user_id])
    end

    if params[:date].present?
      @work_proofs = @work_proofs.where(date: params[:date])
    else
      # Default to current date if no date filter is applied
      @work_proofs = @work_proofs.where(date: Date.today)
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def check_permissions
    # Check if the user has monitor permissions
    @can_monitor_work_proof = User.current.admin? || User.current.allowed_to?(:view_work_proof, @project)

    # Check if the user has self-review permissions
    @can_view_self_work_proof = User.current.allowed_to?(:view_self_work_proof, @project)

    # Deny access if the user has neither permission
    render_403 unless @can_monitor_work_proof || @can_view_self_work_proof
  end
end
