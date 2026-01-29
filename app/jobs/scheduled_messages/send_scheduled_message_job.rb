class ScheduledMessages::SendScheduledMessageJob < ApplicationJob
  queue_as :medium

  def perform(scheduled_message_id)
    scheduled_message = ScheduledMessage.find_by(id: scheduled_message_id)
    return unless scheduled_message

    Current.executed_by = scheduled_message.author if scheduled_message.author.is_a?(AutomationRule)
    scheduled_message.with_lock { send_if_ready(scheduled_message) }
  rescue StandardError => e
    Rails.logger.error("Scheduled message #{scheduled_message_id} failed: #{e.class} #{e.message}")
    if scheduled_message&.pending?
      scheduled_message.update!(status: :failed)
      dispatch_scheduled_message_update(scheduled_message)
    end
  ensure
    Current.reset
  end

  private

  def send_if_ready(scheduled_message)
    return unless scheduled_message.pending?
    return unless scheduled_message.due_for_sending?

    message = build_message(scheduled_message)
    attach_scheduled_metadata(message, scheduled_message)
    update_scheduled_message_status(scheduled_message, message)
  end

  def build_message(scheduled_message)
    params = {
      content: scheduled_message.content,
      private: false,
      message_type: 'outgoing'
    }
    params[:template_params] = scheduled_message.template_params if scheduled_message.template_params.present?
    params[:attachments] = [scheduled_message.attachment.blob.signed_id] if scheduled_message.attachment.attached?
    params.merge!(scheduled_message_content_attributes(scheduled_message))

    Messages::MessageBuilder.new(message_author(scheduled_message), scheduled_message.conversation, params).perform
  end

  def message_author(scheduled_message)
    scheduled_message.author.is_a?(User) ? scheduled_message.author : nil
  end

  def scheduled_message_content_attributes(scheduled_message)
    return {} unless scheduled_message.author.is_a?(AutomationRule)

    { content_attributes: { automation_rule_id: scheduled_message.author_id } }
  end

  def attach_scheduled_metadata(message, scheduled_message)
    existing_attributes = message.additional_attributes || {}
    merged_attributes = existing_attributes.dup
    merged_attributes['scheduled_message_id'] = scheduled_message.id
    scheduled_by = {
      'id' => scheduled_message.author_id,
      'type' => scheduled_message.author_type
    }
    scheduled_by['name'] = scheduled_message.author.name if scheduled_message.author.respond_to?(:name)
    merged_attributes['scheduled_by'] = scheduled_by
    merged_attributes['scheduled_at'] = scheduled_message.updated_at.to_i

    message.update!(additional_attributes: merged_attributes) if merged_attributes != existing_attributes
  end

  def update_scheduled_message_status(scheduled_message, message)
    return unless scheduled_message.pending?

    new_status = message.failed? ? :failed : :sent
    return if scheduled_message.status == new_status.to_s

    scheduled_message.update!(status: new_status)
    dispatch_scheduled_message_update(scheduled_message)
  end

  def dispatch_scheduled_message_update(scheduled_message)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::SCHEDULED_MESSAGE_UPDATED,
      Time.zone.now,
      scheduled_message: scheduled_message
    )
  end
end
