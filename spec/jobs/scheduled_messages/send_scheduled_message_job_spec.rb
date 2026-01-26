require 'rails_helper'

RSpec.describe ScheduledMessages::SendScheduledMessageJob, type: :job do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  def build_scheduled_message(attrs = {})
    ScheduledMessage.new({
      account: account,
      inbox: inbox,
      conversation: conversation,
      author: author,
      content: 'Hello',
      scheduled_at: Time.current.beginning_of_minute + 30.seconds,
      status: :pending
    }.merge(attrs))
  end

  def create_scheduled_message(attrs = {})
    build_scheduled_message(attrs).tap(&:save!)
  end

  describe '#perform' do
    it 'creates a text message with correct metadata' do
      freeze_time do
        scheduled_message = create_scheduled_message

        expect { described_class.new.perform(scheduled_message.id) }
          .to change { Message.where(conversation_id: conversation.id).count }.by(1)

        message = conversation.messages.last
        expected_scheduled_at = scheduled_message.scheduled_at.as_json

        expect(message.content).to eq('Hello')
        expect(message.additional_attributes['scheduled_message_id']).to eq(scheduled_message.id)
        expect(message.additional_attributes['scheduled_by']).to eq(
          { 'id' => scheduled_message.author_id, 'type' => scheduled_message.author_type }
        )
        expect(message.additional_attributes['scheduled_at']).to eq(expected_scheduled_at)
      end
    end

    it 'creates a whatsapp template message with correct metadata' do
      freeze_time do
        whatsapp_channel = create(
          :channel_whatsapp,
          account: account,
          provider: 'whatsapp_cloud',
          sync_templates: false,
          validate_provider_config: false
        )
        whatsapp_conversation = create(:conversation, account: account, inbox: whatsapp_channel.inbox)
        template_params = { 'name' => 'sample_shipping_confirmation', 'language' => 'id' }
        scheduled_message = ScheduledMessage.create!(
          account: account,
          inbox: whatsapp_channel.inbox,
          conversation: whatsapp_conversation,
          author: author,
          content: nil,
          scheduled_at: Time.current.beginning_of_minute + 10.seconds,
          status: :pending,
          template_params: template_params
        )

        expect { described_class.new.perform(scheduled_message.id) }
          .to change { Message.where(conversation_id: whatsapp_conversation.id).count }.by(1)

        message = whatsapp_conversation.messages.last

        expect(message.additional_attributes['template_params']).to eq(template_params)
        expect(message.additional_attributes['scheduled_message_id']).to eq(scheduled_message.id)
        expect(message.additional_attributes['scheduled_at']).to eq(expected_scheduled_at)
        expect(message.additional_attributes['scheduled_by']).to eq(
          { 'id' => scheduled_message.author_id, 'type' => scheduled_message.author_type }
        )
      end
    end

    it 'creates a message with attachment and correct metadata' do
      freeze_time do
        scheduled_message = build_scheduled_message(content: nil)
        scheduled_message.attachment.attach(
          io: Rails.root.join('spec/assets/avatar.png').open,
          filename: 'avatar.png',
          content_type: 'image/png'
        )
        scheduled_message.save!

        expect { described_class.new.perform(scheduled_message.id) }
          .to change { Message.where(conversation_id: conversation.id).count }.by(1)

        message = conversation.messages.last
        expected_scheduled_at = scheduled_message.scheduled_at.as_json

        expect(message.attachments.count).to eq(1)
        expect(message.additional_attributes['scheduled_message_id']).to eq(scheduled_message.id)
        expect(message.additional_attributes['scheduled_at']).to eq(expected_scheduled_at)
        expect(message.additional_attributes['scheduled_by']).to eq(
          { 'id' => scheduled_message.author_id, 'type' => scheduled_message.author_type }
        )
      end
    end

    it 'marks the scheduled message as failed when message creation raises' do
      freeze_time do
        scheduled_message = create_scheduled_message

        allow(Messages::MessageBuilder).to receive(:new).and_raise(StandardError, 'boom')

        expect { described_class.new.perform(scheduled_message.id) }
          .not_to(change { Message.where(conversation_id: conversation.id).count })

        expect(scheduled_message.reload.status).to eq('failed')
      end
    end
  end
end
