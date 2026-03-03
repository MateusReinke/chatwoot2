class Api::V1::Accounts::Contacts::GroupMembersController < Api::V1::Accounts::Contacts::BaseController
  def index
    authorize @contact, :show?

    @group_members = GroupMember.active
                                .where(group_contact: @contact)
                                .includes(:contact)
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

    member = group_members.find(params[:member_id])
    action = params[:role] == 'admin' ? 'promote' : 'demote'
    channel.update_group_participants(@contact.identifier, [jid_for_member(member)], action)
    member.update!(role: params[:role])
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @contact, :update?

    member = group_members.find(params[:id])
    channel.update_group_participants(@contact.identifier, [jid_for_member(member)], 'remove')
    member.update!(is_active: false)
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def group_members
    GroupMember.where(group_contact: @contact)
  end

  def channel
    @contact.group_channel
  end

  def format_participants(phone_numbers)
    Array(phone_numbers).map { |phone| "#{phone.to_s.delete('+')}@s.whatsapp.net" }
  end

  def jid_for_member(member)
    "#{member.contact.phone_number.to_s.delete('+')}@s.whatsapp.net"
  end

  def add_group_members(phone_numbers)
    inbox = @contact.contact_inboxes.first&.inbox
    Array(phone_numbers).each do |phone|
      normalized = phone.start_with?('+') ? phone : "+#{phone}"
      contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: normalized.delete('+'),
        inbox: inbox,
        contact_attributes: { name: normalized, phone_number: normalized }
      ).perform
      next if contact_inbox.blank?

      member = GroupMember.find_or_initialize_by(group_contact: @contact, contact: contact_inbox.contact)
      member.update!(role: :member, is_active: true) unless member.persisted? && member.is_active?
    end
  end
end
