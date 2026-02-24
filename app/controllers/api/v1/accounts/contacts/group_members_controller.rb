class Api::V1::Accounts::Contacts::GroupMembersController < Api::V1::Accounts::Contacts::BaseController
  def index
    authorize @contact, :show?

    conversations = Current.account.conversations
                           .where(contact_id: @contact.id, status: %i[open pending])

    @group_members = ConversationGroupMember.active
                                            .where(conversation: conversations)
                                            .includes(:contact)
  end
end
