<script setup>
import { computed, ref, onMounted } from 'vue';

import AutomationActionFileInput from './AutomationFileInput.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import DurationInput from 'dashboard/components-next/input/DurationInput.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

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
  const value = props.modelValue;
  if (Array.isArray(value)) {
    const first = value[0];
    return typeof first === 'object' && first !== null ? first : {};
  }
  return typeof value === 'object' && value !== null ? value : {};
});

const updateParams = updates => {
  const newParams = { ...normalizedParams.value, ...updates };
  emit('update:modelValue', [newParams]);
};

const content = computed({
  get: () => {
    const value = normalizedParams.value.content;
    return typeof value === 'string' ? value : '';
  },
  set: value => updateParams({ content: value }),
});

const delayMinutes = computed({
  get: () => normalizedParams.value.delay_minutes ?? 1440,
  set: value => {
    const numValue = Math.min(Math.max(1, Number(value) || 1), 1438560);
    updateParams({ delay_minutes: numValue });
  },
});

const delayUnit = ref(DURATION_UNITS.MINUTES);

const detectUnit = minutes => {
  const m = Number(minutes) || 0;
  if (m === 0) return DURATION_UNITS.DAYS;
  if (m % (24 * 60) === 0) return DURATION_UNITS.DAYS;
  if (m % 60 === 0) return DURATION_UNITS.HOURS;
  return DURATION_UNITS.MINUTES;
};

onMounted(() => {
  // Always emit the properly formatted params on mount
  // This ensures the data is in the correct array format for validation
  // and sets default delay_minutes if not present
  const currentDelay = normalizedParams.value.delay_minutes;
  const delay = currentDelay ?? 1440;
  updateParams({ delay_minutes: delay });
  delayUnit.value = detectUnit(delay);
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
  <div class="mt-2 flex flex-col gap-1">
    <div class="flex flex-col gap-1">
      <label class="text-xs text-n-slate-11">
        {{ $t('AUTOMATION.ACTION.SCHEDULED_MESSAGE_DELAY_LABEL') }}
      </label>
      <div class="flex items-center gap-2">
        <!-- allow 1 min to 999 days -->
        <DurationInput
          v-model:model-value="delayMinutes"
          v-model:unit="delayUnit"
          :min="1"
          :max="1438560"
        />
      </div>
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
