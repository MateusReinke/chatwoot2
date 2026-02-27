class Groups::CreateService
  pattr_initialize [:inbox!, :subject!, :participants!]

  def perform
    group_data = channel.create_group(subject, format_participants)
    group_jid = group_data[:id]
    raise Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError, 'Group JID missing from response' if group_jid.blank?

    create_group_conversation(group_jid)
  end

  private

  def channel
    inbox.channel
  end

  def format_participants
    participants.map { |phone| "#{phone.delete('+')}@s.whatsapp.net" }
  end

  def create_group_conversation(group_jid)
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: group_jid,
      inbox: inbox,
      contact_attributes: {
        name: subject,
        identifier: group_jid,
        group_type: :group
      }
    ).perform

    conversation = contact_inbox.conversations.where(status: %i[open pending], group_type: :group).last
    conversation ||= ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      group_type: :group
    )

    add_initial_members(conversation, contact_inbox)
    conversation
  end

  def add_initial_members(conversation, _group_contact_inbox)
    return if participants.blank?

    participants.each do |phone|
      normalized = phone.start_with?('+') ? phone : "+#{phone}"
      contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: normalized.delete('+'),
        inbox: inbox,
        contact_attributes: { name: normalized, phone_number: normalized }
      ).perform
      next if contact_inbox.blank?

      member = ConversationGroupMember.find_or_initialize_by(conversation: conversation, contact: contact_inbox.contact)
      member.update!(role: :member, is_active: true) unless member.persisted? && member.is_active?
    end
  end
end
