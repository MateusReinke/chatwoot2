<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { debounce } from '@chatwoot/utils';
import ContactsAPI from 'dashboard/api/contacts';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const route = useRoute();

const dialogRef = ref(null);
const groupName = ref('');
const selectedInboxId = ref('');
const participantInput = ref('');
const participants = ref([]);
const searchResults = ref([]);
const isSearching = ref(false);
const showDropdown = ref(false);

const inboxesList = useMapGetter('inboxes/getInboxes');
const uiFlags = useMapGetter('groupMembers/getUIFlags');

const isCreating = computed(() => uiFlags.value.isCreating);

const whatsappInboxes = computed(() =>
  inboxesList.value.filter(inbox => inbox.channel_type === INBOX_TYPES.WHATSAPP)
);

const isFormValid = computed(
  () => selectedInboxId.value && groupName.value.trim()
);

const searchContacts = debounce(
  async query => {
    if (!query || query.length < 2) {
      searchResults.value = [];
      showDropdown.value = false;
      return;
    }
    isSearching.value = true;
    try {
      const { data } = await ContactsAPI.search(query);
      searchResults.value = (data.payload || []).filter(
        contact =>
          contact.phone_number &&
          !participants.value.some(p => p.phone_number === contact.phone_number)
      );
      showDropdown.value = searchResults.value.length > 0;
    } catch {
      searchResults.value = [];
    } finally {
      isSearching.value = false;
    }
  },
  300,
  false
);

const onParticipantInput = event => {
  participantInput.value = event.target.value;
  searchContacts(participantInput.value);
};

const addParticipant = contact => {
  participants.value.push(contact);
  participantInput.value = '';
  searchResults.value = [];
  showDropdown.value = false;
};

const removeParticipant = index => {
  participants.value.splice(index, 1);
};

const resetForm = () => {
  groupName.value = '';
  selectedInboxId.value = '';
  participantInput.value = '';
  participants.value = [];
  searchResults.value = [];
  showDropdown.value = false;
};

const handleSubmit = async () => {
  if (!isFormValid.value) return;
  try {
    const data = await store.dispatch('groupMembers/createGroup', {
      inbox_id: selectedInboxId.value,
      subject: groupName.value.trim(),
      participants: participants.value.map(p => p.phone_number),
    });
    const url = frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: data.id,
      })
    );
    resetForm();
    dialogRef.value?.close();
    useAlert(t('GROUP.CREATE.SUCCESS_MESSAGE'));
    router.push({ path: url });
  } catch {
    useAlert(t('GROUP.CREATE.ERROR_MESSAGE'));
  }
};

const open = () => {
  dialogRef.value?.open();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('GROUP.CREATE.TITLE')"
    :show-confirm-button="false"
    :show-cancel-button="false"
    width="lg"
    @close="resetForm"
  >
    <div class="flex flex-col gap-4">
      <!-- Inbox selector -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('GROUP.CREATE.INBOX_LABEL') }}
        </label>
        <select
          v-model="selectedInboxId"
          class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        >
          <option value="" disabled>
            {{ t('GROUP.CREATE.INBOX_PLACEHOLDER') }}
          </option>
          <option
            v-for="inbox in whatsappInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>
      </div>

      <!-- Group name -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('GROUP.CREATE.NAME_LABEL') }}
        </label>
        <input
          v-model="groupName"
          type="text"
          class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :placeholder="t('GROUP.CREATE.NAME_PLACEHOLDER')"
        />
      </div>

      <!-- Participants -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('GROUP.CREATE.PARTICIPANTS_LABEL') }}
        </label>
        <!-- Selected participants chips -->
        <div v-if="participants.length" class="flex flex-wrap gap-1.5 mb-1">
          <span
            v-for="(participant, index) in participants"
            :key="participant.id"
            class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-12"
          >
            {{ participant.name || participant.phone_number }}
            <button
              type="button"
              class="i-lucide-x size-3 text-n-slate-10 hover:text-n-slate-12"
              @click="removeParticipant(index)"
            />
          </span>
        </div>
        <!-- Search input -->
        <div class="relative">
          <input
            :value="participantInput"
            type="text"
            class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :placeholder="t('GROUP.CREATE.PARTICIPANTS_PLACEHOLDER')"
            @input="onParticipantInput"
            @focus="showDropdown = searchResults.length > 0"
          />
          <span
            v-if="isSearching"
            class="absolute i-lucide-loader-2 animate-spin size-4 text-n-slate-10 right-3 top-2.5"
          />
          <!-- Dropdown results -->
          <ul
            v-if="showDropdown"
            class="absolute z-10 w-full mt-1 overflow-y-auto border rounded-lg shadow-lg bg-n-alpha-3 backdrop-blur-[100px] border-n-weak max-h-48"
          >
            <li
              v-for="contact in searchResults"
              :key="contact.id"
              class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer text-n-slate-12 hover:bg-n-alpha-2"
              @click="addParticipant(contact)"
            >
              <span class="truncate">{{ contact.name }}</span>
              <span class="text-xs text-n-slate-10">
                {{ contact.phone_number }}
              </span>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="faded"
          color="slate"
          class="w-full"
          type="button"
          @click="dialogRef?.close()"
        />
        <Button
          :label="t('GROUP.CREATE.SUBMIT_BUTTON')"
          color="blue"
          class="w-full"
          type="button"
          :disabled="!isFormValid || isCreating"
          :is-loading="isCreating"
          @click="handleSubmit"
        />
      </div>
    </template>
  </Dialog>
</template>
