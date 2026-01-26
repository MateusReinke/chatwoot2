import { actions } from '../../scheduledMessages';
import * as types from '../../../mutation-types';
import ScheduledMessagesAPI from '../../../../api/scheduledMessages';

const commit = vi.fn();

describe('#scheduledMessages actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('#get', () => {
    it('fetches and commits scheduled messages for a conversation', async () => {
      vi.spyOn(ScheduledMessagesAPI, 'get').mockResolvedValue({
        data: [{ id: 1 }],
      });

      await actions.get({ commit }, '12');

      expect(commit).toHaveBeenCalledWith(
        types.default.SET_SCHEDULED_MESSAGES,
        {
          conversationId: 12,
          data: [{ id: 1 }],
        }
      );
    });
  });

  describe('#create', () => {
    it('creates and commits new scheduled message', async () => {
      vi.spyOn(ScheduledMessagesAPI, 'create').mockResolvedValue({
        data: { id: 9 },
      });

      const result = await actions.create(
        { commit },
        { conversationId: '7', payload: { content: 'Hello' } }
      );

      expect(result).toEqual({ id: 9 });
      expect(commit).toHaveBeenCalledWith(types.default.ADD_SCHEDULED_MESSAGE, {
        conversationId: 7,
        data: { id: 9 },
      });
    });
  });

  describe('#update', () => {
    it('updates and commits scheduled message', async () => {
      vi.spyOn(ScheduledMessagesAPI, 'update').mockResolvedValue({
        data: { id: 9, status: 'pending' },
      });

      const result = await actions.update(
        { commit },
        { conversationId: '7', scheduledMessageId: 3, payload: {} }
      );

      expect(result).toEqual({ id: 9, status: 'pending' });
      expect(commit).toHaveBeenCalledWith(
        types.default.UPDATE_SCHEDULED_MESSAGE,
        {
          conversationId: 7,
          data: { id: 9, status: 'pending' },
        }
      );
    });
  });

  describe('#delete', () => {
    it('deletes scheduled message and removes from store', async () => {
      vi.spyOn(ScheduledMessagesAPI, 'delete').mockResolvedValue({});

      await actions.delete(
        { commit },
        { conversationId: '7', scheduledMessageId: 3 }
      );

      expect(commit).toHaveBeenCalledWith(
        types.default.DELETE_SCHEDULED_MESSAGE,
        {
          conversationId: 7,
          scheduledMessageId: 3,
        }
      );
    });
  });

  describe('#upsertFromEvent', () => {
    it('updates existing record or adds new one from websocket event', () => {
      const state = { records: { 5: [{ id: 1 }] } };

      actions.upsertFromEvent(
        { commit, state },
        { id: 1, conversation_id: '5' }
      );
      expect(commit).toHaveBeenCalledWith(
        types.default.UPDATE_SCHEDULED_MESSAGE,
        {
          conversationId: 5,
          data: { id: 1, conversation_id: '5' },
        }
      );

      commit.mockClear();

      actions.upsertFromEvent(
        { commit, state },
        { id: 2, conversation_id: '5' }
      );
      expect(commit).toHaveBeenCalledWith(types.default.ADD_SCHEDULED_MESSAGE, {
        conversationId: 5,
        data: { id: 2, conversation_id: '5' },
      });
    });
  });

  describe('#removeFromEvent', () => {
    it('removes record using event payload', () => {
      actions.removeFromEvent({ commit }, { id: 3, conversation_id: '8' });

      expect(commit).toHaveBeenCalledWith(
        types.default.DELETE_SCHEDULED_MESSAGE,
        {
          conversationId: 8,
          scheduledMessageId: 3,
        }
      );
    });
  });
});
