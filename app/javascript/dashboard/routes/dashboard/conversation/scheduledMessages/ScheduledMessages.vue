<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import ScheduledMessageItem from 'next/Contacts/ContactsSidebar/components/ScheduledMessageItem.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ScheduledMessageModal from './ScheduledMessageModal.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: [Number, String],
    default: null,
  },
});

const { t } = useI18n();
const store = useStore();

const currentUser = useMapGetter('getCurrentUser');
const scheduledMessagesGetter = useMapGetter(
  'scheduledMessages/getAllByConversation'
);
const uiFlags = useMapGetter('scheduledMessages/getUIFlags');

const isFetching = computed(() => uiFlags.value.isFetching);
const isDeleting = computed(() => uiFlags.value.isDeleting);

const shouldShowModal = ref(false);
const editingMessage = ref(null);
const showHistory = ref(false);
const visibleCount = ref(10);
const pageSize = 10;

const scheduledMessages = computed(() => {
  if (!props.conversationId) return [];
  return scheduledMessagesGetter.value(props.conversationId) || [];
});

const hasHistory = computed(() =>
  scheduledMessages.value.some(message =>
    ['sent', 'failed'].includes(message.status)
  )
);

const filteredMessages = computed(() => {
  if (showHistory.value) {
    return scheduledMessages.value;
  }
  return scheduledMessages.value.filter(
    message => !['sent', 'failed'].includes(message.status)
  );
});

const visibleMessages = computed(() =>
  filteredMessages.value.slice(0, visibleCount.value)
);

const hasMore = computed(
  () => filteredMessages.value.length > visibleCount.value
);

const resetPagination = () => {
  visibleCount.value = pageSize;
};

const fetchScheduledMessages = conversationId => {
  if (!conversationId) return;
  store.dispatch('scheduledMessages/get', conversationId);
};

const getWrittenBy = scheduledMessage => {
  const currentUserId = currentUser.value?.id;
  const author = scheduledMessage?.author;

  if (!author) return t('CONVERSATION.BOT');
  if (author.id === currentUserId && scheduledMessage.author_type === 'User') {
    return t('CONTACTS_LAYOUT.SIDEBAR.NOTES.YOU');
  }

  return author.name || t('CONVERSATION.BOT');
};

const openCreateModal = () => {
  if (!props.conversationId) return;
  editingMessage.value = null;
  shouldShowModal.value = true;
};

const openEditModal = message => {
  editingMessage.value = message;
  shouldShowModal.value = true;
};

const closeModal = () => {
  shouldShowModal.value = false;
  editingMessage.value = null;
};

const toggleHistory = () => {
  showHistory.value = !showHistory.value;
  resetPagination();
};

const loadMore = () => {
  visibleCount.value += pageSize;
};

const onDelete = async message => {
  if (!props.conversationId || !message?.id || isDeleting.value) return;
  await store.dispatch('scheduledMessages/delete', {
    conversationId: props.conversationId,
    scheduledMessageId: message.id,
  });
};

watch(
  () => props.conversationId,
  newConversationId => {
    resetPagination();
    showHistory.value = false;
    fetchScheduledMessages(newConversationId);
  },
  { immediate: true }
);
</script>

<template>
  <div>
    <div class="flex items-center justify-between gap-2 px-4 pt-3 pb-2">
      <NextButton
        ghost
        xs
        icon="i-lucide-plus"
        :label="t('SCHEDULED_MESSAGES.NEW_BUTTON')"
        :disabled="!conversationId || isFetching"
        @click="openCreateModal"
      />
      <NextButton
        v-if="hasHistory"
        ghost
        xs
        :label="
          showHistory
            ? t('SCHEDULED_MESSAGES.HIDE_HISTORY')
            : t('SCHEDULED_MESSAGES.SHOW_HISTORY')
        "
        @click="toggleHistory"
      />
    </div>

    <div
      v-if="isFetching"
      class="flex items-center justify-center py-8 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div
      v-else-if="visibleMessages.length"
      class="flex flex-col max-h-[300px] overflow-y-auto"
    >
      <ScheduledMessageItem
        v-for="message in visibleMessages"
        :key="message.id"
        class="px-4 py-4 last-of-type:border-b-0"
        :scheduled-message="message"
        :written-by="getWrittenBy(message)"
        :allow-edit="['pending', 'draft'].includes(message.status)"
        :allow-delete="['pending', 'draft'].includes(message.status)"
        collapsible
        @edit="openEditModal"
        @delete="onDelete"
      />
    </div>
    <p v-else class="px-6 py-6 text-sm leading-6 text-center text-n-slate-11">
      {{ t('SCHEDULED_MESSAGES.EMPTY_STATE') }}
    </p>

    <div v-if="hasMore" class="px-4 pb-4">
      <NextButton
        ghost
        xs
        :label="t('SCHEDULED_MESSAGES.SHOW_MORE')"
        @click="loadMore"
      />
    </div>

    <ScheduledMessageModal
      v-model:show="shouldShowModal"
      :conversation-id="conversationId"
      :inbox-id="inboxId"
      :scheduled-message="editingMessage"
      @close="closeModal"
    />
  </div>
</template>
