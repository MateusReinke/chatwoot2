class Api::V1::Accounts::Contacts::GroupMembersController < Api::V1::Accounts::Contacts::BaseController
  def index
    authorize @contact, :show?

    Contacts::SyncGroupService.new(contact: @contact).perform

    conversations = Current.account.conversations
                           .where(contact_id: @contact.id, group_type: :group, status: %i[open pending])

    @group_members = ConversationGroupMember.active
                                            .where(conversation: conversations)
                                            .includes(:contact)
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render_internal_server_error(e.message)
  end
end
