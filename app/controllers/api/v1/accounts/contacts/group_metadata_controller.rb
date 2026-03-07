class Api::V1::Accounts::Contacts::GroupMetadataController < Api::V1::Accounts::Contacts::BaseController
  def update
    authorize @contact, :update?
    update_subject if metadata_params[:subject].present?
    update_description if metadata_params[:description].present?
    render json: { id: @contact.id, name: @contact.name, additional_attributes: @contact.additional_attributes }
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def metadata_params
    params.permit(:subject, :description)
  end

  def update_subject
    channel.update_group_subject(@contact.identifier, metadata_params[:subject])
    @contact.update!(name: metadata_params[:subject])
  end

  def update_description
    channel.update_group_description(@contact.identifier, metadata_params[:description])
    attrs = @contact.additional_attributes.merge('description' => metadata_params[:description])
    @contact.update!(additional_attributes: attrs)
  end

  def channel
    @channel ||= @contact.group_channel
  end
end
