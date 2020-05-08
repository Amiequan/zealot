# frozen_string_literal: true

class Api::Apps::UploadController < Api::BaseController
  before_action :validate_user_token
  before_action :get_channel

  # Upload an App
  #
  # POST /api/apps/upload
  #
  # @param token         [String]   required  user token
  # @param file          [String]   required  file of app
  # @param channel_key   [String]   optional  channel key of app
  # @param name          [String]   optional  name of app
  # @param password      [String]   optional  password to download app
  # @param release_type  [String]   optional  release type(debug, beta, adhoc, release, enterprise etc)
  # @param source        [String]   optional  upload source(api, cli, jenkins, gitlab-ci etc)
  # @param changelog     [String]   optional  changelog
  # @param branch        [String]   optional  git branch
  # @param git_commit    [String]   optional  git commit
  # @param ci_url        [String]   optional  ci url
  # @param allow_duplice [Boolean]  optional  allow duplice upload, default is false (true, false)
  # @return              [String]   json formatted app info
  def create
    create_or_update_release
    perform_app_web_hook_job

    render json: @release,
           serializer: Api::UploadAppSerializer,
           status: :created
  end

  private

  def create_or_update_release
    ActiveRecord::Base.transaction do
      if new_record?
        create_new_build
      else
        update_new_build
      end
    end
  end

  # 创建 App 并创建新版本
  def create_new_build
    create_release with_channel and_scheme and_app
  end

  # 使用现有 App 创建新版本
  def update_new_build
    message = "bundle id `#{app_info.bundle_id}` not matched with `#{@channel.bundle_id}` in channel #{@channel.id}"
    raise TypeError, message unless @channel.bundle_id_matched? app_info.bundle_id

    create_release with_updated_channel
  end

  def new_record?
    @channel.blank?
  end

  def perform_app_web_hook_job
    @channel.perform_web_hook('upload_events')
  end

  ###########################
  # new build methods
  ###########################
  def with_updated_channel
    @channel.update! channel_params
    @channel
  end

  def create_release(channel)
    @release = channel.releases.upload_file(release_params)
    @release.save!
  end

  def with_channel(scheme)
    @channel = scheme.channels.find_or_create_by channel_params do |channel|
      channel.name = app_info.os
      channel.device_type = app_info.os
    end
  end

  def and_scheme(app)
    name = parse_scheme_name || '测试版'
    app.schemes.find_or_create_by name: name
  end

  def and_app
    permitted = params.permit :name
    permitted[:name] ||= app_info.name

    App.find_or_create_by permitted do |app|
      app.users << @user
    end
  end

  def parse_scheme_name
    return unless app_info.os == AppInfo::Platform::IOS

    case app_info.release_type
    when AppInfo::IPA::ExportType::DEBUG
      '开发版'
    when AppInfo::IPA::ExportType::ADHOC
      '测试版'
    when AppInfo::IPA::ExportType::INHOUSE
      '企业版'
    when AppInfo::IPA::ExportType::RELEASE
      '线上版'
    end
  end

  def decode_icon(icon_file)
    Pngdefry.defry icon_file, icon_file
    File.open icon_file
  end

  def release_params
    params.permit(
      :file, :release_type, :source, :branch, :git_commit,
      :ci_url, :changelog, :devices, :custom_fields
    )
  end

  def channel_params
    params.permit(:slug, :password, :git_url)
  end

  def app_info
    @app_info ||= AppInfo.parse(params[:file].path)
  end

  def get_channel
    @channel = Channel.find_by(key: params[:channel_key])
  end
end
