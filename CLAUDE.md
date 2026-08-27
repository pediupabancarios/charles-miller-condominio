# Charles Miller — App do Condomínio

## O que é
PWA de gestão do Condomínio Residencial Charles Miller.
Quatro perfis de acesso: **Morador**, **Portaria**, **Administrativo** e **Síndico**.
Estado atual: **protótipo** — dados mockados no próprio `index.html`, sem backend.

## Stack
- **Single file:** `index.html` (HTML + CSS + JS inline, sem build, sem dependências)
- **PWA:** `manifest.json` + `service-worker.js` (cache offline stale-while-revalidate)
- **Ícones:** `icon-192.png`, `icon-512.png`, `icon-512-maskable.png`
- **Fontes:** Google Fonts — Fraunces (títulos), Inter (texto), IBM Plex Mono (números)
- **Backend:** nenhum ainda. Migração futura provável: Supabase (mesmo padrão do app MedEscala)

## Tema visual
- **Acento:** dourado `--gold-500 #c79a3d`
- **Escuro/marinho:** `--navy-950 #0e1b33` → `--navy-700 #28417a`
- **Fundo:** `--paper #f4f2ec` | Cards: `--card #ffffff`
- **Texto:** `--ink #1c1c1c` | `--ink-soft #5c5f66`
- **Status:** verde `--green`, vermelho `--red`, âmbar `--amber`, azul `--blue` (cada um com `-bg`)
- **Badges:** `.b-green` `.b-blue` `.b-red` `.b-amber` `.b-navy`

## Arquitetura JS (tudo em `index.html`, tag `<script>` única)
- **Dados mock** no topo: `morador`, `eventos`, `reservas`, `boletos`, `avisos`,
  `ocorrencias`, `encomendas`, `sugestoes`, `moradoresLista`, `visitantes`, `calendarEvents`,
  `assembleias`, `documentos`, `manutencoes`, `serieFinanceira`, `despesasPorCategoria`,
  `inadimplentes`, `config`
- **App do Morador** (mobile, `#residentApp`):
  - `renderHome/Reservas/Financeiro/Avisos/Ocorrencias/Sugestoes/Encomendas/Hub()` — retornam string HTML
  - `renderAssembleiasMorador()` — pauta + votação (`votar()`); `renderDocumentosMorador()` — biblioteca
  - `viewMap{}` — mapeia nome da view → função render
  - `goView(v)` — troca a view em `#residentViews`, atualiza a bottom nav
  - `switchTab()`, `filterList()`, `filterEnc()` — abas e filtros dentro das views
- **Apps de Staff** (desktop c/ sidebar, `#staffApp`) — Síndico / Administrativo / Portaria:
  - `staffRoles{}` — config de cada perfil (itens do menu, nome, avatar)
  - `sbItemsSindico / sbItemsAdministrativo / sbItemsPorteiro` — itens da sidebar
  - `rendererMap{}` → `adminRenderers / administrativoRenderers / porteiroRenderers`
  - `goAdmin(v)` — troca a view em `#adminMain`, reconstrói sidebar + abas mobile
  - `buildSidebar()`, `mobileTabs()`, `adminStub(v)` — módulos não implementados caem no stub
  - `renderDashboard/AdminFinanceiro/AdminMoradores/AdminReservas/AdminOcorrencias/`
    `AdminSugestoes/AdminEncomendas/AdminVisitantes/AdminUnidades/PorteiroDashboard()`
  - `renderAdminAvisos()` — publicar/editar/fixar/remover aviso (síndico e administrativo)
  - `renderAdminVeiculos()` — cadastro de veículos + mapa de vagas (também na portaria)
  - `podeVerInadimplencia()` / `painelRestrito()` — ver **Privacidade** abaixo
  - `renderAdminAssembleias/AdminDocumentos/AdminManutencoes/AdminRelatorios/AdminConfiguracoes()`
  - `temModulo(v)` — o módulo existe no menu do perfil atual? (`goAdmin` bloqueia o que não existe)
- **Troca de perfil:** `#roleSwitch` no topo → `setRole('resident'|'porteiro'|'administrativo'|'sindico')`
- **Helpers:** `kpi()`, `shortcut()`, `actionCard()`, `quick()`, `calendar()`, `cashChart()`,
  `donut()`, `toast(msg)`, `sw()` (switch), `fmtBRL()`, `fmtData()`, `diasAte()`, `somaISO()`
- **PWA:** registro do SW + `beforeinstallprompt` → `showInstallBanner()` / `hideInstallBanner()`

## Privacidade — inadimplência
Quem deve em qual unidade é dado pessoal. A regra está em `podeVerInadimplencia()`
(hoje: apenas `sindico`) e é aplicada em **três** telas — mexeu numa, confira as outras:

| Tela | Síndico | Administrativo | Morador |
|---|---|---|---|
| Dashboard (KPI) | Inadimplência R$ | Saldo em caixa | — |
| Financeiro (boletos do mês) | unidade + nome | linha em atraso mascarada (`•••`) | só a própria unidade |
| Relatórios | KPI, evolução e lista nominal | Arrecadação média + resultado mensal; lista bloqueada | — |

A portaria não tem Financeiro nem Relatórios. **Ao adicionar qualquer tela nova com
dado financeiro por unidade, passe por `podeVerInadimplencia()`.** Em produção isso
tem de virar RLS no Postgres — a checagem no cliente não protege nada sozinha.

## Unidades e vagas
- Código: `codUnidade(andar,apto,torre)` → `802-A`, `1401-B` — **sem zero à esquerda no andar**
- `todasUnidades()` gera as 104; `UNIDADES_DESOCUPADAS` lista as 3 sem morador
- `vagas`: 1 privativa por unidade (`A-01`…`A-52` Subsolo 1, `B-01`…`B-52` Subsolo 2)
  + 6 de visitante no pátio. Vaga de unidade desocupada fica livre.
- Placa aceita Mercosul (`ABC1D23`) e antiga (`ABC1234`) — `placaValida()` / `formataPlaca()`
- Limite de `MAX_VEICULOS_UNIDADE` (3) veículos por unidade

## Perfis e permissões (protótipo — sem auth real)
- **Morador:** própria unidade — financeiro, reservas, avisos, ocorrências, sugestões,
  encomendas, assembleias (voto), documentos, veículos
- **Portaria:** moradores, reservas, encomendas, visitantes, veículos e vagas
- **Administrativo:** tudo do síndico exceto assembleias / manutenções / configurações,
  **e sem os dados de inadimplência** (ver Privacidade)
- **Síndico:** acesso total

## Regras de negócio / dados do prédio
- 2 torres (A e B), 26 andares, 2 apts por andar → **104 unidades** (ver Unidades e vagas)
- Áreas comuns reserváveis: Salão de Festas, Churrasqueira 1/2, Quadra Poliesportiva
- Status de reserva: Pendente → Confirmada
- Status de sugestão: Em análise → Aprovada / Recusada → Implementada
- Status de encomenda: Em armazenamento → Entregue
- Status de ocorrência: Aberta → Em execução → Resolvida
- Boletos: Condomínio mensal + Fundo de Obras
- **Assembleias:** status Agendada → Votação aberta → Encerrada. Voto por **pauta**,
  1 voto por unidade (`TOTAL_UNIDADES = 104`), quórum = maioria simples das unidades.
  O morador pode trocar o voto enquanto a votação estiver aberta.
- **Avisos:** categoria (`urgentes` / `comunicados` / `manutencoes`) define ícone, cor e
  badge via `tiposAviso` — **não** duplique esses campos no registro. Aviso `fixado`
  sobe ao topo em todas as listas (`avisosOrdenados()`). Publicação respeita o toggle
  de notificações em `config.notificacoes`.
- **Manutenções:** status derivado da data (`Atrasada` < hoje, `Vence em Nd` ≤ 15 dias,
  senão `Em dia`). Registrar execução recalcula a próxima pela periodicidade.

## Como editar
Toda a UI é gerada por funções JS que montam HTML como template string e
injetam em `innerHTML` (`#residentViews` ou `#adminMain`). Para adicionar uma
tela: criar `renderX()`, registrar em `viewMap` / `rendererMap`, adicionar o
item de navegação correspondente.

Ao mexer nos assets em cache, subir a versão em `service-worker.js` (`CACHE_NAME`).

## Rodar localmente
Servir a pasta por HTTP (o SW não funciona em `file://`):

```bash
python3 -m http.server 8000
```

Depois abrir http://localhost:8000

## Estado dos módulos
Todos os módulos do menu de cada perfil estão implementados — `adminStub()` continua
no código apenas como rede de segurança para views não registradas.

Ainda são placeholder (mostram só um toast): no hub do morador — Visitantes,
Fale com o síndico, Configurações; e no financeiro — Pix, 2ª via, histórico
e os botões de pagamento.

Sidebar do síndico: 16 módulos · administrativo: 13 · portaria: 6.

## Próximos passos
1. **Autenticação real** — hoje o seletor de perfil no topo troca de papel sem login
2. **Backend (Supabase)** — todo o estado vive em memória e some ao recarregar
3. **Cadastro de visitante autorizado** pelo morador (pré-autorização / QR)
4. Upload real de documentos (hoje o `<input type=file>` só lê o tamanho)
5. Envio real das notificações (Web Push) — hoje o toggle só controla o texto do toast
