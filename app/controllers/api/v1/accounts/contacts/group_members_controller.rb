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

  def create
    authorize @contact, :update?

    channel.update_group_participants(@contact.identifier, format_participants(params[:participants]), 'add')
    add_group_members(params[:participants])
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @contact, :update?

    member = group_conversation_members.find(params[:member_id])
    action = params[:role] == 'admin' ? 'promote' : 'demote'
    channel.update_group_participants(@contact.identifier, [jid_for_member(member)], action)
    member.update!(role: params[:role])
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @contact, :update?

    member = group_conversation_members.find(params[:id])
    channel.update_group_participants(@contact.identifier, [jid_for_member(member)], 'remove')
    member.update!(is_active: false)
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def group_conversation
    @group_conversation ||= Current.account.conversations
                                   .where(contact_id: @contact.id, group_type: :group, status: %i[open pending])
                                   .first
  end

  def group_conversation_members
    ConversationGroupMember.where(conversation: group_conversation)
  end

  def channel
    group_conversation.inbox.channel
  end

  def format_participants(phone_numbers)
    Array(phone_numbers).map { |phone| "#{phone.to_s.delete('+')}@s.whatsapp.net" }
  end

  def jid_for_member(member)
    "#{member.contact.phone_number.to_s.delete('+')}@s.whatsapp.net"
  end

  def add_group_members(phone_numbers)
    inbox = group_conversation.inbox
    Array(phone_numbers).each do |phone|
      normalized = phone.start_with?('+') ? phone : "+#{phone}"
      contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: normalized.delete('+'),
        inbox: inbox,
        contact_attributes: { name: normalized, phone_number: normalized }
      ).perform
      next if contact_inbox.blank?

      member = ConversationGroupMember.find_or_initialize_by(conversation: group_conversation, contact: contact_inbox.contact)
      member.update!(role: :member, is_active: true) unless member.persisted? && member.is_active?
    end
  end
end
