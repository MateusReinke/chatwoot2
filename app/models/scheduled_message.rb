# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  author_type     :string           not null
#  content         :text
#  scheduled_at    :datetime
#  status          :integer          default("draft"), not null
#  template_params :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  author_id       :bigint           not null
#  conversation_id :bigint           not null
#  inbox_id        :bigint           not null
#
# Indexes
#
#  index_scheduled_messages_on_account_id                        (account_id)
#  index_scheduled_messages_on_account_id_and_status             (account_id,status)
#  index_scheduled_messages_on_author_id                         (author_id)
#  index_scheduled_messages_on_author_id_and_status              (author_id,status)
#  index_scheduled_messages_on_conversation_id                   (conversation_id)
#  index_scheduled_messages_on_conversation_id_and_scheduled_at  (conversation_id,scheduled_at)
#  index_scheduled_messages_on_conversation_id_and_status        (conversation_id,status)
#  index_scheduled_messages_on_inbox_id                          (inbox_id)
#  index_scheduled_messages_on_inbox_id_and_status               (inbox_id,status)
#  index_scheduled_messages_on_status_and_scheduled_at           (status,scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class ScheduledMessage < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :inbox
  belongs_to :conversation
  belongs_to :author, polymorphic: true

  has_one_attached :attachment

  enum status: { draft: 0, pending: 1, sent: 2, failed: 3 }

  before_save :normalize_scheduled_at

  validates :scheduled_at, presence: true, unless: -> { status == 'draft' }
  validates :content, presence: true, unless: :content_optional?

  scope :due_for_sending, -> { pending.where('scheduled_at <= ?', Time.current.end_of_minute) }

  def push_event_data
    data = {
      id: id,
      content: content,
      inbox_id: inbox_id,
      conversation_id: conversation.display_id,
      account_id: account_id,
      status: status,
      scheduled_at: scheduled_at&.to_i,
      template_params: template_params,
      author_id: author_id,
      author_type: author_type,
      created_at: created_at.to_i,
      updated_at: updated_at.to_i
    }

    data[:author] = author_event_data if author.present?
    data[:attachment] = attachment_data if attachment.attached?
    data
  end

  def attachment_data
    return unless attachment.attached?

    {
      id: attachment.id,
      scheduled_message_id: id,
      file_type: attachment.content_type,
      account_id: account_id,
      file_url: url_for(attachment),
      blob_id: attachment.blob.signed_id,
      filename: attachment.filename.to_s
    }
  end

  private

  def normalize_scheduled_at
    self.scheduled_at = scheduled_at.beginning_of_minute if scheduled_at.present?
  end

  def content_optional?
    template_params.present? || attachment.attached?
  end

  def author_event_data
    return author.push_event_data if author.is_a?(User)

    data = { id: author_id, type: author_type }
    data[:name] = author.name if author.respond_to?(:name)
    data
  end
end
