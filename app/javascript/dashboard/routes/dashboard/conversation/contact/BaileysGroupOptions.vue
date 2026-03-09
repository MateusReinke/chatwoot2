<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import GroupMembersAPI from 'dashboard/api/groupMembers';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
  isAdmin: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

// NOTE: Computed: read from additional_attributes (stored as restriction-active booleans)
// NOTE: WhatsApp shows "members CAN do X" so we invert restrict/announce for display
const canEditGroupSettings = computed(
  () => props.contact.additional_attributes?.restrict !== true
);
const canSendMessages = computed(
  () => props.contact.additional_attributes?.announce !== true
);
const canAddMembers = computed(
  () => props.contact.additional_attributes?.member_add_mode !== false
);
const isJoinApprovalEnabled = computed(
  () => props.contact.additional_attributes?.join_approval_mode === true
);

const isTogglingRestrict = ref(false);
const isTogglingAnnounce = ref(false);
const isTogglingMemberAdd = ref(false);
const isTogglingJoinApproval = ref(false);

const updateContactAttribute = async (key, value) => {
  await store.dispatch('contacts/update', {
    id: props.contact.id,
    additional_attributes: {
      ...props.contact.additional_attributes,
      [key]: value,
    },
  });
};

const toggleEditGroupSettings = async () => {
  isTogglingRestrict.value = true;
  try {
    // NOTE: restrict=true means members CANNOT edit; flip to the opposite of current
    const currentValue = props.contact.additional_attributes?.restrict === true;
    const newValue = !currentValue;
    await GroupMembersAPI.updateGroupProperty(props.contact.id, {
      property: 'restrict',
      enabled: newValue,
    });
    await updateContactAttribute('restrict', newValue);
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingRestrict.value = false;
  }
};

const toggleSendMessages = async () => {
  isTogglingAnnounce.value = true;
  try {
    // NOTE: announce=true means only admins can send; flip to the opposite of current
    const currentValue = props.contact.additional_attributes?.announce === true;
    const newValue = !currentValue;
    await GroupMembersAPI.updateGroupProperty(props.contact.id, {
      property: 'announce',
      enabled: newValue,
    });
    await updateContactAttribute('announce', newValue);
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingAnnounce.value = false;
  }
};

const toggleAddMembers = async () => {
  isTogglingMemberAdd.value = true;
  try {
    // NOTE: member_add_mode: true = all members can add, false = only admins
    const currentValue =
      props.contact.additional_attributes?.member_add_mode !== false;
    const newValue = !currentValue;
    await GroupMembersAPI.updateGroupProperty(props.contact.id, {
      property: 'member_add_mode',
      enabled: newValue,
    });
    await updateContactAttribute('member_add_mode', newValue);
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingMemberAdd.value = false;
  }
};

const toggleJoinApproval = async () => {
  isTogglingJoinApproval.value = true;
  try {
    // NOTE: join_approval_mode=true means admins must approve; flip to opposite
    const currentValue =
      props.contact.additional_attributes?.join_approval_mode === true;
    const newValue = !currentValue;
    await GroupMembersAPI.updateGroupProperty(props.contact.id, {
      property: 'join_approval_mode',
      enabled: newValue,
    });
    await updateContactAttribute('join_approval_mode', newValue);
    useAlert(t('GROUP.SETTINGS.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('GROUP.SETTINGS.UPDATE_ERROR'));
  } finally {
    isTogglingJoinApproval.value = false;
  }
};
</script>

<template>
  <div v-show="isAdmin" class="flex flex-col gap-3">
    <div>
      <h4 class="mb-2 text-xs font-semibold text-n-slate-10">
        {{ t('GROUP.BAILEYS_OPTIONS.MEMBERS_CAN') }}
      </h4>
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between py-1">
          <div class="flex flex-col pr-2">
            <span class="text-sm text-n-slate-12">
              {{ t('GROUP.BAILEYS_OPTIONS.EDIT_GROUP_SETTINGS') }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{ t('GROUP.BAILEYS_OPTIONS.EDIT_GROUP_SETTINGS_DESCRIPTION') }}
            </span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span
              v-if="isTogglingRestrict"
              class="i-lucide-loader-2 animate-spin size-3 text-n-slate-10"
            />
            <Switch
              :model-value="canEditGroupSettings"
              :disabled="isTogglingRestrict"
              @change="toggleEditGroupSettings"
            />
          </div>
        </div>

        <div class="flex items-center justify-between py-1">
          <div class="flex flex-col pr-2">
            <span class="text-sm text-n-slate-12">
              {{ t('GROUP.BAILEYS_OPTIONS.SEND_MESSAGES') }}
            </span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span
              v-if="isTogglingAnnounce"
              class="i-lucide-loader-2 animate-spin size-3 text-n-slate-10"
            />
            <Switch
              :model-value="canSendMessages"
              :disabled="isTogglingAnnounce"
              @change="toggleSendMessages"
            />
          </div>
        </div>

        <div class="flex items-center justify-between py-1">
          <div class="flex flex-col pr-2">
            <span class="text-sm text-n-slate-12">
              {{ t('GROUP.BAILEYS_OPTIONS.ADD_MEMBERS') }}
            </span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span
              v-if="isTogglingMemberAdd"
              class="i-lucide-loader-2 animate-spin size-3 text-n-slate-10"
            />
            <Switch
              :model-value="canAddMembers"
              :disabled="isTogglingMemberAdd"
              @change="toggleAddMembers"
            />
          </div>
        </div>

        <!-- Invite via link or QR code (placeholder — no route yet) -->
        <div class="flex items-center justify-between py-1 opacity-50">
          <div class="flex flex-col pr-2">
            <span class="text-sm text-n-slate-12">
              {{ t('GROUP.BAILEYS_OPTIONS.INVITE_VIA_LINK') }}
              <span class="text-xs text-n-slate-9">
                {{ t('GROUP.BAILEYS_OPTIONS.NOT_AVAILABLE') }}
              </span>
            </span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <Switch model-value disabled />
          </div>
        </div>
      </div>
    </div>

    <div>
      <h4 class="mb-2 text-xs font-semibold text-n-slate-10">
        {{ t('GROUP.BAILEYS_OPTIONS.ADMINS_CAN') }}
      </h4>
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between py-1">
          <div class="flex flex-col pr-2">
            <span class="text-sm text-n-slate-12">
              {{ t('GROUP.BAILEYS_OPTIONS.APPROVE_MEMBERS') }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{ t('GROUP.BAILEYS_OPTIONS.APPROVE_MEMBERS_DESCRIPTION') }}
            </span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span
              v-if="isTogglingJoinApproval"
              class="i-lucide-loader-2 animate-spin size-3 text-n-slate-10"
            />
            <Switch
              :model-value="isJoinApprovalEnabled"
              :disabled="isTogglingJoinApproval"
              @change="toggleJoinApproval"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
