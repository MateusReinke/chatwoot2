<template>
  <div
    class="p-4 bg-white dark:bg-slate-900 rounded-lg border border-slate-200 dark:border-slate-700 cursor-move hover:shadow-md transition-shadow"
    :class="{ 'opacity-50': isDragging }"
    draggable="true"
    @dragstart="handleDragStart"
    @dragend="handleDragEnd"
    @click="openConversation"
  >
    <!-- Header: Nome e Score -->
    <div class="flex items-start justify-between mb-3">
      <div class="flex-1">
        <h4 class="font-medium text-slate-900 dark:text-slate-100 truncate">
          {{ contactName }}
        </h4>
        <p class="text-sm text-slate-500 dark:text-slate-400">
          {{ contactPhone }}
        </p>
      </div>

      <div class="flex items-center gap-2">
        <!-- Temperatura -->
        <span class="text-lg" :title="temperaturaLabel">
          {{ temperaturaEmoji }}
        </span>

        <!-- Lead Score Badge -->
        <div
          class="px-2 py-1 text-xs font-semibold rounded"
          :class="scoreColorClass"
        >
          {{ leadScore }}
        </div>
      </div>
    </div>

    <!-- Informações Adicionais -->
    <div v-if="servicoInteresse" class="mb-2">
      <p class="text-sm text-slate-600 dark:text-slate-300">
        <fluent-icon icon="heart" size="12" class="inline mr-1" />
        {{ servicoInteresse }}
      </p>
    </div>

    <!-- Dores -->
    <div v-if="doresIdentificadas" class="mb-2">
      <p class="text-xs text-orange-600 dark:text-orange-400 line-clamp-2">
        <fluent-icon icon="warning" size="12" class="inline mr-1" />
        {{ doresIdentificadas }}
      </p>
    </div>

    <!-- Objeções -->
    <div v-if="objecoes" class="mb-3">
      <p class="text-xs text-red-600 dark:text-red-400 line-clamp-2">
        <fluent-icon icon="dismiss-circle" size="12" class="inline mr-1" />
        {{ objecoes }}
      </p>
    </div>

    <!-- Footer: Última mensagem e data -->
    <div class="flex items-center justify-between pt-3 border-t border-slate-100 dark:border-slate-800">
      <div class="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
        <fluent-icon icon="chat" size="12" />
        <span>{{ totalMensagens }} msgs</span>
      </div>

      <span class="text-xs text-slate-500 dark:text-slate-400">
        {{ lastActivityFormatted }}
      </span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const props = defineProps({
  lead: {
    type: Object,
    required: true,
  },
  columnId: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['drag-start']);

const router = useRouter();
const isDragging = ref(false);

// Computed
const contact = computed(() => props.lead.contact || {});
const customAttributes = computed(() => contact.value.custom_attributes || {});

const contactName = computed(() => contact.value.name || 'Sem nome');
const contactPhone = computed(() => contact.value.phone_number || '');

const leadScore = computed(() => customAttributes.value.lead_score || 0);
const temperatura = computed(() => customAttributes.value.temperatura || 'frio');
const servicoInteresse = computed(() => customAttributes.value.servico_interesse);
const doresIdentificadas = computed(() => customAttributes.value.dores_identificadas);
const objecoes = computed(() => customAttributes.value.objecoes);
const totalMensagens = computed(() => props.lead.messages_count || 0);

const temperaturaEmoji = computed(() => {
  const emojis = {
    quente: '🔥',
    morno: '☀️',
    frio: '❄️',
  };
  return emojis[temperatura.value] || '❄️';
});

const temperaturaLabel = computed(() => {
  const labels = {
    quente: 'Lead Quente',
    morno: 'Lead Morno',
    frio: 'Lead Frio',
  };
  return labels[temperatura.value] || 'Lead Frio';
});

const scoreColorClass = computed(() => {
  const score = leadScore.value;
  if (score >= 70) {
    return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100';
  } else if (score >= 40) {
    return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100';
  } else {
    return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-100';
  }
});

const lastActivityFormatted = computed(() => {
  if (!props.lead.last_activity_at) return 'Nunca';

  return formatDistanceToNow(new Date(props.lead.last_activity_at), {
    addSuffix: true,
    locale: ptBR,
  });
});

// Methods
const handleDragStart = (event) => {
  isDragging.value = true;
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('conversationId', props.lead.id);
  emit('drag-start', props.lead.id);
};

const handleDragEnd = () => {
  isDragging.value = false;
};

const openConversation = () => {
  if (props.lead.id) {
    router.push({
      name: 'inbox_conversation',
      params: {
        conversation_id: props.lead.id,
      },
    });
  }
};
</script>
