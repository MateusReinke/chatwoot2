<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import ContactsAPI from 'dashboard/api/contacts';
import GroupMembersAPI from 'dashboard/api/groupMembers';
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
const route = useRoute();
const { t } = useI18n();

// Inbox admin check: determine if the inbox's phone number is an admin in this group
const currentChat = useMapGetter('getSelectedChat');
const inboxGetter = useMapGetter('inboxes/getInboxById');
const inbox = computed(
  () => inboxGetter.value(currentChat.value?.inbox_id) || {}
);
const inboxPhone = computed(() => inbox.value?.phone_number);

const contactProfileLink = computed(
  () => `/app/accounts/${route.params.accountId}/contacts/${props.contact.id}`
);
const uiFlags = useMapGetter('groupMembers/getUIFlags');
const getGroupMembers = useMapGetter('groupMembers/getGroupMembers');
const getGroupMembersMeta = useMapGetter('groupMembers/getGroupMembersMeta');

const members = computed(() => {
  const allMembers = getGroupMembers.value(props.contact.id) || [];
  return allMembers.filter(m => m.is_active);
});

const membersMeta = computed(
  () => getGroupMembersMeta.value(props.contact.id) || {}
);
const memberCount = computed(
  () => membersMeta.value.total_count ?? members.value.length
);
const hasMoreMembers = computed(() => {
  const meta = membersMeta.value;
  if (!meta.total_count || !meta.page || !meta.per_page) return false;
  return meta.page * meta.per_page < meta.total_count;
});

// Compare phone numbers flexibly to handle format differences
// (e.g. Brazilian 9th digit: +5587988465072 vs +558788465072)
const phonesMatch = (phoneA, phoneB) => {
  const a = phoneA?.replace(/\D/g, '');
  const b = phoneB?.replace(/\D/g, '');
  if (!a || !b) return false;
  if (a === b) return true;
  return a.length >= 8 && b.length >= 8 && a.slice(-8) === b.slice(-8);
};

const isInboxAdmin = computed(() => {
  if (!inboxPhone.value) return false;
  return members.value.some(
    m =>
      phonesMatch(inboxPhone.value, m.contact?.phone_number) &&
      m.role === 'admin'
  );
});

const isOwnMember = member => {
  if (!inboxPhone.value) return false;
  return phonesMatch(inboxPhone.value, member.contact?.phone_number);
};

const isFetching = computed(() => uiFlags.value.isFetching);
const isFetchingMore = computed(() => uiFlags.value.isFetchingMore);
const isSyncing = computed(() => uiFlags.value.isSyncing);
const memberListRef = ref(null);

const loadMoreMembers = async () => {
  if (isFetchingMore.value || !hasMoreMembers.value) return;
  const nextPage = (membersMeta.value.page || 1) + 1;
  await store.dispatch('groupMembers/fetch', {
    contactId: props.contact.id,
    page: nextPage,
  });
};

const onMemberListScroll = event => {
  const el = event.target;
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 40) {
    loadMoreMembers();
  }
};

// Inline edit state
const isEditingName = ref(false);
const editNameValue = ref('');
const isSavingName = ref(false);
const isEditingDescription = ref(false);
const editDescriptionValue = ref('');
const isSavingDescription = ref(false);
const isSavingAvatar = ref(false);
const avatarFileInput = ref(null);

const contactDescription = computed(
  () => props.contact.additional_attributes?.description || ''
);

const startEditName = () => {
  editNameValue.value = props.contact.name || '';
  isEditingName.value = true;
};

const saveName = async () => {
  const newName = editNameValue.value.trim();
  if (!newName || newName === props.contact.name) {
    isEditingName.value = false;
    return;
  }
  isSavingName.value = true;
  try {
    await store.dispatch('groupMembers/updateGroupMetadata', {
      contactId: props.contact.id,
      params: { subject: newName },
    });
    useAlert(t('GROUP.METADATA.SAVE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.METADATA.SAVE_ERROR'));
  } finally {
    isSavingName.value = false;
    isEditingName.value = false;
  }
};

const onNameKeydown = event => {
  if (event.key === 'Enter') saveName();
  if (event.key === 'Escape') {
    isEditingName.value = false;
  }
};

const startEditDescription = () => {
  editDescriptionValue.value = contactDescription.value;
  isEditingDescription.value = true;
};

const saveDescription = async () => {
  const newDesc = editDescriptionValue.value.trim();
  if (newDesc === contactDescription.value) {
    isEditingDescription.value = false;
    return;
  }
  isSavingDescription.value = true;
  try {
    await store.dispatch('groupMembers/updateGroupMetadata', {
      contactId: props.contact.id,
      params: { description: newDesc },
    });
    useAlert(t('GROUP.METADATA.SAVE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.METADATA.SAVE_ERROR'));
  } finally {
    isSavingDescription.value = false;
    isEditingDescription.value = false;
  }
};

const onAvatarClick = () => {
  avatarFileInput.value?.click();
};

const onAvatarSelected = async event => {
  const file = event.target.files[0];
  if (!file) return;
  isSavingAvatar.value = true;
  try {
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      avatar: file,
      isFormData: true,
    });
    useAlert(t('GROUP.METADATA.SAVE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.METADATA.SAVE_ERROR'));
  } finally {
    isSavingAvatar.value = false;
    if (avatarFileInput.value) avatarFileInput.value.value = '';
  }
};

// Add member state
const showAddMember = ref(false);
const addMemberInput = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const showSearchDropdown = ref(false);

// Action menu state (per member)
const activeMenuMemberId = ref(null);
const loadingMemberId = ref(null);

// Invite link state
const inviteUrl = ref('');
const isFetchingInvite = ref(false);
const hasInviteLink = computed(() => !!inviteUrl.value);

// Join requests state
const pendingRequests = ref([]);
const isFetchingRequests = ref(false);
const loadingRequestJid = ref(null);

// Group settings state
const isAnnouncementMode = computed(
  () => props.contact.additional_attributes?.announce === true
);
const isLockedMode = computed(
  () => props.contact.additional_attributes?.restrict === true
);
const isJoinApprovalEnabled = computed(
  () => props.contact.additional_attributes?.join_approval_mode === true
);
const isTogglingAnnouncement = ref(false);
const isTogglingLocked = ref(false);
const isTogglingJoinApproval = ref(false);
const isLeavingGroup = ref(false);
const showLeaveConfirm = ref(false);

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

// Invite link methods
const fetchInviteLink = async () => {
  isFetchingInvite.value = true;
  try {
    const { data } = await GroupMembersAPI.getInviteLink(props.contact.id);
    inviteUrl.value = data.invite_url || '';
  } catch {
    inviteUrl.value = '';
  } finally {
    isFetchingInvite.value = false;
  }
};

const copyInviteLink = async () => {
  try {
    if (inviteUrl.value) {
      await copyTextToClipboard(inviteUrl.value);
      useAlert(t('GROUP.INVITE.COPY_SUCCESS'));
    }
  } catch {
    useAlert(t('GROUP.INVITE.FETCH_ERROR'));
  }
};

// Join request methods
const fetchPendingRequests = async () => {
  isFetchingRequests.value = true;
  try {
    const { data } = await GroupMembersAPI.getPendingRequests(props.contact.id);
    pendingRequests.value = data.payload || [];
  } catch {
    pendingRequests.value = [];
  } finally {
    isFetchingRequests.value = false;
  }
};

const handleJoinRequest = async (request, action) => {
  loadingRequestJid.value = request.jid;
  try {
    await GroupMembersAPI.handleJoinRequest(props.contact.id, {
      participants: [request.jid],
      request_action: action,
    });
    pendingRequests.value = pendingRequests.value.filter(
      r => r.jid !== request.jid
    );
    const msgKey =
      action === 'approve'
        ? 'GROUP.JOIN_REQUESTS.APPROVE_SUCCESS'
        : 'GROUP.JOIN_REQUESTS.REJECT_SUCCESS';
    useAlert(t(msgKey));
  } catch {
    useAlert(t('GROUP.JOIN_REQUESTS.ACTION_ERROR'));
  } finally {
    loadingRequestJid.value = null;
  }
};

// Group settings methods
const toggleAnnouncementMode = async () => {
  isTogglingAnnouncement.value = true;
  try {
    const setting = isAnnouncementMode.value
      ? 'not_announcement'
      : 'announcement';
    await GroupMembersAPI.updateGroupSetting(props.contact.id, { setting });
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      additional_attributes: {
        ...props.contact.additional_attributes,
        announce: !isAnnouncementMode.value,
      },
    });
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingAnnouncement.value = false;
  }
};

const toggleLockedMode = async () => {
  isTogglingLocked.value = true;
  try {
    const setting = isLockedMode.value ? 'unlocked' : 'locked';
    await GroupMembersAPI.updateGroupSetting(props.contact.id, { setting });
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      additional_attributes: {
        ...props.contact.additional_attributes,
        restrict: !isLockedMode.value,
      },
    });
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingLocked.value = false;
  }
};

const toggleJoinApproval = async () => {
  isTogglingJoinApproval.value = true;
  try {
    const mode = isJoinApprovalEnabled.value ? 'off' : 'on';
    await GroupMembersAPI.toggleJoinApproval(props.contact.id, { mode });
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      additional_attributes: {
        ...props.contact.additional_attributes,
        join_approval_mode: !isJoinApprovalEnabled.value,
      },
    });
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingJoinApproval.value = false;
  }
};

const leaveGroup = async () => {
  isLeavingGroup.value = true;
  try {
    await GroupMembersAPI.leaveGroup(props.contact.id);
    showLeaveConfirm.value = false;
    useAlert(t('GROUP.SETTINGS.LEAVE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.LEAVE_ERROR'));
  } finally {
    isLeavingGroup.value = false;
  }
};

onMounted(() => {
  if (props.contact.id) {
    store.dispatch('groupMembers/fetch', { contactId: props.contact.id });
    fetchInviteLink();
    fetchPendingRequests();
  }
});
</script>

<template>
  <div class="relative items-center w-full p-4">
    <div class="flex flex-col w-full gap-2 text-left rtl:text-right">
      <!-- Group header: avatar, name, member count, description -->
      <div class="flex flex-row items-start gap-3">
        <!-- Avatar (clickable for upload only when admin) -->
        <div
          class="relative shrink-0"
          :class="{ 'cursor-pointer group/avatar': isInboxAdmin }"
          @click="isInboxAdmin ? onAvatarClick() : undefined"
        >
          <Avatar
            :src="contact.thumbnail"
            :name="contact.name"
            :size="48"
            rounded-full
          />
          <div
            v-if="isInboxAdmin"
            class="absolute inset-0 flex items-center justify-center transition-opacity rounded-full opacity-0 bg-n-alpha-black2 group-hover/avatar:opacity-100"
          >
            <span
              v-if="isSavingAvatar"
              class="i-lucide-loader-2 animate-spin size-4 text-n-alpha-white1"
            />
            <span v-else class="i-lucide-camera size-4 text-n-alpha-white1" />
          </div>
          <input
            ref="avatarFileInput"
            type="file"
            accept="image/*"
            class="hidden"
            @change="onAvatarSelected"
          />
        </div>
        <div class="flex flex-col min-w-0 flex-1">
          <!-- Inline-editable name (only when admin) -->
          <div v-if="isEditingName" class="flex items-center gap-1">
            <input
              v-model="editNameValue"
              type="text"
              class="w-full px-2 py-1 text-base font-medium border rounded bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              :placeholder="t('GROUP.METADATA.EDIT_NAME_PLACEHOLDER')"
              @keydown="onNameKeydown"
              @blur="saveName"
            />
            <span
              v-if="isSavingName"
              class="i-lucide-loader-2 animate-spin size-4 text-n-slate-10 shrink-0"
            />
          </div>
          <div v-else class="flex items-center gap-2 min-w-0">
            <h3
              class="my-0 text-base font-medium capitalize break-words text-n-slate-12 cursor-pointer hover:text-n-brand"
              @click="startEditName"
            >
              {{ contact.name }}
            </h3>
            <div class="flex flex-row items-center gap-2 shrink-0">
              <span
                v-if="contact.created_at"
                v-tooltip.left="
                  `${t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                    contact.created_at
                  )}`
                "
                class="i-lucide-info text-sm text-n-slate-10"
              />
              <a
                :href="contactProfileLink"
                target="_blank"
                rel="noopener nofollow noreferrer"
                class="leading-3"
              >
                <span class="i-lucide-external-link text-sm text-n-slate-10" />
              </a>
            </div>
          </div>
          <span class="text-sm text-n-slate-11">
            {{ t('GROUP.INFO.MEMBER_COUNT', { count: memberCount }) }}
          </span>
        </div>
      </div>

      <!-- Inline-editable description (only when admin) -->
      <div class="mt-2">
        <label class="text-xs font-semibold text-n-slate-11">
          {{ t('GROUP.METADATA.EDIT_DESCRIPTION_LABEL') }}
        </label>
        <div v-if="isEditingDescription" class="relative mt-1">
          <textarea
            v-model="editDescriptionValue"
            rows="2"
            class="w-full px-2 py-1 text-sm border rounded bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
            :placeholder="t('GROUP.METADATA.EDIT_DESCRIPTION_PLACEHOLDER')"
            @blur="saveDescription"
          />
          <span
            v-if="isSavingDescription"
            class="absolute i-lucide-loader-2 animate-spin size-4 text-n-slate-10 right-2 top-2"
          />
        </div>
        <p
          v-else
          class="mt-1 text-sm break-words text-n-slate-12 cursor-pointer hover:text-n-brand"
          @click="startEditDescription"
        >
          {{
            contactDescription ||
            t('GROUP.METADATA.EDIT_DESCRIPTION_PLACEHOLDER')
          }}
        </p>
      </div>

      <!-- Members section -->
      <div class="mt-3">
        <div class="flex items-center justify-between mb-2">
          <h4 class="text-sm font-semibold text-n-slate-11">
            {{ t('GROUP.INFO.MEMBER_LIST_TITLE') }}
          </h4>
          <div class="flex items-center gap-1">
            <NextButton
              v-if="isInboxAdmin"
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
        <div
          v-else
          ref="memberListRef"
          class="flex flex-col gap-2 overflow-y-auto max-h-80"
          @scroll="onMemberListScroll"
        >
          <div
            v-for="member in members"
            :key="member.id"
            class="flex items-center gap-3 py-1 group"
          >
            <a
              :href="`/app/accounts/${route.params.accountId}/contacts/${member.contact.id}`"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="shrink-0"
            >
              <Avatar
                :src="member.contact.thumbnail"
                :name="member.contact.name"
                :size="32"
                rounded-full
              />
            </a>
            <div class="flex items-center flex-1 min-w-0 gap-2">
              <a
                :href="`/app/accounts/${route.params.accountId}/contacts/${member.contact.id}`"
                target="_blank"
                rel="noopener nofollow noreferrer"
                class="text-sm truncate text-n-slate-12 hover:text-n-brand"
              >
                {{ member.contact.name }}
              </a>
              <span
                v-if="member.role === 'admin'"
                class="px-1.5 py-0.5 text-xs font-medium rounded bg-n-amber-3 text-n-amber-11"
              >
                {{ t('GROUP.INFO.ADMIN_BADGE') }}
              </span>
              <span
                v-if="isOwnMember(member)"
                class="px-1.5 py-0.5 text-xs font-medium rounded bg-n-blue-3 text-n-blue-11"
              >
                {{ t('GROUP.INFO.YOU_BADGE') }}
              </span>
            </div>
            <!-- Loading spinner for this member -->
            <span
              v-if="isInboxAdmin && loadingMemberId === member.id"
              class="i-lucide-loader-2 animate-spin size-4 text-n-slate-10"
            />
            <!-- Action menu toggle (admin only, not for self) -->
            <div
              v-else-if="isInboxAdmin && !isOwnMember(member)"
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
          <!-- Loading more skeleton -->
          <div v-if="isFetchingMore" class="flex flex-col gap-3 pt-1">
            <div
              v-for="i in 3"
              :key="`more-${i}`"
              class="flex items-center gap-3"
            >
              <div class="rounded-full size-8 bg-n-slate-3 animate-pulse" />
              <div class="flex flex-col flex-1 gap-1">
                <div class="w-2/5 h-4 rounded bg-n-slate-3 animate-pulse" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Invite Link section (admin only, when link exists) -->
      <div v-if="isInboxAdmin && hasInviteLink" class="mt-4">
        <h4 class="mb-2 text-sm font-semibold text-n-slate-11">
          {{ t('GROUP.INVITE.SECTION_TITLE') }}
        </h4>
        <div class="flex items-center gap-2">
          <NextButton
            :label="t('GROUP.INVITE.COPY_INVITE_LINK')"
            icon="i-lucide-link"
            variant="ghost"
            size="xs"
            @click="copyInviteLink"
          />
        </div>
      </div>

      <!-- Pending Join Requests section (admin only) -->
      <div v-if="isInboxAdmin && pendingRequests.length > 0" class="mt-4">
        <h4 class="mb-2 text-sm font-semibold text-n-slate-11">
          {{ t('GROUP.JOIN_REQUESTS.SECTION_TITLE') }}
          <span class="ml-1 text-xs font-normal text-n-slate-10">
            {{
              t('GROUP.JOIN_REQUESTS.PENDING_COUNT', {
                count: pendingRequests.length,
              })
            }}
          </span>
        </h4>
        <div class="flex flex-col gap-2">
          <div
            v-for="request in pendingRequests"
            :key="request.jid"
            class="flex items-center gap-3 py-1"
          >
            <Avatar
              :name="request.name || request.jid"
              :size="32"
              rounded-full
            />
            <div class="flex flex-col flex-1 min-w-0">
              <span class="text-sm truncate text-n-slate-12">
                {{ request.name || request.jid }}
              </span>
              <span
                v-if="request.phone_number || request.jid"
                class="text-xs text-n-slate-10"
              >
                {{ request.phone_number || request.jid }}
              </span>
            </div>
            <span
              v-if="loadingRequestJid === request.jid"
              class="i-lucide-loader-2 animate-spin size-4 text-n-slate-10"
            />
            <div v-else class="flex items-center gap-1">
              <NextButton
                :label="t('GROUP.JOIN_REQUESTS.APPROVE_BUTTON')"
                icon="i-lucide-check"
                variant="ghost"
                size="xs"
                @click="handleJoinRequest(request, 'approve')"
              />
              <NextButton
                :label="t('GROUP.JOIN_REQUESTS.REJECT_BUTTON')"
                icon="i-lucide-x"
                variant="ghost"
                color="ruby"
                size="xs"
                @click="handleJoinRequest(request, 'reject')"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Group Settings section (admin only) -->
      <div v-if="isInboxAdmin" class="mt-4">
        <h4 class="mb-2 text-sm font-semibold text-n-slate-11">
          {{ t('GROUP.SETTINGS.SECTION_TITLE') }}
        </h4>
        <div class="flex flex-col gap-2">
          <!-- Announcement Mode -->
          <div class="flex items-center justify-between py-1">
            <div class="flex flex-col">
              <span class="text-sm text-n-slate-12">
                {{ t('GROUP.SETTINGS.ANNOUNCEMENT_MODE') }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{ t('GROUP.SETTINGS.ANNOUNCEMENT_MODE_DESCRIPTION') }}
              </span>
            </div>
            <button
              class="relative inline-flex items-center h-5 rounded-full w-9 transition-colors focus:outline-none"
              :class="isAnnouncementMode ? 'bg-n-brand' : 'bg-n-slate-5'"
              :disabled="isTogglingAnnouncement"
              @click="toggleAnnouncementMode"
            >
              <span
                v-if="isTogglingAnnouncement"
                class="i-lucide-loader-2 animate-spin size-3 absolute left-1/2 -translate-x-1/2 text-n-alpha-white1"
              />
              <span
                v-else
                class="inline-block size-4 rounded-full bg-white transition-transform"
                :class="
                  isAnnouncementMode ? 'translate-x-4' : 'translate-x-0.5'
                "
              />
            </button>
          </div>

          <!-- Locked Mode -->
          <div class="flex items-center justify-between py-1">
            <div class="flex flex-col">
              <span class="text-sm text-n-slate-12">
                {{ t('GROUP.SETTINGS.LOCKED_MODE') }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{ t('GROUP.SETTINGS.LOCKED_MODE_DESCRIPTION') }}
              </span>
            </div>
            <button
              class="relative inline-flex items-center h-5 rounded-full w-9 transition-colors focus:outline-none"
              :class="isLockedMode ? 'bg-n-brand' : 'bg-n-slate-5'"
              :disabled="isTogglingLocked"
              @click="toggleLockedMode"
            >
              <span
                v-if="isTogglingLocked"
                class="i-lucide-loader-2 animate-spin size-3 absolute left-1/2 -translate-x-1/2 text-n-alpha-white1"
              />
              <span
                v-else
                class="inline-block size-4 rounded-full bg-white transition-transform"
                :class="isLockedMode ? 'translate-x-4' : 'translate-x-0.5'"
              />
            </button>
          </div>

          <!-- Join Approval -->
          <div class="flex items-center justify-between py-1">
            <div class="flex flex-col">
              <span class="text-sm text-n-slate-12">
                {{ t('GROUP.SETTINGS.JOIN_APPROVAL') }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{ t('GROUP.SETTINGS.JOIN_APPROVAL_DESCRIPTION') }}
              </span>
            </div>
            <button
              class="relative inline-flex items-center h-5 rounded-full w-9 transition-colors focus:outline-none"
              :class="isJoinApprovalEnabled ? 'bg-n-brand' : 'bg-n-slate-5'"
              :disabled="isTogglingJoinApproval"
              @click="toggleJoinApproval"
            >
              <span
                v-if="isTogglingJoinApproval"
                class="i-lucide-loader-2 animate-spin size-3 absolute left-1/2 -translate-x-1/2 text-n-alpha-white1"
              />
              <span
                v-else
                class="inline-block size-4 rounded-full bg-white transition-transform"
                :class="
                  isJoinApprovalEnabled ? 'translate-x-4' : 'translate-x-0.5'
                "
              />
            </button>
          </div>
        </div>
      </div>

      <!-- Leave Group section -->
      <div class="mt-4">
        <div v-if="!showLeaveConfirm">
          <NextButton
            :label="t('GROUP.SETTINGS.LEAVE_GROUP')"
            icon="i-lucide-log-out"
            variant="ghost"
            color="ruby"
            size="xs"
            class="w-full"
            @click="showLeaveConfirm = true"
          />
        </div>
        <div
          v-else
          class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
        >
          <p class="text-sm text-n-slate-12">
            {{ t('GROUP.SETTINGS.LEAVE_CONFIRM') }}
          </p>
          <div class="flex items-center gap-2">
            <NextButton
              :label="t('GROUP.SETTINGS.LEAVE_CONFIRM_YES')"
              color="ruby"
              size="xs"
              :is-loading="isLeavingGroup"
              :disabled="isLeavingGroup"
              @click="leaveGroup"
            />
            <NextButton
              :label="t('GROUP.SETTINGS.LEAVE_CONFIRM_NO')"
              variant="ghost"
              size="xs"
              :disabled="isLeavingGroup"
              @click="showLeaveConfirm = false"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
