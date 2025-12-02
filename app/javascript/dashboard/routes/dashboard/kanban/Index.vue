<template>
  <div class="flex flex-col h-full bg-slate-25 dark:bg-slate-900">
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b border-slate-75 dark:border-slate-800">
      <div class="flex items-center gap-4">
        <h1 class="text-2xl font-semibold text-slate-800 dark:text-slate-100">
          {{ $t('KANBAN.TITLE') }}
        </h1>
        <span class="text-sm text-slate-600 dark:text-slate-400">
          {{ totalLeads }} {{ $t('KANBAN.LEADS') }}
        </span>
      </div>

      <div class="flex items-center gap-2">
        <woot-button
          color-scheme="secondary"
          icon="arrow-clockwise"
          @click="refreshData"
        >
          {{ $t('KANBAN.REFRESH') }}
        </woot-button>
      </div>
    </div>

    <!-- Filters -->
    <kanban-filters
      v-model:search="filters.search"
      v-model:temperatura="filters.temperatura"
      v-model:score="filters.score"
      v-model:inbox="filters.inbox_id"
      :inboxes="inboxes"
      @filter="loadLeads"
    />

    <!-- Loading State -->
    <div v-if="uiFlags.isFetching" class="flex items-center justify-center h-full">
      <spinner size="large" />
    </div>

    <!-- Kanban Board -->
    <kanban-board
      v-else
      :columns="columns"
      :leads-by-status="leadsByStatus"
      :status-conversao="statusConversao"
      @move-card="handleMoveCard"
      @export-column="handleExportColumn"
    />

    <!-- Stats Footer -->
    <div class="flex items-center justify-between p-4 border-t border-slate-75 dark:border-slate-800 bg-white dark:bg-slate-800">
      <div class="flex gap-6">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full bg-red-500"></div>
          <span class="text-sm text-slate-600 dark:text-slate-400">
            🔥 Quente: {{ stats.by_temperatura?.quente || 0 }}
          </span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
          <span class="text-sm text-slate-600 dark:text-slate-400">
            ☀️ Morno: {{ stats.by_temperatura?.morno || 0 }}
          </span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full bg-blue-500"></div>
          <span class="text-sm text-slate-600 dark:text-slate-400">
            ❄️ Frio: {{ stats.by_temperatura?.frio || 0 }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import KanbanBoard from '../../../components/kanban/KanbanBoard.vue';
import KanbanFilters from '../../../components/kanban/KanbanFilters.vue';
import KanbanAPI from '../../../api/kanban';
import Spinner from '../../../components/ui/Spinner.vue';
import { useAlert } from 'dashboard/composables';

const store = useStore();
const { t } = useI18n();
const { showAlert } = useAlert();

// Estado
const leadsByStatus = ref({});
const stats = ref({});
const filters = ref({
  search: '',
  temperatura: '',
  score: '',
  inbox_id: null,
});

const uiFlags = ref({
  isFetching: false,
  isMoving: false,
});

// Computed
const currentAccount = computed(() => store.getters.getCurrentAccount);
const statusConversao = computed(() =>
  currentAccount.value?.custom_attributes?.status_conversao || 'convertido'
);

const columns = computed(() => [
  { id: 'novo_lead', title: t('KANBAN.STATUS.NOVO_LEAD'), color: 'blue' },
  { id: 'aquecimento', title: t('KANBAN.STATUS.AQUECIMENTO'), color: 'yellow' },
  { id: 'qualificado', title: t('KANBAN.STATUS.QUALIFICADO'), color: 'green' },
  {
    id: statusConversao.value,
    title: formatStatusLabel(statusConversao.value),
    color: 'emerald'
  },
  { id: 'perdido', title: t('KANBAN.STATUS.PERDIDO'), color: 'red' },
]);

const inboxes = computed(() => store.getters['inboxes/getInboxes']);

const totalLeads = computed(() => {
  return Object.values(leadsByStatus.value).reduce(
    (sum, leads) => sum + leads.length,
    0
  );
});

// Methods
const loadLeads = async () => {
  uiFlags.value.isFetching = true;

  try {
    const response = await KanbanAPI.getLeads(filters.value);
    leadsByStatus.value = response.data.kanban_data || {};
    stats.value = response.data.stats || {};
  } catch (error) {
    showAlert(t('KANBAN.API.ERROR.FETCH'));
    console.error('Error loading leads:', error);
  } finally {
    uiFlags.value.isFetching = false;
  }
};

const handleMoveCard = async ({ conversationId, newStatus }) => {
  uiFlags.value.isMoving = true;

  try {
    await KanbanAPI.moveCard(conversationId, newStatus);
    showAlert(t('KANBAN.API.SUCCESS.MOVE'));

    // Recarregar dados
    await loadLeads();
  } catch (error) {
    showAlert(t('KANBAN.API.ERROR.MOVE'));
    console.error('Error moving card:', error);
  } finally {
    uiFlags.value.isMoving = false;
  }
};

const handleExportColumn = async (status) => {
  try {
    const response = await KanbanAPI.exportColumn(status);
    const data = response.data.data;

    // Converter para CSV
    if (data.length === 0) {
      showAlert(t('KANBAN.EXPORT.NO_DATA'));
      return;
    }

    const headers = Object.keys(data[0]);
    const csv = [
      headers.join(','),
      ...data.map(row => headers.map(h => `"${row[h] || ''}"`).join(','))
    ].join('\n');

    // Download
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `leads_${status}_${new Date().toISOString()}.csv`;
    link.click();

    showAlert(t('KANBAN.EXPORT.SUCCESS'));
  } catch (error) {
    showAlert(t('KANBAN.EXPORT.ERROR'));
    console.error('Error exporting:', error);
  }
};

const refreshData = () => {
  loadLeads();
};

const formatStatusLabel = (status) => {
  const labels = {
    'convertido': 'Convertido',
    'agendado': 'Agendado',
    'vendido': 'Vendido',
  };
  return labels[status] || status.charAt(0).toUpperCase() + status.slice(1);
};

// Lifecycle
onMounted(() => {
  loadLeads();
  store.dispatch('inboxes/get');
});
</script>
