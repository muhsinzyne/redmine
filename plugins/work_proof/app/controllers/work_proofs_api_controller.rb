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
  # Accepts multipart/form-data with image file upload OR JSON with work_proof nested params
  def create
    # Handle image upload if file is provided
    if params[:image].present?
      image_url = upload_to_gcs(params[:image])
      unless image_url
        render json: { errors: ['Image upload failed'] }, status: :unprocessable_entity
        return
      end
    else
      # If no file, expect image_url parameter (from JSON or flat params)
      image_url = params[:image_url] || params.dig(:work_proof, :image_url)
    end
    
    # Build work_proof - handle both nested (JSON) and flat (multipart) params
    @work_proof = WorkProof.new
    @work_proof.project_id = params[:project_id] || @project.id
    @work_proof.issue_id = params[:issue_id] || params.dig(:work_proof, :issue_id)
    @work_proof.user_id = User.current.id
    @work_proof.image_url = image_url
    @work_proof.date = params[:date] || params.dig(:work_proof, :date) || Date.today
    @work_proof.description = params[:description] || params.dig(:work_proof, :description)
    @work_proof.work_hours = params[:work_hours] || params.dig(:work_proof, :work_hours)
    @work_proof.status = params[:status] || params.dig(:work_proof, :status)
    
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
  
  def upload_to_gcs(image_file)
    begin
      require 'google/cloud/storage'
      require 'mini_magick'
      
      # Initialize GCS client
      gcs_key_path = Rails.root.join('config', 'gcp', 'gcp-key.json')
      
      # Check if GCS is configured
      unless File.exist?(gcs_key_path) && File.size(gcs_key_path) > 0
        Rails.logger.warn "GCS key not found, using local fallback"
        return upload_to_local(image_file)
      end
      
      storage = Google::Cloud::Storage.new(
        project_id: ENV['GCP_PROJECT_ID'] || 'redmine-workproof',
        credentials: gcs_key_path
      )
      
      bucket_name = ENV['GCS_BUCKET'] || 'redmine-workproof-images'
      bucket = storage.bucket(bucket_name)
      
      # Compress image before upload
      compressed_file = compress_image(image_file)
      original_size = File.size(image_file.tempfile)
      compressed_size = File.size(compressed_file)
      compression_ratio = ((1 - compressed_size.to_f / original_size) * 100).round(2)
      
      Rails.logger.info "Image compressed: #{original_size} bytes → #{compressed_size} bytes (#{compression_ratio}% reduction)"
      
      # Generate unique filename
      extension = File.extname(image_file.original_filename)
      filename = "#{Time.now.to_i}_#{User.current.id}_#{SecureRandom.hex(8)}#{extension}"
      
      # Upload compressed file
      file = bucket.create_file(
        compressed_file,
        filename,
        content_type: image_file.content_type || 'image/jpeg'
      )
      
      # Clean up temp file
      File.delete(compressed_file) if File.exist?(compressed_file)
      
      # Return public URL
      # Note: Bucket should have public access configured at bucket level
      # (uniform bucket-level access), not per-file ACL
      file.public_url
      
    rescue => e
      Rails.logger.error "GCS upload failed: #{e.message}"
      # Fallback to local storage
      upload_to_local(image_file)
    end
  end
  
  def compress_image(image_file)
    begin
      require 'mini_magick'
      
      # Check if ImageMagick is installed
      unless MiniMagick.cli_path
        Rails.logger.warn "ImageMagick not installed, uploading original image"
        return image_file.tempfile.path
      end
      
      # Create temp file for compressed image
      temp_file = Tempfile.new(['compressed', File.extname(image_file.original_filename)])
      temp_file.binmode
      
      # Read image with MiniMagick
      image = MiniMagick::Image.open(image_file.tempfile.path)
      
      # Resize if too large (max 1920px width, maintains aspect ratio)
      if image.width > 1920
        image.resize "1920x1920>"
        Rails.logger.info "Image resized from #{image.width}px width"
      end
      
      # Compress based on format
      case image.type.downcase
      when 'jpeg', 'jpg'
        image.quality 85  # High quality but compressed (was 100%)
      when 'png'
        # For PNG photos without transparency, convert to JPEG (better compression)
        unless image.alpha?
          image.format 'jpg'
          image.quality 85
          temp_file = Tempfile.new(['compressed', '.jpg'])
          temp_file.binmode
        else
          # Keep PNG for images with transparency
          image.quality 85
        end
      when 'webp'
        image.quality 85
      end
      
      # Strip metadata (EXIF, etc.) to reduce size
      image.strip
      
      # Write compressed image
      image.write temp_file.path
      temp_file.rewind
      
      temp_file.path
      
    rescue LoadError
      Rails.logger.warn "MiniMagick gem not loaded, uploading original image"
      image_file.tempfile.path
    rescue => e
      Rails.logger.warn "Image compression failed: #{e.message}, using original"
      image_file.tempfile.path
    end
  end
  
  def upload_to_local(image_file)
    # Fallback: save to local public directory
    upload_dir = Rails.root.join('public', 'uploads', 'work_proofs', Date.today.strftime('%Y%m%d'))
    FileUtils.mkdir_p(upload_dir)
    
    extension = File.extname(image_file.original_filename)
    filename = "#{Time.now.to_i}_#{User.current.id}_#{SecureRandom.hex(8)}#{extension}"
    filepath = upload_dir.join(filename)
    
    File.open(filepath, 'wb') do |file|
      file.write(image_file.read)
    end
    
    # Return relative URL
    "/uploads/work_proofs/#{Date.today.strftime('%Y%m%d')}/#{filename}"
  end
  
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

