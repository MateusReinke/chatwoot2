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

  private

  def normalize_scheduled_at
    self.scheduled_at = scheduled_at.beginning_of_minute if scheduled_at.present?
  end

  def content_optional?
    template_params.present? || attachment.attached?
  end
end
