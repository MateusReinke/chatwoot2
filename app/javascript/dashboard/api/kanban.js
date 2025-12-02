/* global axios */
import ApiClient from './ApiClient';

class KanbanAPI extends ApiClient {
  constructor() {
    super('kanban', { accountScoped: true });
  }

  // GET /api/v1/accounts/:account_id/kanban
  getLeads(params = {}) {
    return axios.get(this.url, { params });
  }

  // PUT /api/v1/accounts/:account_id/kanban/:id/move
  moveCard(conversationId, newStatus) {
    return axios.put(`${this.url}/${conversationId}/move`, {
      status: newStatus,
    });
  }

  // GET /api/v1/accounts/:account_id/kanban/export
  exportColumn(status) {
    return axios.get(`${this.url}/export`, {
      params: { status },
    });
  }
}

export default new KanbanAPI();
