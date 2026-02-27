class Api::V1::Accounts::Contacts::GroupMetadataController < Api::V1::Accounts::Contacts::BaseController
  def update
    authorize @contact, :update?
    update_subject if params[:subject].present?
    update_description if params[:description].present?
    render json: { id: @contact.id, name: @contact.name, additional_attributes: @contact.additional_attributes }
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def update_subject
    channel.update_group_subject(@contact.identifier, params[:subject])
    @contact.update!(name: params[:subject])
  end

  def update_description
    channel.update_group_description(@contact.identifier, params[:description])
    @contact.update!(additional_attributes: @contact.additional_attributes.merge('description' => params[:description]))
  end

  def channel
    @channel ||= group_conversation.inbox.channel
  end

  def group_conversation
    @group_conversation ||= Current.account.conversations
                                   .where(contact_id: @contact.id, group_type: :group, status: %i[open pending])
                                   .first
  end
end
