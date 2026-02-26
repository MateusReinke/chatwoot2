require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/contacts/:id/group_members', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:sync_group_service) { instance_double(Contacts::SyncGroupService, perform: nil) }

  before do
    allow(Contacts::SyncGroupService).to receive(:new).and_return(sync_group_service)
  end

  describe 'GET /api/v1/accounts/{account.id}/contacts/:id/group_members' do
    context 'when unauthenticated user' do
      it 'returns unauthorized' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is logged in' do
      it 'returns active group members' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, conversation_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)
        create(:conversation_group_member, conversation: conversation, contact: create(:contact, account: account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq 2
      end

      it 'does not return inactive group members' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, conversation_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)
        create(:conversation_group_member, :inactive, conversation: conversation, contact: create(:contact, account: account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq 1
      end

      it 'does not return group members from another account' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, conversation_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)
        other_account = create(:account)
        other_conversation = create(:conversation, account: other_account, contact: create(:contact, account: other_account),
                                                   conversation_type: :group)
        create(:conversation_group_member, conversation: other_conversation, contact: create(:contact, account: other_account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq 1
      end

      it 'returns expected attributes in the response' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, conversation_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        member = response.parsed_body['payload'].first
        source_member = ConversationGroupMember.find(member['id'])
        expect(member['id']).to eq(source_member.id)
        expect(member['role']).to eq(source_member.role)
        expect(member['is_active']).to eq(source_member.is_active)
        expect(member['conversation_id']).to eq(conversation.id)
        expect(member['contact']['id']).to eq(source_member.contact.id)
      end

      it 'only returns members from open and pending conversations' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        open_conversation = create(:conversation, account: account, contact: contact, conversation_type: :group, status: :open)
        pending_conversation = create(:conversation, account: account, contact: contact, conversation_type: :group, status: :pending)
        resolved_conversation = create(:conversation, account: account, contact: contact, conversation_type: :group, status: :resolved)
        create(:conversation_group_member, conversation: open_conversation, contact: contact)
        create(:conversation_group_member, conversation: pending_conversation, contact: create(:contact, account: account))
        create(:conversation_group_member, conversation: resolved_conversation, contact: create(:contact, account: account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        conversation_ids = response.parsed_body['payload'].map { |m| m['conversation_id'] }.uniq
        expect(conversation_ids).to contain_exactly(open_conversation.id, pending_conversation.id)
      end

      it 'returns bad request when contact is not a group' do
        contact = create(:contact, account: account, group_type: :individual)
        allow(sync_group_service).to receive(:perform).and_raise(
          ActionController::BadRequest, I18n.t('contacts.sync_group.not_a_group')
        )

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns internal server error when provider is unavailable' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        allow(sync_group_service).to receive(:perform).and_raise(
          Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError, 'Provider offline'
        )

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
