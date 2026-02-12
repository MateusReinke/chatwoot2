module Whatsapp::BaileysHandlers::MessagesUpsert
  include Whatsapp::BaileysHandlers::Helpers
  include Whatsapp::BaileysHandlers::Concerns::ContactMessageHandler
  include BaileysHelper

  private

  def process_messages_upsert
    messages = processed_params[:data][:messages]
    messages.each do |message|
      @message = nil
      @contact_inbox = nil
      @contact = nil
      @raw_message = message

      next handle_message if incoming?

      # NOTE: Shared lock with Whatsapp::SendOnWhatsappService
      # Avoids race conditions when sending messages.
      with_baileys_channel_lock_on_outgoing_message(inbox.channel.id) { handle_message }
    end
  end

  def handle_message
    @lock_acquired = false

    return if ignore_message?
    return if find_message_by_source_id(raw_message_id)

    return handle_contact_message if %w[lid user].include?(jid_type)
  end
end
