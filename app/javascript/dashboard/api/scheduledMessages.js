/* global axios */
import ApiClient from './ApiClient';

export const buildScheduledMessagePayload = ({
  content,
  status,
  scheduledAt,
  private: isPrivate,
  templateParams,
  contentAttributes,
  additionalAttributes,
  attachment,
} = {}) => {
  if (!attachment) {
    return {
      content,
      status,
      scheduled_at: scheduledAt,
      private: isPrivate,
      template_params: templateParams,
      content_attributes: contentAttributes,
      additional_attributes: additionalAttributes,
    };
  }

  const payload = new FormData();
  if (content) payload.append('content', content);
  if (scheduledAt) payload.append('scheduled_at', scheduledAt);
  if (status) payload.append('status', status);
  if (isPrivate !== undefined) payload.append('private', isPrivate);
  payload.append('attachment', attachment);
  if (templateParams) {
    payload.append('template_params', JSON.stringify(templateParams));
  }
  if (contentAttributes) {
    payload.append('content_attributes', JSON.stringify(contentAttributes));
  }
  if (additionalAttributes) {
    payload.append(
      'additional_attributes',
      JSON.stringify(additionalAttributes)
    );
  }

  return payload;
};

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
    this.conversationId = null;
  }

  get url() {
    return `${this.baseUrl()}/conversations/${this.conversationId}/scheduled_messages`;
  }

  get(conversationId, { page = 1, perPage = 5 } = {}) {
    this.conversationId = conversationId;
    return axios.get(this.url, {
      params: { page, per_page: perPage },
    });
  }

  create(conversationId, payload) {
    this.conversationId = conversationId;
    return axios({
      method: 'post',
      url: this.url,
      data: buildScheduledMessagePayload(payload),
    });
  }

  update(conversationId, scheduledMessageId, payload) {
    this.conversationId = conversationId;
    return axios({
      method: 'patch',
      url: `${this.url}/${scheduledMessageId}`,
      data: buildScheduledMessagePayload(payload),
    });
  }

  delete(conversationId, scheduledMessageId) {
    this.conversationId = conversationId;
    return super.delete(scheduledMessageId);
  }
}

export default new ScheduledMessagesAPI();
