class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  include Events::Types

  before_action :scheduled_message, only: [:update, :destroy]
  before_action :ensure_editable, only: [:update, :destroy]

  PER_PAGE = 5

  def index
    authorize build_scheduled_message
    @scheduled_messages = @conversation.scheduled_messages
                                       .order(scheduled_at: :asc)
                                       .page(params[:page])
                                       .per(params[:per_page] || PER_PAGE)
  end

  def create
    @scheduled_message = build_scheduled_message
    authorize @scheduled_message
    return unless ensure_allowed_status

    @scheduled_message.assign_attributes(scheduled_message_params)
    return unless ensure_future_schedule(@scheduled_message)

    @scheduled_message.save!
    dispatch_event(SCHEDULED_MESSAGE_CREATED, scheduled_message: @scheduled_message)
  end

  def update
    return unless ensure_allowed_status

    @scheduled_message.assign_attributes(scheduled_message_params)
    return unless ensure_future_schedule(@scheduled_message)

    @scheduled_message.save!
    dispatch_event(SCHEDULED_MESSAGE_UPDATED, scheduled_message: @scheduled_message)
  end

  def destroy
    scheduled_message = @scheduled_message
    scheduled_message.destroy!
    dispatch_event(SCHEDULED_MESSAGE_DELETED, scheduled_message: scheduled_message)
  end

  private

  def scheduled_message
    @scheduled_message ||= @conversation.scheduled_messages.find(params[:id])
    authorize @scheduled_message
  end

  def build_scheduled_message
    @conversation.scheduled_messages.new(account: Current.account, inbox: @conversation.inbox, author: Current.user)
  end

  def scheduled_message_params
    params.permit(
      :content,
      :scheduled_at,
      :status,
      :attachment,
      template_params: {}
    )
  end

  def ensure_editable
    return if @scheduled_message.draft? || @scheduled_message.pending?

    render_could_not_create_error('Scheduled message can only be modified while draft or pending') and return
  end

  def ensure_allowed_status
    return true if scheduled_message_params[:status].blank?
    return true if %w[draft pending].include?(scheduled_message_params[:status])

    render_could_not_create_error('Scheduled message status must be draft or pending')
    false
  end

  def ensure_future_schedule(scheduled_message)
    return true unless scheduled_message.pending?

    scheduled_at = scheduled_message.scheduled_at&.beginning_of_minute
    if scheduled_at.blank? || scheduled_at <= Time.current.beginning_of_minute
      render_could_not_create_error('Scheduled time must be in the future')
      return false
    end

    true
  end

  def dispatch_event(event_name, data)
    Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, data)
  end
end
