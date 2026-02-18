class Email::SendOnEmailService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Email
  end

  def perform_reply # rubocop:disable Metrics/AbcSize
    return unless message.email_notifiable_message?

    reply_mail = ConversationReplyMailer.with(account: message.account).email_reply(message).deliver_now
    raise "Email delivery returned nil for message #{message.id}" if reply_mail.nil?

    Rails.logger.info("Email message #{message.id} sent with source_id: #{reply_mail.message_id}")
    message.update!(source_id: reply_mail.message_id)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end
end
