require 'rails_helper'

RSpec.describe ScheduledMessages::TriggerScheduledMessagesJob, type: :job do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  def create_scheduled_message(attrs = {})
    ScheduledMessage.create!({
      account: account,
      inbox: inbox,
      conversation: conversation,
      author: author,
      content: 'Hello',
      scheduled_at: 1.minute.ago,
      status: :pending,
      template_params: {}
    }.merge(attrs))
  end

  describe '#perform' do
    it 'enqueues jobs for due scheduled messages only' do
      freeze_time do
        due_same_minute = create_scheduled_message(
          scheduled_at: Time.current.beginning_of_minute + 50.seconds
        )
        overdue = create_scheduled_message(
          scheduled_at: Time.current.beginning_of_minute - 2.minutes
        )
        future = create_scheduled_message(
          scheduled_at: Time.current.beginning_of_minute + 1.minute
        )
        draft = create_scheduled_message(
          scheduled_at: Time.current.beginning_of_minute - 10.minutes,
          status: :draft
        )

        clear_enqueued_jobs
        described_class.new.perform

        enqueued_ids = enqueued_jobs
                       .select { |job| job[:job] == ScheduledMessages::SendScheduledMessageJob }
                       .map { |job| job[:args].first }

        expect(enqueued_ids).to contain_exactly(due_same_minute.id, overdue.id)
        expect(enqueued_ids).not_to include(future.id)
        expect(enqueued_ids).not_to include(draft.id)
      end
    end
  end
end
