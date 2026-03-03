class Api::V1::Accounts::Contacts::GroupSettingsController < Api::V1::Accounts::Contacts::BaseController
  def leave
    authorize @contact, :update?
    channel.group_leave(@contact.identifier)
    resolve_group_conversations
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @contact, :update?
    channel.group_setting_update(@contact.identifier, params[:setting])
    update_contact_setting(params[:setting])
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def toggle_join_approval
    authorize @contact, :update?
    channel.group_join_approval_mode(@contact.identifier, params[:mode])
    update_contact_attribute('join_approval_mode', params[:mode] == 'on')
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def channel
    @channel ||= @contact.group_channel
  end

  def resolve_group_conversations
    Current.account.conversations
           .where(contact_id: @contact.id, group_type: :group, status: %i[open pending])
           .find_each { |c| c.update!(status: :resolved) }
  end

  def update_contact_setting(setting)
    case setting
    when 'announcement'
      update_contact_attribute('announce', true)
    when 'not_announcement'
      update_contact_attribute('announce', false)
    when 'locked'
      update_contact_attribute('restrict', true)
    when 'unlocked'
      update_contact_attribute('restrict', false)
    end
  end

  def update_contact_attribute(key, value)
    new_attrs = (@contact.additional_attributes || {}).merge(key => value)
    @contact.update!(additional_attributes: new_attrs)
  end
end
