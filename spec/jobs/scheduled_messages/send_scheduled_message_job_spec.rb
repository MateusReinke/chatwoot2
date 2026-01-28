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
    it 'creates message with metadata and marks as sent' do
      freeze_time do
        scheduled_message = create_scheduled_message

        described_class.new.perform(scheduled_message.id)

        message = conversation.messages.last
        expect(message.content).to eq('Hello')
        expect(message.additional_attributes['scheduled_message_id']).to eq(scheduled_message.id)
        expect(message.additional_attributes['scheduled_by']).to include('id' => author.id, 'type' => 'User')
        expect(scheduled_message.reload.status).to eq('sent')
      end
    end

    it 'sets automation_rule_id when author is AutomationRule' do
      freeze_time do
        automation_rule = create(:automation_rule, account: account)
        scheduled_message = create_scheduled_message(author: automation_rule)

        described_class.new.perform(scheduled_message.id)

        message = conversation.messages.last
        expect(message.content_attributes['automation_rule_id']).to eq(automation_rule.id)
        expect(message.additional_attributes['scheduled_by']).to include('id' => automation_rule.id, 'type' => 'AutomationRule')
      end
    end

    it 'includes template_params when present' do
      freeze_time do
        template_params = { 'name' => 'sample_template', 'language' => 'en' }
        scheduled_message = create_scheduled_message(content: nil, template_params: template_params)

        described_class.new.perform(scheduled_message.id)

        expect(conversation.messages.last.additional_attributes['template_params']).to eq(template_params)
      end
    end

    it 'includes attachment when present' do
      freeze_time do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'), 'image/png')
        scheduled_message = create_scheduled_message(content: nil, attachment: file)

        described_class.new.perform(scheduled_message.id)

        expect(conversation.messages.last.attachments.count).to eq(1)
      end
    end

    it 'marks as failed on error' do
      scheduled_message = create_scheduled_message
      allow(Messages::MessageBuilder).to receive(:new).and_raise(StandardError, 'boom')

      described_class.new.perform(scheduled_message.id)

      expect(scheduled_message.reload.status).to eq('failed')
    end

    it 'skips when not pending or not due' do
      draft_message = create_scheduled_message(status: :draft)
      future_message = create_scheduled_message(scheduled_at: 2.minutes.from_now)

      expect { described_class.new.perform(draft_message.id) }.not_to(change { conversation.messages.count })
      expect { described_class.new.perform(future_message.id) }.not_to(change { conversation.messages.count })
    end
  end
end
