module Whatsapp::BaileysHandlers::GroupsActivity
  private

  def process_groups_activity
    activities = processed_params[:data]
    return if activities.blank?

    activities.each do |activity|
      jid = activity[:jid]
      next if jid.blank?

      source_id = jid.split('@').first
      contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id)
      next if contact_inbox.blank?

      conversation = contact_inbox.conversations.where(status: %i[open pending]).order(created_at: :desc).first
      next if conversation.blank?

      conversation.update_columns(last_activity_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
