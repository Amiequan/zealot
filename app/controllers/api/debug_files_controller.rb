# frozen_string_literal: true

class Api::DebugFilesController < Api::BaseController
  before_action :validate_user_token, only: :create
  before_action :validate_channel_key, only: %i[index create]
  before_action :set_debug_file, only: %i[show destroy]

  # GET /api/debug_files
  def index
    @debug_files = DebugFile.where(app: @channel.app)
                            .page(params.fetch(:page, 1).to_i)
                            .per(params.fetch(:per_page, 10).to_i)
                            .order(id: :desc)

    @debug_files = @debug_files.where(device_type: @channel.device_type)

    render json: @debug_files, each_serializer: Api::DebugFileSerializer
  end

  # GET /api/debug_files/:id
  def show
    render json: @debug_file, serializer: Api::DebugFileSerializer
  end

  # POST /api/debug_files/upload
  def create
    @debug_file = DebugFile.new(debug_file_params)
    @debug_file.app = @channel.app
    @debug_file.device_type = @channel.device_type
    if @debug_file.save!
      DebugFileTeardownJob.perform_now @debug_file
      render json: @debug_file, serializer: Api::DebugFileSerializer, status: 201
    else
      render json: @debug_file.errors
    end
  end

  # PUT /api/debug_files/:id
  def update
    @debug_file.update(debug_file_params)
  end

  # DELETE /api/debug_files/:id
  def destroy
    @debug_file.destroy
    render json: { mesage: 'OK' }
  end

  protected

  def set_debug_file
    @debug_file = DebugFile.find(params[:id])
  end

  def debug_file_params
    params.permit(
      :release_version, :build_version, :file
    )
  end
end
