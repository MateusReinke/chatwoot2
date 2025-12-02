<template>
  <div
    class="flex flex-col w-80 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 flex-shrink-0"
    :class="{ 'ring-2 ring-woot-500': isOver }"
    @drop.prevent="handleDrop"
    @dragover.prevent="handleDragOver"
    @dragleave="handleDragLeave"
  >
    <!-- Column Header -->
    <div
      class="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-700"
      :class="headerColorClass"
    >
      <div class="flex items-center gap-2">
        <h3 class="font-semibold text-slate-900 dark:text-slate-100">
          {{ column.title }}
        </h3>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
        >
          {{ leads.length }}
        </span>
      </div>

      <woot-button
        variant="link"
        size="small"
        icon="download"
        color-scheme="secondary"
        @click="$emit('export')"
      >
        Export
      </woot-button>
    </div>

    <!-- Cards Container -->
    <div class="flex-1 overflow-y-auto p-3 space-y-3 min-h-[200px]">
      <kanban-card
        v-for="lead in leads"
        :key="lead.id"
        :lead="lead"
        :column-id="column.id"
        @drag-start="handleCardDragStart"
      />

      <div v-if="leads.length === 0" class="flex flex-col items-center justify-center py-8 text-slate-400">
        <fluent-icon icon="inbox" size="24" class="mb-2" />
        <p class="text-sm">{{ $t('KANBAN.EMPTY_COLUMN') }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, getCurrentInstance } from 'vue';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  column: {
    type: Object,
    required: true,
  },
  leads: {
    type: Array,
    default: () => [],
  },
  isOver: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['drop', 'drag-over', 'drag-leave', 'export']);

const headerColorClass = computed(() => {
  const colors = {
    blue: 'bg-blue-50 dark:bg-blue-900/20',
    yellow: 'bg-yellow-50 dark:bg-yellow-900/20',
    green: 'bg-green-50 dark:bg-green-900/20',
    emerald: 'bg-emerald-50 dark:bg-emerald-900/20',
    red: 'bg-red-50 dark:bg-red-900/20',
  };
  return colors[props.column.color] || 'bg-slate-50 dark:bg-slate-800';
});

const handleDrop = (event) => {
  const conversationId = event.dataTransfer.getData('conversationId');
  emit('drop', conversationId);
};

const handleDragOver = () => {
  emit('drag-over');
};

const handleDragLeave = () => {
  emit('drag-leave');
};

const handleCardDragStart = (conversationId) => {
  // Propagar para o board
  const board = findParentBoard();
  if (board) {
    board.setDraggedCard(conversationId, props.column.id);
  }
};

const findParentBoard = () => {
  // Encontra a instância do KanbanBoard no parent
  let parent = getCurrentInstance()?.parent;
  while (parent) {
    if (parent.type.name === 'KanbanBoard' || parent.exposed?.setDraggedCard) {
      return parent.exposed || parent.proxy;
    }
    parent = parent.parent;
  }
  return null;
};
</script>
