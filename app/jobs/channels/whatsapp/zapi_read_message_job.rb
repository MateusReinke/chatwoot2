class Channels::Whatsapp::ZapiReadMessageJob < ApplicationJob
  queue_as :default

  def perform(whatsapp_channel, phone, message_source_id)
    response = HTTParty.post(
      "#{api_instance_path_with_token(whatsapp_channel)}/read-message",
      headers: api_headers(whatsapp_channel),
      body: {
        phone: phone,
        messageId: message_source_id
      }.to_json
    )

    Rails.logger.error response.body unless response.success?
  end

  private

  def api_instance_path(whatsapp_channel)
    "#{Whatsapp::Providers::WhatsappZapiService::API_BASE_PATH}/instances/#{whatsapp_channel.provider_config['instance_id']}"
  end

  def api_instance_path_with_token(whatsapp_channel)
    "#{api_instance_path(whatsapp_channel)}/token/#{whatsapp_channel.provider_config['token']}"
  end

  def api_headers(whatsapp_channel)
    { 'Content-Type' => 'application/json', 'Client-Token' => whatsapp_channel.provider_config['client_token'] }
  end
end
