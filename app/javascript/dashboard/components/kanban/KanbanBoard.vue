<template>
  <div class="flex-1 overflow-x-auto overflow-y-hidden">
    <div class="flex gap-4 p-4 h-full min-w-max">
      <kanban-column
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :leads="leadsByStatus[column.id] || []"
        :is-over="dragState.overColumn === column.id"
        @drop="handleDrop($event, column.id)"
        @drag-over="handleDragOver(column.id)"
        @drag-leave="handleDragLeave"
        @export="$emit('export-column', column.id)"
      />
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import KanbanColumn from './KanbanColumn.vue';

const props = defineProps({
  columns: {
    type: Array,
    required: true,
  },
  leadsByStatus: {
    type: Object,
    required: true,
  },
  statusConversao: {
    type: String,
    default: 'convertido',
  },
});

const emit = defineEmits(['move-card', 'export-column']);

// Estado do drag & drop
const dragState = ref({
  draggedCard: null,
  sourceColumn: null,
  overColumn: null,
});

const handleDrop = (conversationId, targetColumn) => {
  if (!dragState.value.draggedCard) return;

  const sourceColumn = dragState.value.sourceColumn;

  // Não fazer nada se dropou na mesma coluna
  if (sourceColumn === targetColumn) {
    resetDragState();
    return;
  }

  // Emitir evento de movimentação
  emit('move-card', {
    conversationId: dragState.value.draggedCard,
    oldStatus: sourceColumn,
    newStatus: targetColumn,
  });

  resetDragState();
};

const handleDragOver = (columnId) => {
  dragState.value.overColumn = columnId;
};

const handleDragLeave = () => {
  dragState.value.overColumn = null;
};

const setDraggedCard = (conversationId, sourceColumn) => {
  dragState.value.draggedCard = conversationId;
  dragState.value.sourceColumn = sourceColumn;
};

const resetDragState = () => {
  dragState.value.draggedCard = null;
  dragState.value.sourceColumn = null;
  dragState.value.overColumn = null;
};

// Expor método para os cards iniciarem o drag
defineExpose({
  setDraggedCard,
});
</script>
