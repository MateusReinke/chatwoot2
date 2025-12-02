<template>
  <div class="flex items-center gap-3 p-4 bg-white dark:bg-slate-800 border-b border-slate-75 dark:border-slate-700">
    <!-- Busca -->
    <div class="flex-1 max-w-md">
      <input
        :value="search"
        type="text"
        :placeholder="$t('KANBAN.FILTERS.SEARCH_PLACEHOLDER')"
        class="w-full px-4 py-2 text-sm border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500 dark:bg-slate-900 dark:text-slate-100"
        @input="$emit('update:search', $event.target.value)"
        @keyup.enter="$emit('filter')"
      />
    </div>

    <!-- Filtro: Temperatura -->
    <select
      :value="temperatura"
      class="px-4 py-2 text-sm border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500 dark:bg-slate-900 dark:text-slate-100"
      @change="handleTemperaturaChange"
    >
      <option value="">{{ $t('KANBAN.FILTERS.ALL_TEMPERATURA') }}</option>
      <option value="quente">🔥 Quente</option>
      <option value="morno">☀️ Morno</option>
      <option value="frio">❄️ Frio</option>
    </select>

    <!-- Filtro: Score -->
    <select
      :value="score"
      class="px-4 py-2 text-sm border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500 dark:bg-slate-900 dark:text-slate-100"
      @change="handleScoreChange"
    >
      <option value="">{{ $t('KANBAN.FILTERS.ALL_SCORES') }}</option>
      <option value="alto">Alto (70-100)</option>
      <option value="medio">Médio (40-69)</option>
      <option value="baixo">Baixo (0-39)</option>
    </select>

    <!-- Filtro: Inbox -->
    <select
      :value="inbox"
      class="px-4 py-2 text-sm border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500 dark:bg-slate-900 dark:text-slate-100"
      @change="handleInboxChange"
    >
      <option :value="null">{{ $t('KANBAN.FILTERS.ALL_INBOXES') }}</option>
      <option v-for="inboxItem in inboxes" :key="inboxItem.id" :value="inboxItem.id">
        {{ inboxItem.name }}
      </option>
    </select>

    <!-- Botão Limpar Filtros -->
    <woot-button
      v-if="hasActiveFilters"
      variant="link"
      size="small"
      color-scheme="secondary"
      @click="clearFilters"
    >
      {{ $t('KANBAN.FILTERS.CLEAR') }}
    </woot-button>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  search: {
    type: String,
    default: '',
  },
  temperatura: {
    type: String,
    default: '',
  },
  score: {
    type: String,
    default: '',
  },
  inbox: {
    type: [Number, null],
    default: null,
  },
  inboxes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:search', 'update:temperatura', 'update:score', 'update:inbox', 'filter']);

const hasActiveFilters = computed(() => {
  return props.search || props.temperatura || props.score || props.inbox;
});

const handleTemperaturaChange = (event) => {
  emit('update:temperatura', event.target.value);
  emit('filter');
};

const handleScoreChange = (event) => {
  emit('update:score', event.target.value);
  emit('filter');
};

const handleInboxChange = (event) => {
  const value = event.target.value;
  emit('update:inbox', value ? parseInt(value, 10) : null);
  emit('filter');
};

const clearFilters = () => {
  emit('update:search', '');
  emit('update:temperatura', '');
  emit('update:score', '');
  emit('update:inbox', null);
  emit('filter');
};
</script>
