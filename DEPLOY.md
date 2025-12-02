# 🚀 Deploy do Chatwoot JAIFI CRM na VPS com Portainer

## Requisitos
- VPS com Docker e Portainer instalados
- Domínio configurado (ex: crm.seudominio.com.br)
- Certificado SSL (Let's Encrypt ou similar)

## 📋 Passo a Passo no Portainer

### 1. Criar Stack no Portainer

Acesse Portainer → Stacks → Add Stack

### 2. Configurar Repository

**Build method**: Repository

**Git repository**:
- **Repository URL**: `https://github.com/Filipe-Pires4/chatwoot--jaifi-crm.git`
- **Repository reference**: `refs/heads/claude/study-functionality-01JqNXiJXtmApRr6CPx4jDQJ`
- **Compose path**: `docker-compose.production.yaml` ⬅️ **IMPORTANTE!**

### 3. Adicionar Environment Variables

⚠️ **IMPORTANTE**: Substitua TODOS os valores `MUDE_ISSO_*` pelas suas configurações reais!

Clique em "Add an environment variable" e adicione:

```bash
# SEGURANÇA (OBRIGATÓRIO)
SECRET_KEY_BASE=MUDE_ISSO_USE_openssl_rand_hex_64

# URL (OBRIGATÓRIO)
FRONTEND_URL=https://crm.seudominio.com.br

# DATABASE
POSTGRES_HOST=postgres
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=MUDE_ISSO_senha_postgres_forte
POSTGRES_DATABASE=chatwoot_production

# REDIS
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=MUDE_ISSO_senha_redis_forte

# AMBIENTE
RAILS_ENV=production
NODE_ENV=production
RAILS_MAX_THREADS=5

# EMAIL (Configure com seu SMTP)
MAILER_SENDER_EMAIL=JAIFI CRM <noreply@seudominio.com.br>
SMTP_ADDRESS=smtp.seudominio.com.br
SMTP_PORT=587
SMTP_USERNAME=noreply@seudominio.com.br
SMTP_PASSWORD=MUDE_ISSO_senha_email
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true

# SEGURANÇA
ENABLE_ACCOUNT_SIGNUP=false
FORCE_SSL=true

# STORAGE
ACTIVE_STORAGE_SERVICE=local
```

### 4. Gerar SECRET_KEY_BASE

Execute no seu terminal/VPS:
```bash
openssl rand -hex 64
```

Copie o resultado e cole na variável `SECRET_KEY_BASE`

### 5. Deploy

1. Clique em "Deploy the stack"
2. Aguarde o download das imagens e inicialização dos containers
3. Verifique os logs: Portainer → Stacks → seu-stack → Logs

### 6. Executar Migrações do Banco (Primeira vez)

No terminal da VPS ou no console do container `rails`:

```bash
# Via Portainer Console (container rails)
bundle exec rails db:chatwoot_prepare

# Ou via docker exec
docker exec -it <rails_container_id> bundle exec rails db:chatwoot_prepare
```

### 7. Criar Usuário Admin

```bash
# Via Portainer Console (container rails)
bundle exec rails db:seed

# Ou criar manualmente
bundle exec rails c
# No console Rails:
user = User.create!(
  email: 'admin@seudominio.com.br',
  name: 'Admin',
  password: 'SuaSenhaForte123!',
  password_confirmation: 'SuaSenhaForte123!'
)
account = Account.create!(name: 'Sua Empresa')
AccountUser.create!(account: account, user: user, role: :administrator)
```

### 8. Configurar Nginx/Caddy (Reverse Proxy)

Configure seu reverse proxy para apontar para `localhost:3000`

**Exemplo Nginx**:
```nginx
server {
    server_name crm.seudominio.com.br;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # SSL configurado via certbot
}
```

## 🎯 Funcionalidades Customizadas

### Kanban de Leads
Acesse pelo menu lateral: **Kanban**

**Campos personalizados** (configurar em Settings → Custom Attributes):
- `status_lead`: novo_lead, aquecimento, qualificado, convertido/agendado, perdido
- `temperatura`: quente, morno, frio
- `lead_score`: 0-100
- `servico_interesse`: texto
- `dores_identificadas`: texto
- `objecoes`: texto
- `status_conversao`: convertido ou agendado (configurável por conta)

### Configurar Status de Conversão

Para mudar o status de conversão (ex: de "convertido" para "agendado"):

1. Settings → Account Settings
2. Custom Attributes (no Account)
3. Adicionar atributo:
   - Key: `status_conversao`
   - Value: `agendado` (ou `convertido`, `vendido`)

## 🔧 Manutenção

### Ver Logs
```bash
# Portainer → Containers → rails/sidekiq → Logs
# Ou via docker
docker logs -f <container_id>
```

### Restart dos Serviços
```bash
docker-compose -f docker-compose.production.yaml restart
```

### Backup do Banco
```bash
docker exec <postgres_container> pg_dump -U postgres chatwoot_production > backup.sql
```

### Atualizar Código
```bash
# No Portainer: Stack → Pull and redeploy
# Ou via terminal:
git pull origin claude/study-functionality-01JqNXiJXtmApRr6CPx4jDQJ
docker-compose -f docker-compose.production.yaml up -d --build
```

## 🔌 Integrações Futuras

### Evolution API (WhatsApp)
Configure via Custom Attributes no Inbox ou Account

### N8N
Configure webhooks via Custom Attributes

### Gemini AI
Configure API key via variável de ambiente ou Custom Attributes

---

## 📞 Suporte

Para issues: https://github.com/Filipe-Pires4/chatwoot--jaifi-crm/issues
