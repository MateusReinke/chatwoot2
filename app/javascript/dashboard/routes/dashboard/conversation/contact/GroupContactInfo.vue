<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import ContactsAPI from 'dashboard/api/contacts';
import Avatar from 'next/avatar/Avatar.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

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
const isSyncing = computed(() => uiFlags.value.isSyncing);

// Add member state
const showAddMember = ref(false);
const addMemberInput = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const showSearchDropdown = ref(false);

// Action menu state (per member)
const activeMenuMemberId = ref(null);
const loadingMemberId = ref(null);

const onSync = async () => {
  try {
    await store.dispatch('groupMembers/sync', {
      contactId: props.contact.id,
    });
    useAlert(t('GROUP.INFO.SYNC_SUCCESS'));
  } catch {
    useAlert(t('GROUP.INFO.SYNC_ERROR'));
  }
};

// Add member search
const searchContacts = debounce(
  async query => {
    if (!query || query.length < 2) {
      searchResults.value = [];
      showSearchDropdown.value = false;
      return;
    }
    isSearching.value = true;
    try {
      const { data } = await ContactsAPI.search(query);
      const existingPhones = members.value
        .map(m => m.contact?.phone_number)
        .filter(Boolean);
      searchResults.value = (data.payload || []).filter(
        c => c.phone_number && !existingPhones.includes(c.phone_number)
      );
      showSearchDropdown.value = searchResults.value.length > 0;
    } catch {
      searchResults.value = [];
    } finally {
      isSearching.value = false;
    }
  },
  300,
  false
);

const onAddMemberInput = event => {
  addMemberInput.value = event.target.value;
  searchContacts(addMemberInput.value);
};

const addMember = async contact => {
  showSearchDropdown.value = false;
  addMemberInput.value = '';
  searchResults.value = [];
  try {
    await store.dispatch('groupMembers/addMembers', {
      contactId: props.contact.id,
      participants: [contact.phone_number],
    });
    useAlert(t('GROUP.MEMBERS.ADD_SUCCESS'));
    showAddMember.value = false;
  } catch {
    useAlert(t('GROUP.MEMBERS.ADD_ERROR'));
  }
};

const toggleAddMember = () => {
  showAddMember.value = !showAddMember.value;
  if (!showAddMember.value) {
    addMemberInput.value = '';
    searchResults.value = [];
    showSearchDropdown.value = false;
  }
};

// Member actions
const getMemberMenuItems = member => {
  const items = [];
  if (member.role === 'member') {
    items.push({
      label: t('GROUP.MEMBERS.PROMOTE_BUTTON'),
      action: 'promote',
      value: 'promote',
      icon: 'i-lucide-shield',
    });
  } else {
    items.push({
      label: t('GROUP.MEMBERS.DEMOTE_BUTTON'),
      action: 'demote',
      value: 'demote',
      icon: 'i-lucide-shield-off',
    });
  }
  items.push({
    label: t('GROUP.MEMBERS.REMOVE_BUTTON'),
    action: 'remove',
    value: 'remove',
    icon: 'i-lucide-user-minus',
  });
  return items;
};

const toggleMemberMenu = memberId => {
  activeMenuMemberId.value =
    activeMenuMemberId.value === memberId ? null : memberId;
};

const closeMemberMenu = () => {
  activeMenuMemberId.value = null;
};

const handleMemberAction = async (member, { action }) => {
  activeMenuMemberId.value = null;
  loadingMemberId.value = member.id;
  try {
    if (action === 'remove') {
      await store.dispatch('groupMembers/removeMembers', {
        contactId: props.contact.id,
        memberId: member.id,
      });
      useAlert(t('GROUP.MEMBERS.REMOVE_SUCCESS'));
    } else if (action === 'promote') {
      await store.dispatch('groupMembers/updateMemberRole', {
        contactId: props.contact.id,
        memberId: member.id,
        role: 'admin',
      });
      useAlert(t('GROUP.MEMBERS.PROMOTE_SUCCESS'));
    } else if (action === 'demote') {
      await store.dispatch('groupMembers/updateMemberRole', {
        contactId: props.contact.id,
        memberId: member.id,
        role: 'member',
      });
      useAlert(t('GROUP.MEMBERS.DEMOTE_SUCCESS'));
    }
  } catch {
    const errorKeyMap = {
      remove: 'GROUP.MEMBERS.REMOVE_ERROR',
      promote: 'GROUP.MEMBERS.PROMOTE_ERROR',
      demote: 'GROUP.MEMBERS.DEMOTE_ERROR',
    };
    useAlert(t(errorKeyMap[action]));
  } finally {
    loadingMemberId.value = null;
  }
};

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
        <div class="flex items-center justify-between mb-2">
          <h4 class="text-sm font-semibold text-n-slate-11">
            {{ t('GROUP.INFO.MEMBER_LIST_TITLE') }}
          </h4>
          <div class="flex items-center gap-1">
            <NextButton
              :label="t('GROUP.MEMBERS.ADD_BUTTON')"
              icon="i-lucide-user-plus"
              variant="ghost"
              size="xs"
              @click="toggleAddMember"
            />
            <NextButton
              :label="t('GROUP.INFO.SYNC_BUTTON')"
              icon="i-lucide-refresh-cw"
              variant="ghost"
              size="xs"
              :is-loading="isSyncing"
              :disabled="isSyncing"
              @click="onSync"
            />
          </div>
        </div>

        <!-- Add member search input -->
        <div v-if="showAddMember" class="relative mb-3">
          <input
            :value="addMemberInput"
            type="text"
            class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :placeholder="t('GROUP.CREATE.PARTICIPANTS_PLACEHOLDER')"
            @input="onAddMemberInput"
            @focus="showSearchDropdown = searchResults.length > 0"
          />
          <span
            v-if="isSearching"
            class="absolute i-lucide-loader-2 animate-spin size-4 text-n-slate-10 right-3 top-2.5"
          />
          <ul
            v-if="showSearchDropdown"
            class="absolute z-10 w-full mt-1 overflow-y-auto border rounded-lg shadow-lg bg-n-alpha-3 backdrop-blur-[100px] border-n-weak max-h-48"
          >
            <li
              v-for="result in searchResults"
              :key="result.id"
              class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer text-n-slate-12 hover:bg-n-alpha-2"
              @click="addMember(result)"
            >
              <Avatar
                :src="result.thumbnail"
                :name="result.name"
                :size="24"
                rounded-full
              />
              <span class="truncate">{{ result.name }}</span>
              <span class="text-xs text-n-slate-10">
                {{ result.phone_number }}
              </span>
            </li>
          </ul>
        </div>

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
            class="flex items-center gap-3 py-1 group"
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
            <!-- Loading spinner for this member -->
            <span
              v-if="loadingMemberId === member.id"
              class="i-lucide-loader-2 animate-spin size-4 text-n-slate-10"
            />
            <!-- Action menu toggle -->
            <div
              v-else
              v-on-clickaway="closeMemberMenu"
              class="relative opacity-0 group-hover:opacity-100"
            >
              <NextButton
                icon="i-lucide-ellipsis-vertical"
                color="slate"
                variant="ghost"
                size="xs"
                @click="toggleMemberMenu(member.id)"
              />
              <DropdownMenu
                v-if="activeMenuMemberId === member.id"
                :menu-items="getMemberMenuItems(member)"
                class="ltr:right-0 rtl:left-0 mt-1 w-48 top-full"
                @action="handleMemberAction(member, $event)"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
