class Api::V1::Accounts::Conversations::AttachmentsController < Api::V1::Accounts::Conversations::BaseController
  before_action :set_message
  before_action :set_attachment

  def update
    @attachment.update!(permitted_params)
    @attachment.message.reload.send_update_event
  end

  private

  def set_message
    @message = @conversation.messages.find(params[:message_id])
  end

  def set_attachment
    @attachment = @message.attachments.find(params[:id])
  end

  def permitted_params
    params.permit(meta: {})
  end
end
