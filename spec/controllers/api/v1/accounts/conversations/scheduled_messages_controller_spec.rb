require 'rails_helper'

RSpec.describe 'Scheduled Messages API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  def scheduled_messages_url
    api_v1_account_conversation_scheduled_messages_url(account_id: account.id, conversation_id: conversation.display_id)
  end

  def scheduled_message_url(scheduled_message)
    api_v1_account_conversation_scheduled_message_url(
      account_id: account.id,
      conversation_id: conversation.display_id,
      id: scheduled_message.id
    )
  end

  def create_scheduled_message(attrs = {})
    ScheduledMessage.create!({
      account: account,
      inbox: inbox,
      conversation: conversation,
      author: agent,
      content: 'Hello',
      status: :pending,
      scheduled_at: 2.minutes.from_now
    }.merge(attrs))
  end

  it 'returns unauthorized for unauthenticated users' do
    get scheduled_messages_url
    expect(response).to have_http_status(:unauthorized)
  end

  describe 'GET #index' do
    it 'returns paginated scheduled messages ordered by scheduled_at' do
      later = create_scheduled_message(scheduled_at: 5.minutes.from_now)
      earlier = create_scheduled_message(scheduled_at: 2.minutes.from_now)

      get scheduled_messages_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].pluck('id')).to eq([earlier.id, later.id])
      expect(body['meta']).to include('current_page', 'total_pages', 'total_count')
    end
  end

  describe 'POST #create' do
    it 'creates a pending scheduled message with future time' do
      freeze_time do
        scheduled_at = 2.minutes.from_now

        post scheduled_messages_url,
             params: { content: 'Hello', status: 'pending', scheduled_at: scheduled_at.iso8601 },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        scheduled_message = conversation.scheduled_messages.last
        expect(scheduled_message).to have_attributes(status: 'pending', author_id: agent.id)
      end
    end

    it 'creates a draft without scheduled_at' do
      post scheduled_messages_url,
           params: { content: 'Draft message', status: 'draft' },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.scheduled_messages.last).to have_attributes(status: 'draft', scheduled_at: nil)
    end

    it 'rejects pending schedules not in the future' do
      freeze_time do
        post scheduled_messages_url,
             params: { content: 'Hello', status: 'pending', scheduled_at: Time.current.iso8601 },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates a draft to pending with a future schedule' do
      freeze_time do
        scheduled_message = create_scheduled_message(status: :draft, scheduled_at: nil)

        patch scheduled_message_url(scheduled_message),
              params: { status: 'pending', scheduled_at: 2.minutes.from_now.iso8601 },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(scheduled_message.reload.status).to eq('pending')
      end
    end

    it 'rejects updates for sent messages' do
      scheduled_message = create_scheduled_message(status: :sent)

      patch scheduled_message_url(scheduled_message),
            params: { content: 'Updated' },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes pending scheduled messages' do
      scheduled_message = create_scheduled_message(status: :pending)

      delete scheduled_message_url(scheduled_message), headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ScheduledMessage.exists?(scheduled_message.id)).to be(false)
    end

    it 'rejects delete for sent messages' do
      scheduled_message = create_scheduled_message(status: :sent)

      delete scheduled_message_url(scheduled_message), headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
