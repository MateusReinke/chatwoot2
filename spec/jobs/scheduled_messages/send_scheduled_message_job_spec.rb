require 'rails_helper'

RSpec.describe ScheduledMessages::SendScheduledMessageJob, type: :job do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  def create_scheduled_message(attrs = {})
    ScheduledMessage.create!({
      account: account,
      inbox: inbox,
      conversation: conversation,
      author: author,
      content: 'Hello',
      scheduled_at: Time.current.beginning_of_minute + 30.seconds,
      status: :pending
    }.merge(attrs))
  end

  describe '#perform' do
    it 'creates a message with correct metadata' do
      freeze_time do
        scheduled_message = create_scheduled_message

        expect { described_class.new.perform(scheduled_message.id) }
          .to change { conversation.messages.count }.by(1)

        message = conversation.messages.last

        expect(message.content).to eq('Hello')
        expect(message.additional_attributes['scheduled_message_id']).to eq(scheduled_message.id)
        expect(message.additional_attributes['scheduled_by']).to eq(
          { 'id' => scheduled_message.author_id, 'type' => scheduled_message.author_type }
        )
        expect(message.additional_attributes['scheduled_at']).to eq(scheduled_message.updated_at.to_i)
      end
    end

    it 'marks scheduled message as sent after message creation' do
      freeze_time do
        scheduled_message = create_scheduled_message

        described_class.new.perform(scheduled_message.id)

        expect(scheduled_message.reload.status).to eq('sent')
      end
    end

    it 'creates a message with template_params' do
      freeze_time do
        template_params = { 'name' => 'sample_template', 'language' => 'en' }
        scheduled_message = create_scheduled_message(content: nil, template_params: template_params)

        expect { described_class.new.perform(scheduled_message.id) }
          .to change { conversation.messages.count }.by(1)

        expect(conversation.messages.last.additional_attributes['template_params']).to eq(template_params)
      end
    end

    it 'creates a message with attachment' do
      freeze_time do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'), 'image/png')
        scheduled_message = create_scheduled_message(content: nil, attachment: file)

        expect { described_class.new.perform(scheduled_message.id) }
          .to change { conversation.messages.count }.by(1)

        expect(conversation.messages.last.attachments.count).to eq(1)
      end
    end

    it 'marks as failed when message creation raises' do
      scheduled_message = create_scheduled_message
      allow(Messages::MessageBuilder).to receive(:new).and_raise(StandardError, 'boom')

      described_class.new.perform(scheduled_message.id)

      expect(scheduled_message.reload.status).to eq('failed')
    end

    it 'skips when not pending' do
      scheduled_message = create_scheduled_message(status: :draft)

      expect { described_class.new.perform(scheduled_message.id) }
        .not_to(change { conversation.messages.count })
    end

    it 'skips when scheduled time is in the future' do
      scheduled_message = create_scheduled_message(scheduled_at: 2.minutes.from_now)

      expect { described_class.new.perform(scheduled_message.id) }
        .not_to(change { conversation.messages.count })
    end
  end
end
