import types from '../mutation-types';
import GroupMembersAPI from '../../api/groupMembers';

export const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isSyncing: false,
    isUpdating: false,
    isCreating: false,
  },
};

export const getters = {
  getGroupMembers: _state => contactId => {
    return _state.records[contactId] || [];
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  async createGroup({ commit }, params) {
    commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isCreating: true });
    try {
      const { data } = await GroupMembersAPI.createGroup(params);
      return data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isCreating: false });
    }
  },

  async fetch({ commit }, { contactId }) {
    commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await GroupMembersAPI.getGroupMembers(contactId);
      commit(types.SET_GROUP_MEMBERS, { contactId, members: data.payload });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isFetching: false });
    }
  },

  async sync({ commit, dispatch }, { contactId }) {
    commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isSyncing: true });
    try {
      await GroupMembersAPI.syncGroup(contactId);
      await dispatch('fetch', { contactId });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isSyncing: false });
    }
  },

  async addMembers({ commit, dispatch }, { contactId, participants }) {
    commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isUpdating: true });
    try {
      await GroupMembersAPI.addMembers(contactId, participants);
      await dispatch('fetch', { contactId });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isUpdating: false });
    }
  },

  async removeMembers({ commit, dispatch }, { contactId, memberId }) {
    commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isUpdating: true });
    try {
      await GroupMembersAPI.removeMembers(contactId, memberId);
      await dispatch('fetch', { contactId });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isUpdating: false });
    }
  },

  async updateMemberRole({ commit, dispatch }, { contactId, memberId, role }) {
    commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isUpdating: true });
    try {
      await GroupMembersAPI.updateMemberRole(contactId, memberId, role);
      await dispatch('fetch', { contactId });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_GROUP_MEMBERS_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_GROUP_MEMBERS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_GROUP_MEMBERS](_state, { contactId, members }) {
    _state.records = {
      ..._state.records,
      [contactId]: members,
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
