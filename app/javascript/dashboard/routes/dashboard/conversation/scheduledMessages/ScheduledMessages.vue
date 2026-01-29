<script setup>
import { computed, ref, watch, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useScroll } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import ScheduledMessageItem from 'next/Contacts/ContactsSidebar/components/ScheduledMessageItem.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ScheduledMessageSkeletonLoader from './ScheduledMessageSkeletonLoader.vue';
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
const metaGetter = useMapGetter('scheduledMessages/getMetaByConversation');
const uiFlags = useMapGetter('scheduledMessages/getUIFlags');

const isFetching = computed(() => uiFlags.value.isFetching);
const isFetchingMore = computed(() => uiFlags.value.isFetchingMore);
const isDeleting = computed(() => uiFlags.value.isDeleting);

const shouldShowModal = ref(false);
const editingMessage = ref(null);
const showHistory = ref(false);
const scrollContainerRef = useTemplateRef('scrollContainerRef');

const { arrivedState } = useScroll(scrollContainerRef, {
  offset: { bottom: 20 },
});

const scheduledMessages = computed(() => {
  if (!props.conversationId) return [];
  return scheduledMessagesGetter.value(props.conversationId) || [];
});

const meta = computed(() => metaGetter.value(props.conversationId) || {});

const hasMore = computed(() => {
  const { current_page: currentPage, total_pages: totalPages } = meta.value;
  return currentPage && totalPages && currentPage < totalPages;
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

const fetchScheduledMessages = (conversationId, page = 1) => {
  if (!conversationId) return;
  store.dispatch('scheduledMessages/get', { conversationId, page });
};

const loadMore = () => {
  if (!hasMore.value || isFetchingMore.value) return;
  const nextPage = (meta.value.current_page || 1) + 1;
  fetchScheduledMessages(props.conversationId, nextPage);
};

const getWrittenBy = scheduledMessage => {
  const currentUserId = currentUser.value?.id;
  const author = scheduledMessage?.author;

  if (!author) return t('CONVERSATION.BOT');

  const authorName = author.name || t('CONVERSATION.BOT');
  if (author.id === currentUserId && scheduledMessage.author_type === 'User') {
    return t('SCHEDULED_MESSAGES.META.AUTHOR_YOU', { name: authorName });
  }

  return authorName;
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
    showHistory.value = false;
    fetchScheduledMessages(newConversationId);
  },
  { immediate: true }
);

watch(
  () => arrivedState.bottom,
  isAtBottom => {
    if (isAtBottom && hasMore.value && !isFetchingMore.value) {
      loadMore();
    }
  }
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

    <ScheduledMessageSkeletonLoader v-if="isFetching" :rows="3" />
    <div
      v-else-if="filteredMessages.length"
      ref="scrollContainerRef"
      class="flex flex-col max-h-[300px] overflow-y-auto"
    >
      <ScheduledMessageItem
        v-for="message in filteredMessages"
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
      <ScheduledMessageSkeletonLoader v-if="isFetchingMore" :rows="1" />
    </div>
    <p v-else class="px-6 py-6 text-sm leading-6 text-center text-n-slate-11">
      {{ t('SCHEDULED_MESSAGES.EMPTY_STATE') }}
    </p>

    <ScheduledMessageModal
      v-model:show="shouldShowModal"
      :conversation-id="conversationId"
      :inbox-id="inboxId"
      :scheduled-message="editingMessage"
      @close="closeModal"
    />
  </div>
</template>
