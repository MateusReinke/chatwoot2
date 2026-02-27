class Api::V1::Accounts::GroupsController < Api::V1::Accounts::BaseController
  def create
    inbox = Current.account.inboxes.find_by(id: params[:inbox_id])
    return render json: { error: 'Access Denied' }, status: :forbidden unless inbox_accessible?(inbox)

    @conversation = Groups::CreateService.new(
      inbox: inbox,
      subject: params[:subject],
      participants: Array(params[:participants])
    ).perform
  rescue Whatsapp::Providers::WhatsappBaileysService::ProviderUnavailableError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def inbox_accessible?(inbox)
    inbox.present? && Current.user.assigned_inboxes.exists?(id: inbox.id)
  end
end
