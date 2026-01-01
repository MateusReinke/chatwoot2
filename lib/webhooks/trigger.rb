class Webhooks::Trigger
  SUPPORTED_ERROR_HANDLE_EVENTS = Webhooks::ErrorHandler::SUPPORTED_EVENTS

  def initialize(url, payload, webhook_type)
    @url = url
    @payload = payload
    @webhook_type = webhook_type
  end

  def self.execute(url, payload, webhook_type)
    new(url, payload, webhook_type).execute
  end

  def execute
    perform_request
  rescue RestClient::NotFound => e
    Rails.logger.warn "Webhook returned 404: #{@url}"
    raise CustomExceptions::Webhook::RetriableError.new("Webhook endpoint not found: #{@url}", e)
  rescue StandardError => e
    Webhooks::ErrorHandler.perform(@payload, @webhook_type, e)
    Rails.logger.warn "Exception: Invalid webhook URL #{@url} : #{e.message}"
  end

  private

  def perform_request
    RestClient::Request.execute(
      method: :post,
      url: @url,
      payload: @payload.to_json,
      headers: { content_type: :json, accept: :json },
      timeout: webhook_timeout
    )
  end

  def webhook_timeout
    raw_timeout = GlobalConfig.get_value('WEBHOOK_TIMEOUT')
    timeout = raw_timeout.presence&.to_i

    timeout&.positive? ? timeout : 5
  end
end
