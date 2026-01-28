<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import DatePicker from 'vue-datepicker-next';
import FileUpload from 'vue-upload-component';

import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useFileUpload } from 'dashboard/composables/useFileUpload';
import { ALLOWED_FILE_TYPES } from 'shared/constants/messages';

import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AttachmentPreviews from 'dashboard/components-next/NewConversation/components/AttachmentPreviews.vue';
import DropdownContainer from 'next/dropdown-menu/base/DropdownContainer.vue';
import DropdownBody from 'next/dropdown-menu/base/DropdownBody.vue';
import DropdownSection from 'next/dropdown-menu/base/DropdownSection.vue';
import DropdownItem from 'next/dropdown-menu/base/DropdownItem.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: [Number, String],
    default: null,
  },
  scheduledMessage: {
    type: Object,
    default: null,
  },
  initialContent: {
    type: String,
    default: '',
  },
  initialAttachment: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['update:show', 'close']);

const { t } = useI18n();
const store = useStore();

const inboxGetter = useMapGetter('inboxes/getInbox');
const uiFlags = useMapGetter('scheduledMessages/getUIFlags');

const isEditing = computed(() => !!props.scheduledMessage?.id);
const isCreating = computed(() => uiFlags.value.isCreating);
const isUpdating = computed(() => uiFlags.value.isUpdating);
const isSubmitting = computed(() => isCreating.value || isUpdating.value);
const currentInbox = computed(() => inboxGetter.value(props.inboxId));

const messageContent = ref('');
const scheduledDate = ref(null);
const scheduledTime = ref(null);
const attachments = ref([]);
const existingAttachment = ref(null);
const templateParams = ref(null);
const showConfirmClose = ref(false);

// NOTE: Local ref to control modal visibility, prevents auto-close when unsaved changes exist
const localShowModal = ref(false);

const datePickerLang = {
  days: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
  months: [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
  yearFormat: 'YYYY',
  monthFormat: 'MMMM',
};

const resetForm = () => {
  messageContent.value = '';
  scheduledDate.value = null;
  scheduledTime.value = null;
  attachments.value = [];
  existingAttachment.value = null;
  templateParams.value = null;
};

const setFormFromMessage = scheduledMessage => {
  if (!scheduledMessage) {
    resetForm();
    return;
  }

  messageContent.value = scheduledMessage.content || '';
  templateParams.value = scheduledMessage.template_params || null;
  existingAttachment.value = scheduledMessage.attachment || null;
  attachments.value = [];

  if (scheduledMessage.scheduled_at) {
    const dateValue = new Date(scheduledMessage.scheduled_at * 1000);
    dateValue.setSeconds(0, 0);
    scheduledDate.value = dateValue;
    scheduledTime.value = dateValue;
  } else {
    scheduledDate.value = null;
    scheduledTime.value = null;
  }
};

const { onFileUpload } = useFileUpload({
  inbox: currentInbox.value || {},
  attachFile: ({ blob, file }) => {
    if (!file) return;
    const reader = new FileReader();
    reader.readAsDataURL(file.file);
    reader.onloadend = () => {
      attachments.value = [
        {
          resource: blob || file,
          thumb: reader.result,
          blobSignedId: blob?.signed_id,
        },
      ];
    };
  },
});

const scheduledAt = computed(() => {
  if (!scheduledDate.value) return null;

  const date = new Date(scheduledDate.value);
  if (scheduledTime.value) {
    date.setHours(
      scheduledTime.value.getHours(),
      scheduledTime.value.getMinutes(),
      0,
      0
    );
  } else {
    date.setHours(0, 0, 0, 0);
  }

  return date;
});

const hasContent = computed(() => Boolean(messageContent.value?.trim()));
const hasNewAttachment = computed(() => attachments.value.length > 0);
const hasTemplate = computed(
  () => templateParams.value && Object.keys(templateParams.value).length
);
const hasExistingAttachment = computed(() => !!existingAttachment.value);
const showAttachmentUpload = computed(() => !hasNewAttachment.value);

const hasUnsavedChanges = computed(() => {
  return (
    hasContent.value ||
    hasNewAttachment.value ||
    scheduledDate.value ||
    scheduledTime.value
  );
});

const showModal = computed({
  get: () => localShowModal.value,
  set: value => {
    // NOTE: When trying to close the modal, check for unsaved changes first
    if (
      !value &&
      hasUnsavedChanges.value &&
      !isEditing.value &&
      !showConfirmClose.value
    ) {
      showConfirmClose.value = true;
      return;
    }
    localShowModal.value = value;
    if (!value) {
      emit('update:show', false);
    }
  },
});

watch(
  () => props.show,
  newValue => {
    if (newValue) {
      localShowModal.value = true;
    }
  },
  { immediate: true }
);

const disablePastDates = date => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return date < today;
};

const onDateChange = value => {
  scheduledDate.value = value;
};

const onTimeChange = value => {
  scheduledTime.value = value;
};

const onAttachmentsChange = value => {
  attachments.value = value.slice(0, 1);
};

const resolveAttachmentPayload = () => {
  if (!attachments.value.length) return null;
  const attachment = attachments.value[0];
  return (
    attachment.blobSignedId ||
    attachment.resource?.signed_id ||
    attachment.resource?.file ||
    attachment.resource
  );
};

const isFutureSchedule = date => {
  if (!date) return false;
  const scheduled = new Date(date);
  const now = new Date();
  scheduled.setSeconds(0, 0);
  now.setSeconds(0, 0);
  return scheduled > now;
};

const validatePayload = status => {
  const hasPayloadContent =
    hasContent.value ||
    hasTemplate.value ||
    hasExistingAttachment.value ||
    hasNewAttachment.value;

  if (!hasPayloadContent) {
    useAlert(t('SCHEDULED_MESSAGES.ERRORS.CONTENT_REQUIRED'));
    return false;
  }

  if (status === 'pending') {
    if (!scheduledAt.value || !isFutureSchedule(scheduledAt.value)) {
      useAlert(t('SCHEDULED_MESSAGES.ERRORS.SCHEDULE_IN_PAST'));
      return false;
    }
  }

  return true;
};

const buildPayload = status => {
  const payload = {
    content: messageContent.value,
    status,
    scheduledAt: scheduledAt.value ? scheduledAt.value.toISOString() : null,
    private: false,
  };

  if (templateParams.value && Object.keys(templateParams.value).length) {
    payload.templateParams = templateParams.value;
  }

  const attachmentPayload = resolveAttachmentPayload();
  if (attachmentPayload) {
    payload.attachment = attachmentPayload;
  }

  return payload;
};

const closeModal = () => {
  showConfirmClose.value = false;
  localShowModal.value = false;
  emit('update:show', false);
  emit('close');
  resetForm();
};

const submit = async status => {
  if (!validatePayload(status)) return;

  if (isEditing.value) {
    await store.dispatch('scheduledMessages/update', {
      conversationId: props.conversationId,
      scheduledMessageId: props.scheduledMessage.id,
      payload: buildPayload(status),
    });
  } else {
    await store.dispatch('scheduledMessages/create', {
      conversationId: props.conversationId,
      payload: buildPayload(status),
    });
  }

  closeModal();
};

const handleClose = () => {
  if (hasUnsavedChanges.value && !isEditing.value) {
    showConfirmClose.value = true;
    return;
  }
  closeModal();
};

const handleConfirmDiscard = () => {
  showConfirmClose.value = false;
  closeModal();
};

const handleConfirmSaveAsDraft = async () => {
  showConfirmClose.value = false;
  await submit('draft');
};

watch(
  () => props.show,
  isVisible => {
    if (isVisible) {
      if (props.scheduledMessage) {
        setFormFromMessage(props.scheduledMessage);
      } else {
        resetForm();
        if (props.initialContent) {
          messageContent.value = props.initialContent;
        }
        if (props.initialAttachment) {
          attachments.value = [
            {
              resource: props.initialAttachment.resource,
              thumb: props.initialAttachment.thumb,
              blobSignedId: props.initialAttachment.blobSignedId,
            },
          ];
        }
      }
    } else {
      resetForm();
    }
  }
);

watch(
  () => props.scheduledMessage,
  newMessage => {
    if (props.show) {
      setFormFromMessage(newMessage);
    }
  }
);
</script>

<template>
  <woot-modal
    v-model:show="showModal"
    :on-close="handleClose"
    :close-on-backdrop-click="false"
    size="medium"
  >
    <div class="flex w-full flex-col gap-6 px-6 py-6">
      <h3 class="text-lg font-semibold text-n-slate-12">
        {{
          isEditing
            ? t('SCHEDULED_MESSAGES.MODAL.TITLE_EDIT')
            : t('SCHEDULED_MESSAGES.MODAL.TITLE_NEW')
        }}
      </h3>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('SCHEDULED_MESSAGES.MODAL.MESSAGE_LABEL') }}
        </span>
        <WootMessageEditor
          v-model="messageContent"
          class="message-editor min-h-[6rem] !px-3"
          :placeholder="t('SCHEDULED_MESSAGES.MODAL.MESSAGE_PLACEHOLDER')"
          :channel-type="currentInbox?.channel_type"
          :medium="currentInbox?.medium"
        />
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-2 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('SCHEDULED_MESSAGES.MODAL.DATE_LABEL') }}
          </span>
          <div
            class="w-full min-w-0 [&_.mx-datepicker]:w-full [&_.mx-input-wrapper]:w-full [&_.mx-input]:w-full"
          >
            <DatePicker
              :value="scheduledDate"
              type="date"
              :placeholder="t('SCHEDULED_MESSAGES.MODAL.DATE_PLACEHOLDER')"
              :lang="datePickerLang"
              format="MMM D, YYYY"
              value-type="date"
              :disabled-date="disablePastDates"
              clearable
              append-to-body
              popup-class="z-[10000]"
              @change="onDateChange"
            />
          </div>
        </div>

        <div v-if="scheduledDate" class="flex flex-col gap-2 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('SCHEDULED_MESSAGES.MODAL.TIME_LABEL') }}
          </span>
          <div
            class="w-full min-w-0 [&_.mx-datepicker]:w-full [&_.mx-input-wrapper]:w-full [&_.mx-input]:w-full"
          >
            <DatePicker
              :value="scheduledTime"
              type="time"
              :placeholder="t('SCHEDULED_MESSAGES.MODAL.TIME_PLACEHOLDER')"
              :lang="datePickerLang"
              format="h:mm A"
              value-type="date"
              :show-second="false"
              clearable
              confirm
              :confirm-text="t('SCHEDULED_MESSAGES.MODAL.TIME_CONFIRM')"
              append-to-body
              popup-class="z-[10000]"
              @change="onTimeChange"
            />
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('SCHEDULED_MESSAGES.MODAL.ATTACHMENT_LABEL') }}
        </span>
        <div class="flex flex-wrap items-center gap-2">
          <FileUpload
            v-if="showAttachmentUpload"
            :accept="ALLOWED_FILE_TYPES"
            :multiple="false"
            :maximum="1"
            @input-file="onFileUpload"
          >
            <NextButton
              ghost
              xs
              icon="i-lucide-paperclip"
              :label="t('SCHEDULED_MESSAGES.MODAL.ATTACHMENT_ADD')"
            />
          </FileUpload>
          <span
            v-if="existingAttachment && !attachments.length"
            class="text-xs text-n-slate-11"
          >
            {{
              t('SCHEDULED_MESSAGES.MODAL.ATTACHMENT_CURRENT', {
                filename: existingAttachment.filename,
              })
            }}
          </span>
          <AttachmentPreviews
            v-if="attachments.length"
            class="!p-0"
            :attachments="attachments"
            @update:attachments="onAttachmentsChange"
          />
        </div>
      </div>

      <div class="flex items-center justify-end gap-3">
        <NextButton
          faded
          slate
          :label="t('SCHEDULED_MESSAGES.MODAL.CANCEL')"
          :disabled="isSubmitting"
          @click="handleClose"
        />
        <div class="relative flex">
          <NextButton
            solid
            blue
            :label="
              isEditing
                ? t('SCHEDULED_MESSAGES.MODAL.UPDATE')
                : t('SCHEDULED_MESSAGES.MODAL.SCHEDULE')
            "
            :is-loading="isSubmitting"
            :disabled="isSubmitting"
            class="rounded-r-none"
            @click="submit('pending')"
          />
          <DropdownContainer>
            <template #trigger="{ toggle }">
              <NextButton
                solid
                blue
                icon="i-lucide-chevron-down"
                :is-loading="isSubmitting"
                :disabled="isSubmitting"
                class="-ml-px rounded-l-none border-l border-l-white/20"
                @click="toggle"
              />
            </template>
            <template #default>
              <DropdownBody class="bottom-9 right-0 min-w-[160px] z-[10000]">
                <DropdownSection>
                  <DropdownItem
                    icon="i-lucide-file-text"
                    :label="t('SCHEDULED_MESSAGES.MODAL.SAVE_DRAFT')"
                    @click="submit('draft')"
                  />
                </DropdownSection>
              </DropdownBody>
            </template>
          </DropdownContainer>
        </div>
      </div>
    </div>

    <woot-modal
      v-model:show="showConfirmClose"
      :on-close="() => {}"
      :show-close-button="false"
      size="small"
    >
      <div class="flex w-full flex-col gap-4 px-6 py-6">
        <h3 class="text-lg font-semibold text-n-slate-12">
          {{ t('SCHEDULED_MESSAGES.CONFIRM_CLOSE.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('SCHEDULED_MESSAGES.CONFIRM_CLOSE.MESSAGE') }}
        </p>
        <div class="flex items-center justify-end gap-3">
          <NextButton
            ghost
            ruby
            :label="t('SCHEDULED_MESSAGES.CONFIRM_CLOSE.DISCARD')"
            @click="handleConfirmDiscard"
          />
          <NextButton
            solid
            blue
            :label="t('SCHEDULED_MESSAGES.CONFIRM_CLOSE.SAVE_DRAFT')"
            @click="handleConfirmSaveAsDraft"
          />
        </div>
      </div>
    </woot-modal>
  </woot-modal>
</template>
