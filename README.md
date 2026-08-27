# Charles Miller · App do Condomínio

PWA de gestão do Condomínio Residencial Charles Miller, com quatro perfis de
acesso: Morador, Portaria, Administrativo e Síndico.

Protótipo single-file — todo o app vive em `index.html` (HTML + CSS + JS inline),
com dados mockados e sem backend.

## Estrutura

| Arquivo | Função |
|---|---|
| `index.html` | App completo (UI, estilos, lógica, dados mock) |
| `manifest.json` | Manifesto PWA |
| `service-worker.js` | Cache offline (stale-while-revalidate) |
| `icon-192.png` / `icon-512.png` / `icon-512-maskable.png` | Ícones do app |
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
