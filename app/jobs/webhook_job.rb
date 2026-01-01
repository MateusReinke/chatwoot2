class WebhookJob < ApplicationJob
  queue_as :medium

  retry_on CustomExceptions::Webhook::RetriableError, wait: :polynomially_longer, attempts: 5

  #  There are 3 types of webhooks, account, inbox and agent_bot
  def perform(url, payload, webhook_type = :account_webhook)
    Webhooks::Trigger.execute(url, payload, webhook_type)
  end
end
