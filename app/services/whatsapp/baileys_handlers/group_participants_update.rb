module Whatsapp::BaileysHandlers::GroupParticipantsUpdate
  include Whatsapp::BaileysHandlers::Helpers
  include Whatsapp::BaileysHandlers::Concerns::GroupContactMessageHandler

  private

  def process_group_participants_update
    data = processed_params[:data]
    group_jid = data[:id]
    author = data[:author]
    action = data[:action]
    participants = data[:participants]

    return if group_jid.blank? || action.blank? || participants.blank?

    with_contact_lock(group_jid) do
      group_contact_inbox = find_or_create_group_contact_inbox(group_jid)
      conversation = find_or_create_conversation(group_contact_inbox)

      contacts = participants.filter_map { |participant| find_or_create_participant_contact(participant) }
      return if contacts.empty?

      contacts.each { |contact| apply_participant_action(action, conversation, contact) }
      create_participant_activity(conversation, action, contacts, author)
    end
  end

  def find_or_create_group_contact_inbox(group_jid)
    source_id = group_jid.split('@').first

    ::ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      contact_attributes: {
        name: source_id,
        identifier: group_jid,
        group_type: :group
      }
    ).perform
  end

  def find_or_create_conversation(group_contact_inbox)
    conversation = group_contact_inbox.conversations.where(status: :open).last
    return conversation if conversation.present?

    ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: group_contact_inbox.contact_id,
      contact_inbox_id: group_contact_inbox.id,
      conversation_type: :group
    )
  end

  def apply_participant_action(action, conversation, contact)
    case action
    when 'add'
      add_group_member(conversation, contact, role: :member)
    when 'remove'
      remove_group_member(conversation, contact)
    when 'promote'
      update_group_member_role(conversation, contact, :admin)
    when 'demote'
      update_group_member_role(conversation, contact, :member)
    end
  end

  def create_participant_activity(conversation, action, contacts, author_jid)
    locale = inbox.account.locale || I18n.default_locale
    action = resolve_effective_action(action, author_jid, contacts)

    content = I18n.with_locale(locale) { build_activity_content(action, contacts, resolve_author_name(author_jid)) }

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    )
  end

  def resolve_effective_action(action, author_jid, contacts)
    return 'join' if action == 'add' && author_jid.blank?
    return 'leave' if action == 'remove' && author_is_participant?(author_jid, contacts)

    action
  end

  def author_is_participant?(author_jid, contacts)
    return false if author_jid.blank?

    author_lid = author_jid.split('@').first
    contacts.any? { |c| c.identifier&.start_with?(author_lid) || c.phone_number&.delete('+') == author_lid }
  end

  def build_activity_content(action, contacts, author_name)
    names = contacts.map { |c| c.name.presence || c.phone_number || c.identifier }

    return I18n.t("conversations.activity.group_participants.#{action}", contact_name: names.first) if action.in?(%w[join leave])

    params = { author_name: author_name }

    if names.one?
      params[:contact_name] = names.first
      I18n.t("conversations.activity.group_participants.#{action}.single", **params)
    else
      params[:contact_names] = names[..-2].join(', ')
      params[:last_contact_name] = names.last
      I18n.t("conversations.activity.group_participants.#{action}.multiple", **params)
    end
  end

  def resolve_author_name(author_jid)
    return author_jid if author_jid.blank?

    lid = author_jid.split('@').first
    contact_inbox = inbox.contact_inboxes.find_by(source_id: lid)
    resolved_contact = contact_inbox&.contact

    resolved_contact&.name.presence || resolved_contact&.phone_number || lid
  end
end
