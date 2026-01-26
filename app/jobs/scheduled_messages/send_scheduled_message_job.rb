class ScheduledMessages::SendScheduledMessageJob < ApplicationJob
  queue_as :medium

  def perform(scheduled_message_id)
    scheduled_message = ScheduledMessage.find_by(id: scheduled_message_id)
    return unless scheduled_message

    scheduled_message.with_lock do
      next unless scheduled_message.pending?
      next unless due_for_sending?(scheduled_message)

      message = build_message(scheduled_message)
      attach_scheduled_metadata(message, scheduled_message)
    end
  rescue StandardError => e
    Rails.logger.error("Scheduled message #{scheduled_message_id} failed: #{e.class} #{e.message}")
    scheduled_message.update!(status: :failed) if scheduled_message&.pending?
  end

  private

  def due_for_sending?(scheduled_message)
    scheduled_message.scheduled_at.present? && scheduled_message.scheduled_at <= Time.current.end_of_minute
  end

  def build_message(scheduled_message)
    params = {
      content: scheduled_message.content,
      private: false,
      message_type: 'outgoing'
    }
    params[:template_params] = scheduled_message.template_params if scheduled_message.template_params.present?
    params[:attachments] = [scheduled_message.attachment.blob.signed_id] if scheduled_message.attachment.attached?

    Messages::MessageBuilder.new(message_author(scheduled_message), scheduled_message.conversation, params).perform
  end

  def message_author(scheduled_message)
    scheduled_message.author.is_a?(User) ? scheduled_message.author : nil
  end

  def attach_scheduled_metadata(message, scheduled_message)
    existing_attributes = message.additional_attributes || {}
    merged_attributes = existing_attributes.dup
    merged_attributes['scheduled_message_id'] = scheduled_message.id
    merged_attributes['scheduled_by'] = {
      'id' => scheduled_message.author_id,
      'type' => scheduled_message.author_type
    }
    merged_attributes['scheduled_at'] = scheduled_message.scheduled_at

    message.update!(additional_attributes: merged_attributes) if merged_attributes != existing_attributes
  end
end
