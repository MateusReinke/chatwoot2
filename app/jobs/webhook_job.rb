class WebhookJob < ApplicationJob
  queue_as :medium

  SUPPORTED_MESSAGE_EVENTS = Webhooks::Trigger::SUPPORTED_ERROR_HANDLE_EVENTS

  retry_on CustomExceptions::Webhook::RetriableError, wait: :polynomially_longer, attempts: 5
  discard_on CustomExceptions::Webhook::RetriableError do |job, error|
    payload = job.arguments[1]

    next unless SUPPORTED_MESSAGE_EVENTS.include?(payload[:event])

    message_id = payload[:id]
    next if message_id.blank?

    message = Message.find_by(id: message_id)
    next unless message

    Rails.logger.warn "Webhook retries exhausted for message #{message_id}: #{error.message}"
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end

  #  There are 3 types of webhooks, account, inbox and agent_bot
  def perform(url, payload, webhook_type = :account_webhook)
    Webhooks::Trigger.execute(url, payload, webhook_type)
  end
end
