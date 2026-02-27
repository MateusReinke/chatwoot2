<script setup>
import { computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();
const uiFlags = useMapGetter('groupMembers/getUIFlags');
const getGroupMembers = useMapGetter('groupMembers/getGroupMembers');

const members = computed(() => {
  const allMembers = getGroupMembers.value(props.contact.id) || [];
  return allMembers.filter(m => m.is_active);
});

const memberCount = computed(() => members.value.length);

const isFetching = computed(() => uiFlags.value.isFetching);

onMounted(() => {
  if (props.contact.id) {
    store.dispatch('groupMembers/fetch', { contactId: props.contact.id });
  }
});
</script>

<template>
  <div class="relative items-center w-full p-4">
    <div class="flex flex-col w-full gap-2 text-left rtl:text-right">
      <!-- Group header: avatar, name, member count -->
      <div class="flex flex-row items-start gap-3">
        <Avatar
          :src="contact.thumbnail"
          :name="contact.name"
          :size="48"
          rounded-full
        />
        <div class="flex flex-col min-w-0">
          <h3
            class="my-0 text-base font-medium capitalize break-words text-n-slate-12"
          >
            {{ contact.name }}
          </h3>
          <span class="text-sm text-n-slate-11">
            {{ t('GROUP.INFO.MEMBER_COUNT', { count: memberCount }) }}
          </span>
        </div>
      </div>

      <!-- Members section -->
      <div class="mt-3">
        <h4 class="mb-2 text-sm font-semibold text-n-slate-11">
          {{ t('GROUP.INFO.MEMBER_LIST_TITLE') }}
        </h4>

        <!-- Skeleton loading -->
        <div v-if="isFetching" class="flex flex-col gap-3">
          <div v-for="i in 4" :key="i" class="flex items-center gap-3">
            <div class="rounded-full size-8 bg-n-slate-3 animate-pulse" />
            <div class="flex flex-col flex-1 gap-1">
              <div class="w-2/5 h-4 rounded bg-n-slate-3 animate-pulse" />
            </div>
          </div>
        </div>

        <!-- Empty state -->
        <p v-else-if="members.length === 0" class="text-sm text-n-slate-11">
          {{ t('GROUP.INFO.EMPTY_STATE') }}
        </p>

        <!-- Member list -->
        <div v-else class="flex flex-col gap-2">
          <div
            v-for="member in members"
            :key="member.id"
            class="flex items-center gap-3 py-1"
          >
            <Avatar
              :src="member.contact.thumbnail"
              :name="member.contact.name"
              :size="32"
              rounded-full
            />
            <div class="flex items-center flex-1 min-w-0 gap-2">
              <span class="text-sm truncate text-n-slate-12">
                {{ member.contact.name }}
              </span>
              <span
                v-if="member.role === 'admin'"
                class="px-1.5 py-0.5 text-xs font-medium rounded bg-n-amber-3 text-n-amber-11"
              >
                {{ t('GROUP.INFO.ADMIN_BADGE') }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
