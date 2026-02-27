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
        conversation = create(:conversation, account: account, contact: contact, group_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)
        create(:conversation_group_member, conversation: conversation, contact: create(:contact, account: account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq 2
      end

      it 'does not return inactive group members' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, group_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)
        create(:conversation_group_member, :inactive, conversation: conversation, contact: create(:contact, account: account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq 1
      end

      it 'does not return group members from another account' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, group_type: :group)
        create(:conversation_group_member, conversation: conversation, contact: contact)
        other_account = create(:account)
        other_conversation = create(:conversation, account: other_account, contact: create(:contact, account: other_account),
                                                   group_type: :group)
        create(:conversation_group_member, conversation: other_conversation, contact: create(:contact, account: other_account))

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/group_members",
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq 1
      end

      it 'returns expected attributes in the response' do
        contact = create(:contact, account: account, group_type: :group, identifier: 'group@g.us')
        conversation = create(:conversation, account: account, contact: contact, group_type: :group)
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
        open_conversation = create(:conversation, account: account, contact: contact, group_type: :group, status: :open)
        pending_conversation = create(:conversation, account: account, contact: contact, group_type: :group, status: :pending)
        resolved_conversation = create(:conversation, account: account, contact: contact, group_type: :group, status: :resolved)
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

  describe 'POST /api/v1/accounts/{account.id}/contacts/:id/group_members' do
    let(:whatsapp_channel) do
      create(:channel_whatsapp, provider: 'baileys', validate_provider_config: false, sync_templates: false, account: account)
    end
    let(:inbox) { whatsapp_channel.inbox }
    let(:group_contact) { create(:contact, account: account, group_type: :group, identifier: 'group@g.us') }
    let(:conversation) { create(:conversation, account: account, contact: group_contact, inbox: inbox, group_type: :group) }
    let(:baileys_service) { instance_double(Whatsapp::Providers::WhatsappBaileysService) }

    before do
      conversation
      allow(Whatsapp::Providers::WhatsappBaileysService).to receive(:new).and_return(baileys_service)
      allow(baileys_service).to receive(:update_group_participants).and_return(true)
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is logged in' do
      it 'adds members and returns ok' do
        allow(baileys_service).to receive(:validate_provider_config?).and_return(true)
        allow(ContactInboxWithContactBuilder).to receive(:new).and_call_original

        post "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members",
             params: { participants: ['+5511999990001'] },
             headers: admin.create_new_auth_token

        expect(response).to have_http_status(:ok)
      end

      it 'returns 422 when provider is unavailable' do
        allow(baileys_service).to receive(:update_group_participants)
          .and_raise(Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError, 'Offline')

        post "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members",
             params: { participants: ['+5511999990001'] },
             headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Offline')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/contacts/:id/group_members/:id' do
    let(:whatsapp_channel) do
      create(:channel_whatsapp, provider: 'baileys', validate_provider_config: false, sync_templates: false, account: account)
    end
    let(:inbox) { whatsapp_channel.inbox }
    let(:group_contact) { create(:contact, account: account, group_type: :group, identifier: 'group@g.us') }
    let(:conversation) { create(:conversation, account: account, contact: group_contact, inbox: inbox, group_type: :group) }
    let(:member_contact) { create(:contact, account: account, phone_number: '+5511999990002') }
    let!(:member) { create(:conversation_group_member, conversation: conversation, contact: member_contact) }
    let(:baileys_service) { instance_double(Whatsapp::Providers::WhatsappBaileysService) }

    before do
      allow(Whatsapp::Providers::WhatsappBaileysService).to receive(:new).and_return(baileys_service)
      allow(baileys_service).to receive(:update_group_participants).and_return(true)
    end

    context 'when user is logged in' do
      it 'deactivates the member and returns ok' do
        delete "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members/#{member.id}",
               headers: admin.create_new_auth_token

        expect(response).to have_http_status(:ok)
        expect(member.reload.is_active).to be false
      end

      it 'returns 422 when provider is unavailable' do
        allow(baileys_service).to receive(:update_group_participants)
          .and_raise(Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError, 'Offline')

        delete "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members/#{member.id}",
               headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/contacts/:id/group_members/:member_id' do
    let(:whatsapp_channel) do
      create(:channel_whatsapp, provider: 'baileys', validate_provider_config: false, sync_templates: false, account: account)
    end
    let(:inbox) { whatsapp_channel.inbox }
    let(:group_contact) { create(:contact, account: account, group_type: :group, identifier: 'group@g.us') }
    let(:conversation) { create(:conversation, account: account, contact: group_contact, inbox: inbox, group_type: :group) }
    let(:member_contact) { create(:contact, account: account, phone_number: '+5511999990003') }
    let!(:member) { create(:conversation_group_member, conversation: conversation, contact: member_contact, role: :member) }
    let(:baileys_service) { instance_double(Whatsapp::Providers::WhatsappBaileysService) }

    before do
      allow(Whatsapp::Providers::WhatsappBaileysService).to receive(:new).and_return(baileys_service)
      allow(baileys_service).to receive(:update_group_participants).and_return(true)
    end

    context 'when user is logged in' do
      it 'promotes member to admin' do
        patch "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members/#{member.id}",
              params: { role: 'admin' },
              headers: admin.create_new_auth_token

        expect(response).to have_http_status(:ok)
        expect(member.reload.role).to eq('admin')
      end

      it 'demotes admin to member' do
        member.update!(role: :admin)
        patch "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members/#{member.id}",
              params: { role: 'member' },
              headers: admin.create_new_auth_token

        expect(response).to have_http_status(:ok)
        expect(member.reload.role).to eq('member')
      end

      it 'returns 422 when provider is unavailable' do
        allow(baileys_service).to receive(:update_group_participants)
          .and_raise(Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError, 'Offline')

        patch "/api/v1/accounts/#{account.id}/contacts/#{group_contact.id}/group_members/#{member.id}",
              params: { role: 'admin' },
              headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
