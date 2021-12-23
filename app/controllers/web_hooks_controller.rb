# frozen_string_literal: true

class WebHooksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_channel
  before_action :set_web_hook, except: [:create]

  def create
    @web_hook = WebHook.new(web_hook_params)
    @channel.web_hooks << @web_hook

    authorize @web_hook
    return redirect_to_channel_url unless @web_hook.save

    redirect_to_channel_url notice: t('activerecord.success.create', key: t('web_hooks.title'))
  end

  def destroy
    authorize @web_hook
    @web_hook.destroy
    redirect_to_channel_url notice: t('activerecord.success.destroy', key: t('web_hooks.title'))
  end

  def disable
    authorize @web_hook
    @channel.web_hooks.delete @web_hook
    redirect_to_channel_url notice: t('admin.web_hooks.messages.success.disable')
  end

  def enable
    authorize @web_hook
    @web_hook.channels << @channel
    redirect_to channel_url(@channel, anchor: 'enabled'), notice: t('admin.web_hooks.messages.success.enable')
  end

  def test
    authorize @web_hook
    event = params[:event] || 'upload_events'
    AppWebHookJob.perform_later event, @web_hook, @channel
    redirect_to_channel_url notice: t('admin.web_hooks.messages.success.test')
  end

  private

  def set_channel
    @channel = Channel.friendly.find(params[:channel_id])
  end

  def set_web_hook
    @web_hook = WebHook.find(params[:id])
  end

  def web_hook_params
    params.require(:web_hook).permit(
      :channel_id, :url, :body,
      :upload_events, :changelog_events, :download_events
    )
  end

  def redirect_to_channel_url(**options)
    redirect_to friendly_channel_path(@channel), **options
  end
end
