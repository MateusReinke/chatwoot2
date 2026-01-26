require 'rails_helper'

RSpec.describe ScheduledMessage, type: :model do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }
  let(:automation_rule) { create(:automation_rule, account: account) }
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
      status: :pending,
      scheduled_at: 1.hour.from_now
    }.merge(attrs))
  end

  def create_scheduled_message(attrs = {})
    build_scheduled_message(attrs).tap(&:save!)
  end

  describe 'validations' do
    context 'with content' do
      it 'requires content when no template params or attachment' do
        message = build_scheduled_message(content: nil, template_params: {})
        expect(message).not_to be_valid
        expect(message.errors[:content]).to be_present
      end

      it 'allows template params without content' do
        message = build_scheduled_message(content: nil, template_params: { id: '123456789', name: 'test_template' })
        expect(message).to be_valid
      end

      it 'allows attachment without content' do
        message = build_scheduled_message(content: nil, template_params: {})
        message.attachment.attach(
          io: Rails.root.join('spec/assets/avatar.png').open,
          filename: 'avatar.png',
          content_type: 'image/png'
        )

        expect(message).to be_valid
      end
    end

    context 'with author' do
      it 'accepts automation rules as author' do
        message = build_scheduled_message(author: automation_rule)
        expect(message).to be_valid
      end
    end
  end

  describe '.due_for_sending' do
    it 'returns only pending messages scheduled up to the current minute' do
      freeze_time

      due_same_minute = create_scheduled_message(
        scheduled_at: Time.current.beginning_of_minute + 50.seconds
      )
      overdue = create_scheduled_message(
        scheduled_at: Time.current.beginning_of_minute - 2.minutes
      )
      create_scheduled_message(
        content: 'Next minute',
        scheduled_at: Time.current.beginning_of_minute + 1.minute
      )
      create_scheduled_message(
        scheduled_at: Time.current.beginning_of_minute - 10.minutes,
        status: :draft
      )
      create_scheduled_message(
        scheduled_at: Time.current.beginning_of_minute - 10.minutes,
        status: :sent
      )
      create_scheduled_message(
        scheduled_at: Time.current.beginning_of_minute - 10.minutes,
        status: :failed
      )

      expect(described_class.due_for_sending).to contain_exactly(due_same_minute, overdue)
    end
  end
end
