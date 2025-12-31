# EagleTalks Whitelabel (fazer-ai/chatwoot)

Este repositório é um fork do `fazer-ai/chatwoot` e contém alterações para whitelabel do produto EagleTalks.

## Objetivo
- Remover todas as menções visuais e links públicos de "Chatwoot"
- Remover rodapés ("Powered by"), links de Docs/Help/Community/GitHub
- Ajustar templates de e-mail (layout, assinatura, links, remetente)
- Manter upgrades previsíveis (patches pequenos, bem documentados)

## Regras
- `main` = produção
- `develop` = homologação
- Alterações entram via Pull Request
- Nunca usar imagens `:latest` em produção
- Não tocar em código de `/enterprise` (exige licença)

## Checklist de validação (alto nível)
- UI (Dashboard): sem "Chatwoot", sem links externos, sem "Powered by"
- Widget: sem "Chatwoot", sem "Powered by"
- Emails: remetente correto, logo correto, links apontando para FRONTEND_URL
- Integração WhatsApp (Baileys): recebimento/envio e mídias OK
