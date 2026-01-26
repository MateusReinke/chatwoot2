<script setup>
import { computed, nextTick, onMounted, ref, useTemplateRef, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { fromUnixTime, format, isSameYear } from 'date-fns';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  scheduledMessage: {
    type: Object,
    required: true,
  },
  writtenBy: {
    type: String,
    required: true,
  },
  allowEdit: {
    type: Boolean,
    default: false,
  },
  allowDelete: {
    type: Boolean,
    default: false,
  },
  collapsible: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['edit', 'delete']);
const noteContentRef = useTemplateRef('noteContentRef');
const needsCollapse = ref(false);
const [isExpanded, toggleExpanded] = useToggle();
const { t } = useI18n();
const { formatMessage } = useMessageFormatter();

const statusConfig = {
  draft: {
    label: t('SCHEDULED_MESSAGES.STATUS.DRAFT'),
    class: 'bg-n-slate-9/10 text-n-slate-12',
  },
  pending: {
    label: t('SCHEDULED_MESSAGES.STATUS.PENDING'),
    class: 'bg-n-slate-9/10 text-n-slate-12',
  },
  sent: {
    label: t('SCHEDULED_MESSAGES.STATUS.SENT'),
    class: 'bg-n-teal-9/10 text-n-teal-11',
  },
  failed: {
    label: t('SCHEDULED_MESSAGES.STATUS.FAILED'),
    class: 'bg-n-ruby-9/10 text-n-ruby-11',
  },
};

const author = computed(() => props.scheduledMessage?.author || {});
const avatarSrc = computed(() =>
  author.value?.thumbnail
    ? author.value.thumbnail
    : '/assets/images/chatwoot_bot.png'
);
const status = computed(() => props.scheduledMessage?.status || 'draft');
const statusBadge = computed(
  () => statusConfig[status.value] || statusConfig.draft
);
const scheduledAt = computed(() => props.scheduledMessage?.scheduled_at);
const formattedScheduledTime = computed(() => {
  if (!scheduledAt.value) return '';
  const unixTime = fromUnixTime(scheduledAt.value);
  const now = new Date();
  if (isSameYear(unixTime, now)) {
    return format(unixTime, 'MMM d, HH:mm');
  }
  return format(unixTime, 'MMM d, yyyy, HH:mm');
});
const scheduledAtLabel = computed(() => {
  if (!scheduledAt.value) {
    return t('SCHEDULED_MESSAGES.ITEM.NO_SCHEDULE');
  }
  return t('SCHEDULED_MESSAGES.ITEM.SCHEDULED_FOR', {
    time: formattedScheduledTime.value,
  });
});

const templateName = computed(() => {
  const templateParams = props.scheduledMessage?.template_params || {};
  return templateParams.name || templateParams.id;
});

const attachment = computed(() => props.scheduledMessage?.attachment);
const attachmentName = computed(() => attachment.value?.filename);
const attachmentUrl = computed(() => attachment.value?.file_url);
const shouldShowAttachmentLine = computed(() => {
  return (
    attachmentName.value &&
    (props.scheduledMessage?.content || templateName.value)
  );
});

const previewContent = computed(() => {
  if (props.scheduledMessage?.content) {
    return props.scheduledMessage.content;
  }
  if (templateName.value) {
    return t('SCHEDULED_MESSAGES.ITEM.TEMPLATE_PREVIEW', {
      name: templateName.value,
    });
  }
  if (attachmentName.value) {
    return t('SCHEDULED_MESSAGES.ITEM.ATTACHMENT_PREVIEW', {
      filename: attachmentName.value,
    });
  }
  return t('SCHEDULED_MESSAGES.ITEM.EMPTY_PREVIEW');
});

const formattedContent = computed(() => formatMessage(previewContent.value));

const calculateCollapse = () => {
  if (!props.collapsible) {
    needsCollapse.value = false;
    return;
  }

  nextTick(() => {
    const threshold = 14 * 1.625 * 4; // NOTE: ~84px
    needsCollapse.value = noteContentRef.value?.clientHeight > threshold;
  });
};

const onEdit = () => emit('edit', props.scheduledMessage);
const onDelete = () => emit('delete', props.scheduledMessage);

onMounted(() => {
  calculateCollapse();
});

watch(previewContent, () => {
  calculateCollapse();
});
</script>

<template>
  <div class="flex flex-col gap-2 border-b border-n-strong group/scheduled">
    <div class="flex items-start justify-between gap-2">
      <div class="flex items-center gap-1.5 min-w-0">
        <Avatar
          :name="author?.name || t('CONVERSATION.BOT')"
          :src="avatarSrc"
          :size="16"
          rounded-full
        />
        <div class="min-w-0 flex-1">
          <span
            class="flex flex-wrap items-center gap-x-1 gap-y-0.5 text-sm text-n-slate-11"
          >
            <span class="font-medium text-n-slate-12 shrink-0">
              {{ writtenBy }}
            </span>
            <span class="break-words">{{ scheduledAtLabel }}</span>
          </span>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <span
          class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
          :class="statusBadge.class"
        >
          {{ statusBadge.label }}
        </span>
        <Button
          v-if="allowEdit"
          variant="faded"
          color="slate"
          size="xs"
          icon="i-lucide-pencil"
          class="opacity-0 group-hover/scheduled:opacity-100"
          @click="onEdit"
        />
        <Button
          v-if="allowDelete"
          variant="faded"
          color="ruby"
          size="xs"
          icon="i-lucide-trash"
          class="opacity-0 group-hover/scheduled:opacity-100"
          @click="onDelete"
        />
      </div>
    </div>
    <p
      ref="noteContentRef"
      v-dompurify-html="formattedContent"
      class="mb-0 prose-sm prose-p:text-sm prose-p:leading-relaxed prose-p:mb-1 prose-p:mt-0 prose-ul:mb-1 prose-ul:mt-0 text-n-slate-12"
      :class="{
        'line-clamp-4': collapsible && !isExpanded && needsCollapse,
      }"
    />
    <div
      v-if="shouldShowAttachmentLine"
      class="flex items-center gap-1.5 text-xs text-n-slate-11"
    >
      <Icon icon="i-lucide-paperclip" class="size-3" />
      <a
        v-if="attachmentUrl"
        :href="attachmentUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="truncate"
      >
        {{
          t('SCHEDULED_MESSAGES.ITEM.ATTACHMENT_LABEL', {
            filename: attachmentName,
          })
        }}
      </a>
      <span v-else class="truncate">
        {{
          t('SCHEDULED_MESSAGES.ITEM.ATTACHMENT_LABEL', {
            filename: attachmentName,
          })
        }}
      </span>
    </div>
    <p v-if="collapsible && needsCollapse">
      <Button
        variant="faded"
        color="blue"
        size="xs"
        :icon="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        @click="() => toggleExpanded()"
      >
        <template v-if="isExpanded">
          {{ t('SCHEDULED_MESSAGES.ITEM.COLLAPSE') }}
        </template>
        <template v-else>
          {{ t('SCHEDULED_MESSAGES.ITEM.EXPAND') }}
        </template>
      </Button>
    </p>
  </div>
</template>
