import types from '../mutation-types';
import ScheduledMessagesAPI from '../../api/scheduledMessages';

export const state = {
  records: {},
  meta: {},
  uiFlags: {
    isFetching: false,
    isFetchingMore: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getAllByConversation: _state => conversationId => {
    return _state.records[Number(conversationId)] || [];
  },
  getMetaByConversation: _state => conversationId => {
    return _state.meta[Number(conversationId)] || {};
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  async get({ commit }, { conversationId, page = 1 }) {
    const isFirstPage = page === 1;
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, {
      isFetching: isFirstPage,
      isFetchingMore: !isFirstPage,
    });
    try {
      const normalizedConversationId = Number(conversationId);
      const { data } = await ScheduledMessagesAPI.get(
        normalizedConversationId,
        { page }
      );
      const mutation = isFirstPage
        ? types.SET_SCHEDULED_MESSAGES
        : types.APPEND_SCHEDULED_MESSAGES;
      commit(mutation, {
        conversationId: normalizedConversationId,
        data: data.payload,
        meta: data.meta,
      });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, {
        isFetching: false,
        isFetchingMore: false,
      });
    }
  },

  async create({ commit }, { conversationId, payload }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: true });
    try {
      const normalizedConversationId = Number(conversationId);
      const { data } = await ScheduledMessagesAPI.create(
        normalizedConversationId,
        payload
      );
      commit(types.ADD_SCHEDULED_MESSAGE, {
        conversationId: normalizedConversationId,
        data,
      });
      return data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: false });
    }
  },

  async update({ commit }, { conversationId, scheduledMessageId, payload }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isUpdating: true });
    try {
      const normalizedConversationId = Number(conversationId);
      const { data } = await ScheduledMessagesAPI.update(
        normalizedConversationId,
        scheduledMessageId,
        payload
      );
      commit(types.UPDATE_SCHEDULED_MESSAGE, {
        conversationId: normalizedConversationId,
        data,
      });
      return data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isUpdating: false });
    }
  },

  async delete({ commit }, { conversationId, scheduledMessageId }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: true });
    try {
      const normalizedConversationId = Number(conversationId);
      await ScheduledMessagesAPI.delete(
        normalizedConversationId,
        scheduledMessageId
      );
      commit(types.DELETE_SCHEDULED_MESSAGE, {
        conversationId: normalizedConversationId,
        scheduledMessageId,
      });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: false });
    }
  },

  upsertFromEvent({ commit, state: localState }, scheduledMessage) {
    const conversationId = Number(scheduledMessage.conversation_id);
    const records = localState.records[conversationId] || [];
    const exists = records.some(record => record.id === scheduledMessage.id);

    commit(
      exists ? types.UPDATE_SCHEDULED_MESSAGE : types.ADD_SCHEDULED_MESSAGE,
      { conversationId, data: scheduledMessage }
    );
  },

  removeFromEvent({ commit }, scheduledMessage) {
    commit(types.DELETE_SCHEDULED_MESSAGE, {
      conversationId: Number(scheduledMessage.conversation_id),
      scheduledMessageId: scheduledMessage.id,
    });
  },
};

export const mutations = {
  [types.SET_SCHEDULED_MESSAGES_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  [types.SET_SCHEDULED_MESSAGES]($state, { conversationId, data, meta }) {
    $state.records = {
      ...$state.records,
      [Number(conversationId)]: data,
    };
    $state.meta = {
      ...$state.meta,
      [Number(conversationId)]: meta,
    };
  },

  [types.APPEND_SCHEDULED_MESSAGES]($state, { conversationId, data, meta }) {
    const normalizedConversationId = Number(conversationId);
    const existingRecords = $state.records[normalizedConversationId] || [];
    const existingIds = new Set(existingRecords.map(r => r.id));
    const newRecords = data.filter(r => !existingIds.has(r.id));

    $state.records = {
      ...$state.records,
      [normalizedConversationId]: [...existingRecords, ...newRecords],
    };
    $state.meta = {
      ...$state.meta,
      [normalizedConversationId]: meta,
    };
  },

  [types.ADD_SCHEDULED_MESSAGE]($state, { conversationId, data }) {
    const normalizedConversationId = Number(conversationId);
    const records = $state.records[normalizedConversationId] || [];
    const existingIndex = records.findIndex(record => record.id === data.id);

    if (existingIndex > -1) {
      records[existingIndex] = data;
    } else {
      records.push(data);
    }

    $state.records = {
      ...$state.records,
      [normalizedConversationId]: [...records],
    };
  },

  [types.UPDATE_SCHEDULED_MESSAGE]($state, { conversationId, data }) {
    const normalizedConversationId = Number(conversationId);
    const records = $state.records[normalizedConversationId] || [];
    const existingIndex = records.findIndex(record => record.id === data.id);

    if (existingIndex > -1) {
      records[existingIndex] = data;
    } else {
      records.push(data);
    }

    $state.records = {
      ...$state.records,
      [normalizedConversationId]: [...records],
    };
  },

  [types.DELETE_SCHEDULED_MESSAGE](
    $state,
    { conversationId, scheduledMessageId }
  ) {
    const normalizedConversationId = Number(conversationId);
    const records = $state.records[normalizedConversationId] || [];
    $state.records = {
      ...$state.records,
      [normalizedConversationId]: records.filter(
        record => record.id !== scheduledMessageId
      ),
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
