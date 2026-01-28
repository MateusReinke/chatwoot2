import * as types from '../../../mutation-types';
import { mutations } from '../../scheduledMessages';

describe('#scheduledMessages mutations', () => {
  describe('SET_SCHEDULED_MESSAGES', () => {
    it('sets records and meta for a conversation', () => {
      const state = { records: {}, meta: {} };
      const meta = { current_page: 1, total_pages: 2, total_count: 10 };

      mutations[types.default.SET_SCHEDULED_MESSAGES](state, {
        conversationId: '4',
        data: [{ id: 10 }],
        meta,
      });

      expect(state.records).toEqual({ 4: [{ id: 10 }] });
      expect(state.meta).toEqual({ 4: meta });
    });
  });

  describe('APPEND_SCHEDULED_MESSAGES', () => {
    it('appends records without duplicates and updates meta', () => {
      const state = {
        records: { 4: [{ id: 1 }] },
        meta: { 4: { current_page: 1, total_pages: 2 } },
      };
      const newMeta = { current_page: 2, total_pages: 2, total_count: 10 };

      mutations[types.default.APPEND_SCHEDULED_MESSAGES](state, {
        conversationId: 4,
        data: [{ id: 1 }, { id: 2 }],
        meta: newMeta,
      });

      expect(state.records[4]).toEqual([{ id: 1 }, { id: 2 }]);
      expect(state.meta[4]).toEqual(newMeta);
    });
  });

  describe('ADD_SCHEDULED_MESSAGE', () => {
    it('adds new record or updates existing one', () => {
      const state = { records: { 2: [{ id: 1, status: 'draft' }] }, meta: {} };

      mutations[types.default.ADD_SCHEDULED_MESSAGE](state, {
        conversationId: 2,
        data: { id: 1, status: 'pending' },
      });

      expect(state.records[2]).toEqual([{ id: 1, status: 'pending' }]);
    });
  });

  describe('DELETE_SCHEDULED_MESSAGE', () => {
    it('removes record by id', () => {
      const state = { records: { 3: [{ id: 1 }, { id: 2 }] }, meta: {} };

      mutations[types.default.DELETE_SCHEDULED_MESSAGE](state, {
        conversationId: 3,
        scheduledMessageId: 1,
      });

      expect(state.records[3]).toEqual([{ id: 2 }]);
    });
  });
});
