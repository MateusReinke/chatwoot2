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
  }

  get(conversationId) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages`
    );
  }

  create(conversationId, payload) {
    return axios({
      method: 'post',
      url: `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages`,
      data: buildScheduledMessagePayload(payload),
    });
  }

  update(conversationId, scheduledMessageId, payload) {
    return axios({
      method: 'patch',
      url: `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${scheduledMessageId}`,
      data: buildScheduledMessagePayload(payload),
    });
  }

  delete(conversationId, scheduledMessageId) {
    return axios.delete(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${scheduledMessageId}`
    );
  }
}

export default new ScheduledMessagesAPI();
