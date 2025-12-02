import { frontendURL } from '../../../helper/URLHelper';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/kanban'),
      name: 'kanban',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: () => import('./Index.vue'),
    },
  ],
};
