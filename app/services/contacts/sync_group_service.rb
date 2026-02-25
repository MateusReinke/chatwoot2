class Contacts::SyncGroupService
  pattr_initialize [:contact!]

  def perform
    validate_group_contact!

    synced = sync_conversations
    raise ActionController::BadRequest, I18n.t('contacts.sync_group.no_supported_inbox') unless synced

    contact.reload
    dispatch_group_synced_event
    contact
  end

  private

  def sync_conversations
    synced = false
    contact.conversations.where(status: %i[open pending]).find_each do |conversation|
      synced = true if conversation.sync_group
    end
    synced
  end

  def validate_group_contact!
    raise ActionController::BadRequest, I18n.t('contacts.sync_group.not_a_group') if contact.group_type_individual?
    raise ActionController::BadRequest, I18n.t('contacts.sync_group.no_identifier') if contact.identifier.blank?
  end

  def dispatch_group_synced_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::CONTACT_GROUP_SYNCED,
      Time.zone.now,
      contact: contact
    )
  end
end
