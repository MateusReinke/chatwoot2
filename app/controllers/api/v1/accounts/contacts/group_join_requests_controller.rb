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
    channel.handle_group_join_requests(@contact.identifier, params[:participants], params[:request_action])
    head :ok
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def channel
    @channel ||= group_conversation.inbox.channel
  end

  def group_conversation
    @group_conversation ||= Current.account.conversations
                                   .where(contact_id: @contact.id, group_type: :group, status: %i[open pending])
                                   .first
  end
end
