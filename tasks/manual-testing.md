## Manual Test Checklist

Execute esses testes manualmente ao final da implementação para garantir que tudo funciona como esperado. Pré-requisito: ter uma inbox Baileys conectada com ao menos um grupo existente no WhatsApp.

### 1. Serialização & Dados

- [ ] **T-01:** Abrir o DevTools → Network. Carregar a lista de conversas. Verificar que o JSON de cada conversa inclui o campo `group_type` (`"individual"` ou `"group"`).
- [ ] **T-02:** Abrir uma conversa de grupo. Verificar que o JSON do contato no `meta.sender` inclui `group_type: "group"`.
- [ ] **T-03:** Abrir uma conversa individual. Verificar que `group_type` é `"individual"` tanto na conversa quanto no contato.

### 2. Filtros

- [ ] **T-04:** No dropdown de filtro rápido (ícone de seta/sort), verificar que existe a seção "Type" com opções "All", "Individual", "Group".
- [ ] **T-05:** Selecionar "Group" → apenas conversas de grupo aparecem na lista. Selecionar "Individual" → apenas individuais. Selecionar "All" → todas.
- [ ] **T-06:** Fechar e reabrir o Chatwoot. Verificar que o filtro de tipo persiste (salvo em UI settings).
- [ ] **T-07:** Abrir o filtro avançado. Verificar que `group_type` aparece como atributo de filtro em "Standard Filters".
- [ ] **T-08:** Criar um filtro avançado: `group_type equal_to group`. Verificar que retorna apenas conversas de grupo.
- [ ] **T-09:** Criar um filtro avançado: `group_type not_equal_to group`. Verificar que retorna apenas conversas individuais.

### 3. Painel Lateral — GroupContactInfo

- [ ] **T-10:** Abrir uma conversa de grupo. Verificar que o painel lateral mostra "Group" como título (não "Contact").
- [ ] **T-11:** Verificar que o `GroupContactInfo` exibe: avatar do grupo, nome do grupo, contagem de membros ativos.
- [ ] **T-12:** Verificar que a lista de membros mostra nome, avatar/placeholder, e badge "Admin" apenas para admins (membros sem badge).
- [ ] **T-13:** Verificar que skeleton loading aparece enquanto os membros estão sendo carregados.
- [ ] **T-14:** Verificar que membros inativos/removidos **não** aparecem na lista.
- [ ] **T-15:** Abrir uma conversa individual. Verificar que o `ContactInfo` original aparece (sem regressão).
- [ ] **T-16:** Verificar que as seções `contact_notes` e `contact_attributes` continuam visíveis para conversas de grupo.

### 4. Sync do Grupo

- [ ] **T-17:** Clicar no botão "Sync" no GroupContactInfo. Verificar que um spinner aparece durante o sync.
- [ ] **T-18:** Após o sync, verificar que a lista de membros é atualizada (pode alterar um membro no WhatsApp antes para validar).
- [ ] **T-19:** Verificar que um alerta de sucesso aparece após sync bem-sucedido.
- [ ] **T-20:** Desconectar o provedor Baileys e tentar sync. Verificar que um alerta de erro aparece.

### 5. Criação de Grupo

- [ ] **T-21:** Abrir o modal/UI de criação de grupo. Verificar que é possível selecionar uma inbox (somente inboxes que suportam grupos).
- [ ] **T-22:** Preencher nome do grupo e selecionar participantes. Submeter. Verificar que o grupo é criado no WhatsApp.
- [ ] **T-23:** Verificar que após criação, o app navega para a nova conversa de grupo.
- [ ] **T-24:** No WhatsApp, verificar que o grupo existe com o nome e participantes corretos.

### 6. Gerenciamento de Membros

- [ ] **T-25:** No GroupContactInfo, clicar em "Add member". Buscar um contato por nome/telefone. Adicionar. Verificar que o membro aparece na lista e foi adicionado no WhatsApp.
- [ ] **T-26:** Remover um membro pelo menu de contexto. Verificar que desaparece da lista e foi removido no WhatsApp.
- [ ] **T-27:** Promover um membro a admin. Verificar que o badge "Admin" aparece e a mudança reflete no WhatsApp.
- [ ] **T-28:** Rebaixar um admin a membro. Verificar que o badge "Admin" desaparece e a mudança reflete no WhatsApp.
- [ ] **T-29:** Verificar loading states durante add/remove/promote/demote.

### 7. Edição de Metadados do Grupo

- [ ] **T-30:** Clicar no nome do grupo para editar. Alterar o nome. Verificar que salva e atualiza no WhatsApp.
- [ ] **T-31:** Editar a descrição do grupo. Verificar que salva e atualiza no WhatsApp.
- [ ] **T-32:** Clicar no avatar para upload. Selecionar uma imagem. Verificar que a foto do grupo atualiza no Chatwoot e no WhatsApp.
- [ ] **T-33:** Verificar loading states durante cada edição.

### 8. Link de Convite

- [ ] **T-34:** Na seção de invite link, verificar que o link é exibido.
- [ ] **T-35:** Clicar em "Copy". Verificar que o link é copiado para a área de transferência (colar em algum lugar para confirmar).
- [ ] **T-36:** Clicar em "Revoke & Regenerate". Verificar que um novo link é gerado (diferente do anterior).
- [ ] **T-37:** Usar o link antigo (revogado) em um navegador — deve ser inválido.
- [ ] **T-38:** Usar o novo link — deve funcionar (se join approval estiver desligado).

### 9. Aprovação de Solicitações de Entrada

- [ ] **T-39:** Ativar "join approval mode" no grupo via WhatsApp. Enviar o link de convite para um contato externo que solicite entrada.
- [ ] **T-40:** Verificar que a seção "Pending Requests" aparece no GroupContactInfo com a solicitação.
- [ ] **T-41:** Clicar em "Approve" em uma solicitação. Verificar que o contato entra no grupo no WhatsApp.
- [ ] **T-42:** Clicar em "Reject" em outra solicitação. Verificar que o contato **não** entra no grupo.
- [ ] **T-43:** Quando não há solicitações pendentes, verificar que a seção não é visível.

### 10. Bolhas de Mensagem de Grupo

- [ ] **T-44:** Abrir uma conversa de grupo com várias mensagens de diferentes remetentes. Verificar que cada bolha mostra o nome do remetente acima do texto.
- [ ] **T-45:** Verificar que a cor do nome do remetente é consistente (mesmo remetente = mesma cor sempre) e varia entre remetentes diferentes.
- [ ] **T-46:** Verificar que mensagens consecutivas do mesmo remetente **não** repetem o nome (só mostra na primeira da sequência).
- [ ] **T-47:** Verificar que o avatar do remetente aparece à esquerda das bolhas (com foto se disponível, placeholder com iniciais se não).
- [ ] **T-48:** Verificar que o avatar não se repete para mensagens consecutivas do mesmo remetente.
- [ ] **T-49:** Abrir uma conversa individual. Verificar que nome e avatar do remetente **não** aparecem nas bolhas (sem regressão).

### 11. Sistema de @Mentions

- [ ] **T-50:** Em uma conversa de grupo, digitar `@` no editor de mensagens. Verificar que um dropdown de sugestão aparece com membros do grupo.
- [ ] **T-51:** Digitar parte do nome de um membro após `@`. Verificar que o dropdown filtra corretamente.
- [ ] **T-52:** Selecionar um membro do dropdown. Verificar que uma mention tag é inserida no editor.
- [ ] **T-53:** Enviar a mensagem. Verificar que a mention aparece formatada/destacada na bolha de mensagem.
- [ ] **T-54:** Em uma conversa individual, digitar `@`. Verificar que o dropdown de mention de grupo **não** aparece (comportamento existente de notas privadas permanece inalterado).

### 12. Atualização em Tempo Real (ActionCable)

- [ ] **T-55:** Abrir uma conversa de grupo no Chatwoot. Em paralelo, adicionar um membro ao grupo via WhatsApp diretamente. Verificar que o novo membro aparece na lista do sidebar automaticamente (sem refresh).
- [ ] **T-56:** Remover um membro via WhatsApp. Verificar que desaparece da lista automaticamente.
- [ ] **T-57:** Alterar o nome do grupo via WhatsApp. Verificar que atualiza no painel lateral automaticamente.

### 13. Regressão — Conversas Individuais

- [ ] **T-58:** Abrir uma conversa individual. Verificar que `ContactInfo` aparece normalmente (avatar, nome, email, telefone, ações).
- [ ] **T-59:** Verificar que todas as seções do sidebar (actions, participants, info, attributes, previous conversations, notes, macros) funcionam normalmente.
- [ ] **T-60:** Criar uma nova conversa individual. Verificar que nenhum elemento de grupo aparece.
- [ ] **T-61:** Verificar que o filtro básico com "All" mostra tanto individuais quanto grupos corretamente.
