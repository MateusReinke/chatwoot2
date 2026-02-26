class Api::V1::Profile::InboxSignaturesController < Api::BaseController
  before_action :set_user
  before_action :set_inbox_signature, only: %i[show update destroy]

  def index
    @inbox_signatures = if params[:account_id].present?
                          account_inbox_ids = Account.find(params[:account_id]).inbox_ids
                          @user.inbox_signatures.where(inbox_id: account_inbox_ids)
                        else
                          @user.inbox_signatures
                        end
  end

  def show
    head :not_found and return unless @inbox_signature
  end

  def update
    if @inbox_signature
      @inbox_signature.update!(inbox_signature_params)
    else
      @inbox_signature = @user.inbox_signatures.create!(
        inbox_signature_params.merge(inbox_id: params[:inbox_id])
      )
    end
  end

  def destroy
    @inbox_signature&.destroy!
    head :no_content
  end

  private

  def set_user
    @user = current_user
  end

  def set_inbox_signature
    @inbox_signature = @user.inbox_signatures.find_by(inbox_id: params[:inbox_id])
  end

  def inbox_signature_params
    params.require(:inbox_signature).permit(:message_signature, :signature_position, :signature_separator)
  end
end
