class Api::V1::Accounts::Contacts::GroupJoinRequestsController < Api::V1::Accounts::Contacts::BaseController
  def index
    authorize @contact, :show?
    requests = channel.group_join_requests(@contact.identifier)
    render json: { payload: requests }
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def handle
    authorize @contact, :update?
    channel.handle_group_join_requests(@contact.identifier, handle_params[:participants], handle_params[:request_action])
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def handle_params
    params.permit(:request_action, participants: [])
  end

  def channel
    @channel ||= @contact.group_channel
  end
end
