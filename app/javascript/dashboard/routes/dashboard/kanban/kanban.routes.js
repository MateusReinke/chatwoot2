import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './Index.vue';

const meta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    component: KanbanIndex,
    name: 'kanban_view',
    meta,
  },
];
