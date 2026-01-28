<script setup>
import { computed } from 'vue';

import AutomationActionFileInput from './AutomationFileInput.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

const props = defineProps({
  modelValue: {
    type: [Object, Array],
    default: () => ({}),
  },
  initialFileName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const normalizedParams = computed(() => {
  if (Array.isArray(props.modelValue)) {
    return props.modelValue[0] || {};
  }
  return props.modelValue || {};
});

const updateParams = updates => {
  emit('update:modelValue', { ...normalizedParams.value, ...updates });
};

const content = computed({
  get: () => normalizedParams.value.content || '',
  set: value => updateParams({ content: value }),
});

const delayMinutes = computed({
  get: () => normalizedParams.value.delay_minutes ?? '',
  set: value => updateParams({ delay_minutes: value }),
});

const attachmentBlobIds = computed({
  get: () => {
    const blobId = normalizedParams.value.blob_id;
    return blobId ? [blobId] : [];
  },
  set: value => {
    const blobId = Array.isArray(value) ? value[0] : value;
    updateParams({ blob_id: blobId });
  },
});
</script>

<template>
  <div class="mt-2 flex flex-col gap-2">
    <div class="flex flex-col gap-1">
      <label class="text-xs text-n-slate-11">
        {{ $t('AUTOMATION.ACTION.SCHEDULED_MESSAGE_DELAY_LABEL') }}
      </label>
      <input
        v-model="delayMinutes"
        type="number"
        min="0"
        class="answer--text-input"
        :placeholder="
          $t('AUTOMATION.ACTION.SCHEDULED_MESSAGE_DELAY_PLACEHOLDER')
        "
      />
    </div>

    <WootMessageEditor
      v-model="content"
      rows="4"
      enable-variables
      :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
      class="action-message"
    />

    <AutomationActionFileInput
      v-model="attachmentBlobIds"
      :initial-file-name="initialFileName"
    />
  </div>
</template>
