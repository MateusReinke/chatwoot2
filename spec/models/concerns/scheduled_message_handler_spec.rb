require 'rails_helper'

RSpec.describe ScheduledMessageHandler do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  let(:scheduled_message) do
    ScheduledMessage.create!(
      account: account,
      inbox: inbox,
      conversation: conversation,
      author: author,
      content: 'Test message',
      scheduled_at: 1.minute.ago,
      status: :pending
    )
  end

  let(:message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :outgoing,
      additional_attributes: { 'scheduled_message_id' => scheduled_message.id }
    )
  end

  describe '#update_scheduled_message_status' do
    it 'marks scheduled message as sent when message status changes to delivered' do
      message.update!(status: :delivered)
      expect(scheduled_message.reload.status).to eq('sent')
    end

    it 'marks scheduled message as sent when message status changes to read' do
      message.update!(status: :read)
      expect(scheduled_message.reload.status).to eq('sent')
    end

    it 'marks scheduled message as failed when message status changes to failed' do
      message.update!(status: :failed)
      expect(scheduled_message.reload.status).to eq('failed')
    end

    it 'does not raise an error when message has no scheduled_message_id' do
      message_without_scheduled = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :outgoing
      )

      expect { message_without_scheduled.update!(status: :delivered) }.not_to raise_error
    end
  end
end
