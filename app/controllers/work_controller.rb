require 'google/cloud/storage'

class WorkController < ApplicationController
  before_action :validate_api_key
  skip_before_action :verify_authenticity_token, only: [:create, :create_time_entry]

  def create
    begin
      # Validate presence of the required file and parameters
      unless params[:image].present?
        return render json: { success: false, message: 'Image is required' }, status: :bad_request
      end

      # Get the current server date
      current_date = Time.now.to_date

      # Ensure `@current_user` is set from the API key validation
      unless @current_user
        return render json: { success: false, message: 'User not authenticated' }, status: :unauthorized
      end

      # Upload the image to the GCP bucket
      image_url = upload_to_gcp(params[:image])

      # Create a new work proof record with derived user_id and current date
      work_proof = WorkProof.new(
        project_id: params[:project_id],
        issue_id: params[:issue_id],
        user_id: @current_user.id, # Retrieved from the validated token
        date: current_date,        # Current server date
        image_url: image_url,
        created_at: Time.now,
        updated_at: Time.now
      )

      if work_proof.save
        render json: { success: true, message: 'Work proof created successfully', data: work_proof }, status: :created
      else
        render json: { success: false, errors: work_proof.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      render json: { success: false, message: "Error: #{e.message}" }, status: :internal_server_error
    end
  end

  def create_time_entry
    begin
      # Ensure the user is authenticated
      unless @current_user
        return render json: { success: false, message: 'User not authenticated' }, status: :unauthorized
      end

      # Validate required parameters
      required_params = [:project_id, :hours, :activity_id]
      missing_params = required_params.select { |param| params[param].blank? }

      unless missing_params.empty?
        return render json: { success: false, message: "Missing parameters: #{missing_params.join(', ')}" }, status: :bad_request
      end

      # Calculate date and time-related fields
      current_date = Date.today
      tyear = current_date.year
      tmonth = current_date.month
      tweek = current_date.cweek # ISO week number

      # Create a new time entry
      time_entry = TimeEntry.new(
        project_id: params[:project_id],
        author_id: @current_user.id, # Author is the authenticated user
        user_id: @current_user.id,  # User is the authenticated user
        issue_id: params[:issue_id], # Optional
        hours: params[:hours],       # Required
        comments: params[:comments], # Optional
        activity_id: params[:activity_id], # Required
        spent_on: current_date,
        tyear: tyear,
        tmonth: tmonth,
        tweek: tweek,
        created_on: Time.now,
        updated_on: Time.now
      )

      if time_entry.save
        render json: { success: true, message: 'Time entry created successfully', data: time_entry }, status: :created
      else
        render json: { success: false, errors: time_entry.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      render json: { success: false, message: "Error: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def upload_to_gcp(image)
    # Define the relative path to your GCP credentials file
    credentials_path = Rails.root.join('config', 'gcp', 'gcp-key.json').to_s

    # Initialize the GCP Storage client with the credentials
    storage = Google::Cloud::Storage.new(
      credentials: credentials_path
    )
    bucket_name = 'goco-storage' # Replace with your GCP bucket name
    bucket = storage.bucket(bucket_name)

    # Specify the sub-path where the file should be stored
    sub_path = "pms-screenshot/" # Directory-like structure in the bucket

    # Generate a unique filename for the image
    filename = "#{SecureRandom.uuid}_#{image.original_filename}"
    file_path = "#{sub_path}#{filename}"

    # Upload the file to the bucket
    file = bucket.create_file(image.tempfile.path, file_path, content_type: image.content_type)

    # Return the public URL of the uploaded file
    file.public_url
  end

  def validate_api_key
    api_key = params[:key]

    Rails.logger.debug "Received API key: #{api_key.inspect}"

    if api_key.present?
      token = Token.find_by(action: 'api', value: api_key)
      @current_user = token&.user # Set the current user for later use

      Rails.logger.debug "Found user: #{@current_user.inspect}"

      if @current_user && @current_user.active?
        Rails.logger.debug "User is active. Proceeding with request."
        # User is authenticated; continue processing
      else
        Rails.logger.debug "Invalid API key or inactive user."
        render plain: 'Invalid API key or user inactive', status: :unauthorized
      end
    else
      Rails.logger.debug "API key missing."
      render plain: 'API key is required', status: :bad_request
    end
  end
end
