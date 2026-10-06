# Charles Miller · App do Condomínio

PWA de gestão do Condomínio Residencial Charles Miller, com quatro perfis de
acesso: Morador, Portaria, Administrativo e Síndico.

App single-file: tudo vive em `index.html` (HTML + CSS + JS inline, sem build).
Os dados ficam no **Supabase** (17 tabelas com prefixo `cm_`); se o banco não
responder, o app entra em modo demonstração e avisa no rodapé.

> ⚠️ **Ainda não há autenticação.** O seletor de perfil no topo troca de papel sem
> senha, e a política de acesso do banco está aberta. Os dados publicados são
> fictícios — não cadastre morador, boleto ou CPF reais antes do login estar pronto.

## Estrutura

| Arquivo | Função |
|---|---|
| `index.html` | App completo (UI, estilos, lógica, dados mock) |
| `manifest.json` | Manifesto PWA |
| `service-worker.js` | Cache offline (stale-while-revalidate) |
| `icon-192.png` / `icon-512.png` / `icon-512-maskable.png` | Ícones do app |
| `supabase/schema.sql` | Schema do banco (idempotente) |
| `CLAUDE.md` | Documentação da arquitetura para o Claude Code |

## Rodar localmente

O service worker exige HTTP (não funciona via `file://`):

```bash
python3 -m http.server 8000
```

Abrir http://localhost:8000

## Perfis

Alternados pelo seletor no topo (`#roleSwitch`):

- **Morador** — app mobile: financeiro, reservas, avisos, ocorrências, sugestões, encomendas
- **Portaria** — painel: moradores, reservas, encomendas, visitantes
- **Administrativo** — painel administrativo do condomínio
- **Síndico** — acesso total: dashboard, financeiro, unidades, relatórios, configurações
