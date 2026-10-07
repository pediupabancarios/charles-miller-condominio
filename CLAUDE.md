# Charles Miller — App do Condomínio

## O que é
PWA de gestão do Condomínio Residencial Charles Miller.
Quatro perfis de acesso: **Morador**, **Portaria**, **Administrativo** e **Síndico**.
Estado atual: **protótipo** — dados mockados no próprio `index.html`, sem backend.

## Backend (Supabase)
- **Projeto:** `ohuaoncwgioawgptyqgz` (prontuario-neonatal-candida-vargas), tabelas com prefixo `cm_`
- **Schema:** `supabase/schema.sql` — idempotente, replicar aqui qualquer migration aplicada
- **Chave no app:** publishable (`sb_publishable_…`), embutida no `index.html` — é pública por design
- **17 tabelas:** cm_config, cm_perfil, cm_moradores, cm_reservas, cm_boletos, cm_boletos_mes,
  cm_avisos, cm_ocorrencias, cm_encomendas, cm_sugestoes, cm_visitantes, cm_autorizacoes,
  cm_veiculos, cm_assembleias, cm_documentos, cm_manutencoes, cm_conversas

### Como a persistência funciona
Os arrays globais continuam sendo a fonte da UI — **os renderers não mudaram**.
`boot()` carrega tudo do banco antes do primeiro render; cada mutação grava e só
então re-renderiza. Se o banco não responder, o app entra em **modo demonstração**
(faixa no rodapé) e segue navegável, sem salvar nada.

- `dbInserir/dbAtualizar/dbRemover(colecao, …)` — `TABELAS{}` liga coleção → tabela
- `dbSalvarConfig(chave)` / `dbSalvarPerfil()` — upsert em `cm_config` / `cm_perfil`
- `paraJS()`/`paraDB()` convertem snake_case ↔ camelCase **só no primeiro nível**:
  o conteúdo de jsonb (`pauta`, `mensagens`, `usos`, `notificacoes`) precisa chegar
  intacto, senão `meuVoto` viraria `meu_voto`
- Colunas `numeric` voltam como string do PostgREST — `carregarTudo()` converte
  `boletos.val`, `boletosDoMes.val` e `manutencoes.custo` para número
- Toda função que persiste é `async` e dá `await` antes de `goView`/`goAdmin`
- `id` vem do banco e é o mesmo usado pela lógica (assembleias, conversas, autorizações)

### Autenticação (Supabase Auth)
- `cm_usuarios` liga cada conta a **papel** (`morador`/`porteiro`/`administrativo`/`sindico`)
  e **unidade**. Conta sem vínculo, ou `ativo=false`, não enxerga nada.
- **A primeira conta criada vira síndico ativo** (bootstrap em `cm_registrar()`);
  as demais entram pendentes até o síndico liberar em **Contas de acesso**.
- **Liberar em lote:** `liberarPendentes()` ativa de uma vez os moradores pendentes
  cuja unidade existe (`contasLiberaveis()`). Quem está sem unidade ou com unidade
  inexistente fica de fora e é listado pelo nome — liberar sem unidade deixaria a
  conta sem enxergar nada, porque a RLS não teria em que se apoiar.
- A constraint do banco exige unidade só para morador **ativo**
  (`cm_usuarios_morador_ativo_tem_unidade`): antes exigia de todo morador, e quem
  se cadastrasse sem informá-la tinha o registro recusado, ficando sem conta.
- O projeto está com **"Confirm email" ligado** no Supabase: o `signUp` não abre
  sessão, então o registro só acontece no primeiro login. Por isso nome e unidade
  vão no `options.data` do `signUp` (user_metadata) e `cm_registrar()` os recupera
  de lá — sem isso, o cadastro chegaria sem unidade.
- O antigo seletor de perfil no topo **não existe mais** — o papel vem da conta.
  `setRole()` força o papel do usuário e ignora qualquer outro valor.
- `morador.cod` vem de `USUARIO.unidade`, não está mais fixo no código.
- A RLS repete as regras no servidor: a checagem de interface
  (`podeVerInadimplencia()`, `temModulo()`) é conveniência, não proteção.
- Dados fictícios **não estão mais no JavaScript** — se o banco falhar, o app
  aparece vazio em vez de mostrar dados falsos como se fossem reais.

### Recuperação de senha
`formEsqueci()` → `sb.auth.resetPasswordForEmail(email, {redirectTo})` aponta de volta
para a própria página. Ao voltar pelo link, `boot()` detecta `type=recovery` na URL
(e escuta o evento `PASSWORD_RECOVERY`) e abre `formNovaSenha()` **antes** de entrar
no app — a sessão existe, mas o destino é trocar a senha.
⚠️ A URL do app precisa estar em **Authentication → URL Configuration** no Supabase,
senão o link do e-mail não volta para cá.

### Relatórios
`serieFinanceira`, `despesasPorCategoria` e `inadimplentes` **não são mais arrays
fixos no código** — `carregarRelatorios()` os traz de `cm_financeiro_mensal`,
`cm_despesas_categoria` e `cm_boletos_mes` (status "Em atraso", com `meses_atraso`).
Só é chamada para síndico e administrativo; a RLS recusa para os demais.
`cashChart()` do dashboard usa a mesma série — antes tinha números próprios
inventados, diferentes dos da tela de Relatórios.
Sem dados, as telas mostram aviso em vez de quebrar (`Math.max` de array vazio
devolve `-Infinity`).

### Limitações conhecidas desta etapa
- O mascaramento da inadimplência para o administrativo é de interface: a RLS deixa
  ele ler `cm_boletos_mes` inteiro. Para valer no servidor, seria uma view sem os nomes.
- `vagas` continua gerado proceduralmente (não há tela para remanejar vaga)
- `eventos`, `calendarEvents`, `serieFinanceira`, `despesasPorCategoria` e
  `inadimplentes` seguem fixos no código — são read-only, não há UI que os altere
- Votos de assembleia vivem no `jsonb` da pauta: dois votos simultâneos podem se
  sobrescrever. O certo é uma tabela `cm_votos (pauta_id, unidade, voto)`, que também
  resolveria auditoria e bloqueio de unidade inadimplente
- `ic`/`cor`/`tag_class` estão no banco por pragmatismo (evitou reescrever os
  renderers). São apresentação e deveriam derivar da categoria, como já acontece
  em `tiposAviso`

## Stack
- **Single file:** `index.html` (HTML + CSS + JS inline, sem build, sem dependências)
- **PWA:** `manifest.json` + `service-worker.js` (cache offline stale-while-revalidate)
- **Ícones:** `icon-192.png`, `icon-512.png`, `icon-512-maskable.png`
- **Fontes:** Google Fonts — Fraunces (títulos), Inter (texto), IBM Plex Mono (números)
- **Backend:** Supabase (ver seção acima) via `@supabase/supabase-js` por CDN

## Tema visual
Paleta **Ardósia e verde-água** (as variáveis mantiveram os nomes `--navy-*` e
`--gold-*` de quando o tema era marinho e dourado; o nome é histórico, a cor não).
- **Escuros:** `--navy-950 #1f2933` → `--navy-800 #32414f`
- **Acento:** `--gold-500 #2a9d8f` (verde-água) · `--gold-400 #4bbdaf` · `--gold-100 #d9f0ec`
- **Links e gradientes:** `--navy-700 #1c6b61`
- **Fundo:** `--paper #f4f6f7` | Cards: `--card #ffffff` | Linhas: `--line #e2e6e9`
- **Texto:** `--ink #1c1c1c` | `--ink-soft #5c5f66`
- **Status (independem da paleta):** verde `--green`, vermelho `--red`,
  âmbar `--amber`, azul `--blue`, cada um com `-bg`
- **Badges:** `.b-green` `.b-blue` `.b-red` `.b-amber` `.b-navy`

Trocar de paleta é trocar os hex no `:root` — mas confira se o novo acento não
fica perto demais do `--green` de status, que aparece lado a lado nos badges.
O `theme-color` do HTML e o `manifest.json` carregam a cor escura: mudam junto.


## Arquitetura JS (tudo em `index.html`, tag `<script>` única)
- **Dados mock** no topo: `morador`, `eventos`, `reservas`, `boletos`, `avisos`,
  `ocorrencias`, `encomendas`, `sugestoes`, `moradoresLista`, `visitantes`, `calendarEvents`,
  `assembleias`, `documentos`, `manutencoes`, `serieFinanceira`, `despesasPorCategoria`,
  `inadimplentes`, `config`, `autorizacoes`, `vagas`, `veiculos`, `boletosDoMes`, `conversas`
- **App do Morador** (mobile, `#residentApp`):
  - `renderHome/Reservas/Financeiro/Avisos/Ocorrencias/Sugestoes/Encomendas/Hub()` — retornam string HTML
  - `renderAssembleiasMorador()` — pauta + votação (`votar()`); `renderDocumentosMorador()` — biblioteca
  - `renderVeiculosMorador()` — própria vaga e veículos
  - `renderAutorizacoesMorador()` — pré-autoriza visitantes e acompanha os códigos
  - `renderFaleMorador()` — threads com o síndico; `renderConfigMorador()` — perfil e preferências
  - `ocultarFab(bool)` — o FAB cobre os botões de qualquer formulário aberto; todo
    `toggle*Form` do morador precisa chamá-lo
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
  - `painelAutorizacoes()` — embutido em `renderAdminVisitantes()`: busca por código/nome/
    unidade e `liberarEntrada()`, que registra o uso e cria a entrada em `visitantes`
  - `renderAdminMensagens()` — caixa de entrada do "Fale com o síndico"
  - `podeVerInadimplencia()` / `painelRestrito()` — ver **Privacidade** abaixo
  - `renderAdminAssembleias/AdminDocumentos/AdminManutencoes/AdminRelatorios/AdminConfiguracoes()`
  - `temModulo(v)` — o módulo existe no menu do perfil atual? (`goAdmin` bloqueia o que não existe)
- **Troca de perfil:** `#roleSwitch` no topo → `setRole('resident'|'porteiro'|'administrativo'|'sindico')`
- **Helpers:** `kpi()`, `shortcut()`, `actionCard()`, `quick()`, `calendar()`, `cashChart()`,
  `donut()`, `toast(msg)`, `sw()` (switch), `fmtBRL()`, `fmtData()`, `diasAte()`, `somaISO()`
- **PWA:** registro do SW + `beforeinstallprompt` → `showInstallBanner()` / `hideInstallBanner()`

## Estado dos dados
O banco foi **zerado dos dados de demonstração** em 07/10/2026. Continuam lá:
- a conta de síndico do Rodrigo
- as 7 áreas comuns reais (Salão de Festas, Salão Gourmet, Churrasqueira 1,
  Garagem Band, Home Cinema, Sauna, Spa) e as preferências de notificação
- a estrutura do prédio, **confirmada pelo condomínio**: 2 torres (A e B),
  26 andares, 2 apartamentos por andar = 104 unidades, numeradas
  `101-A`, `102-A` … `2602-B`

Zerados: moradores, boletos, avisos, ocorrências, encomendas, visitantes,
veículos, assembleias, votos, documentos, manutenções, conversas e relatórios.
Também o CNPJ, o endereço e as taxas, que eram inventados.

Cópia dos dados antigos em `supabase/backup-demonstracao.json` (ver
`restaurar-demonstracao.sql`), caso seja preciso apresentar o app cheio.

## Privacidade — encomendas e ocorrências
Ambas ganharam coluna `unidade`, que é o que a RLS usa:
- **Encomenda** é da unidade: o morador vê só as dele. Antes a unidade vivia
  embutida no texto da data (`"Recebida em … · 1201-A"`), a RLS não tinha em que
  se apoiar e **todo morador lia as encomendas de todos**.
- **Ocorrência** com `unidade = null` é área comum e todos leem; com unidade
  preenchida fica restrita a ela e à gestão. O formulário do morador pergunta
  "na minha unidade" ou "em área comum".
- A aba **Minhas** de ocorrências filtra por `o.unidade === morador.cod`, não
  mais por um campo `cat` fixo que não tinha relação com quem abriu.

## Números do dashboard e do financeiro
`resumoDoMes()` calcula receita, despesa, saldo e variação a partir de
`serieFinanceira`; `kpiValor()` mostra **—** e "sem dados registrados" quando o
valor é nulo. Antes os KPIs eram texto fixo (`"R$ 138.240,00"`), então com o
banco zerado o app exibia uma receita que não existia.

`papelEfetivo()` é a fonte do papel: a conta autenticada (`papelAtual()`), com
`currentStaffRole` só como reserva enquanto não há sessão. `temModulo()`,
`podeVerInadimplencia()` e `goAdmin()` usam essa função — manter duas fontes
para a mesma verdade fazia a permissão depender de qual delas fosse consultada.

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

## Visitantes autorizados
O morador pré-autoriza; a portaria confere o código e libera sem ligar para ele.
- Três tipos: `unica` (campo `data`), `periodo` (`de`/`ate`), `recorrente` (`de`/`ate` + `dias`,
  índices 0–6 de `diasSemana`). `autorizadaEm(a,iso)` é a única fonte da regra de validade.
- `statusAutorizacao()` deriva tudo da data + usos: Cancelada → Utilizada (só `unica`) →
  Expirada → Válida hoje → Agendada. **Não** guarde status no registro.
- Código `CM-XXXX` gerado por `novoCodigoAutorizacao()`, sem `I`, `O`, `0` e `1` para não
  confundir na leitura da portaria — mantenha isso ao criar códigos de exemplo.
- `liberarEntrada()` registra o uso **e** cria o visitante em `visitantes` com
  `autorizado:true`, que vira o badge "Pré-autorizado" na tabela de entradas.
- `CTX_AUTORIZACAO` diz de qual tela o cancelamento partiu (morador ou portaria).

## Fale com o síndico
Uma thread por assunto, compartilhada entre o morador e o síndico.
- `statusConversa()` deriva de quem mandou a **última** mensagem: Encerrada →
  Respondida → Aguardando resposta. Nada de status gravado no registro.
- `conversaAberta` (id) alterna entre lista e thread nos **dois** lados;
  `CTX_CONVERSA` diz de qual lado veio a ação. Sempre zere `conversaAberta`
  ao entrar por outro caminho, senão a tela abre direto numa thread antiga.
- Não lidas por `naoLidas(c, "morador"|"sindico")`, marcadas ao abrir a thread.
- Conversa encerrada some com a caixa de resposta do morador; o síndico reabre.

## Configurações do morador
- `morador` guarda perfil (`nomeCompleto`, `email`, `telefone`), `notificacoes`
  pessoais e `mostrarNaLista`.
- **O nome vive em dois lugares** (`morador` e `moradoresLista`, ligados por
  `unidade === morador.cod`): `salvarPerfil()` propaga para a lista do síndico
  e para `conversas`. Qualquer novo lugar que copie o nome precisa entrar ali.
- Notificação pessoal só aparece se o síndico não desligou a categoria em
  `config.notificacoes` — desligada globalmente, vira badge "Indisponível".
- `mostrarNaLista` desligado marca "Nome oculto" na tabela de Moradores
  (`ocultoNaLista()`), sinalizando a preferência a ser honrada por qualquer
  lista de moradores voltada a moradores.

## Unidades e vagas
- Código: `codUnidade(andar,apto,torre)` → `802-A`, `1401-B` — **sem zero à esquerda no andar**
- `todasUnidades()` gera as 104; `UNIDADES_DESOCUPADAS` lista as 3 sem morador
- `vagas`: 1 privativa por unidade (`A-01`…`A-52` Subsolo 1, `B-01`…`B-52` Subsolo 2)
  + 6 de visitante no pátio. Vaga de unidade desocupada fica livre.
- Placa aceita Mercosul (`ABC1D23`) e antiga (`ABC1234`) — `placaValida()` / `formataPlaca()`
- Limite de `MAX_VEICULOS_UNIDADE` (3) veículos por unidade

## Perfis e permissões (protótipo — sem auth real)
- **Morador:** própria unidade — financeiro, reservas, avisos, ocorrências, sugestões,
  encomendas, assembleias (voto), documentos, veículos, visitantes autorizados,
  fale com o síndico, configurações
- **Portaria:** moradores, reservas, encomendas, visitantes, veículos e vagas
- **Administrativo:** tudo do síndico exceto assembleias / manutenções / configurações,
  **e sem os dados de inadimplência** (ver Privacidade)
- **Síndico:** acesso total

## Regras de negócio / dados do prédio
- 2 torres (A e B), 26 andares, 2 apts por andar → **104 unidades** (ver Unidades e vagas)
- Áreas comuns reserváveis: vêm de `config.areas` (só as `ativa`). `addReserva()` valida
  data no passado, antecedência mínima da área e conflito de mesma área/data.
  Ícone por `iconeArea()`, com padrão para áreas novas.
- Status de reserva: Pendente → Confirmada
- Status de sugestão: Em análise → Aprovada / Recusada → Implementada
- Status de encomenda: Em armazenamento → Entregue
- Status de ocorrência: Aberta → Em execução → Resolvida
- Boletos: Condomínio mensal + Fundo de Obras
- **Assembleias:** status Agendada → Votação aberta → Encerrada. Voto por **pauta**,
  1 voto por unidade (`TOTAL_UNIDADES = 104`), quórum = maioria simples das unidades.
  O morador pode trocar o voto enquanto a votação estiver aberta.
  - O voto vive em **`cm_votos`** (uma linha por unidade, `unique(pauta_id, unidade)`),
    não mais em contadores no jsonb. `votar()` faz upsert — trocar o voto substitui a
    linha em vez de somar outra — e a RLS impede votar em nome de outra unidade.
  - `aplicarVotos()` projeta `cm_votos` nos campos `sim/nao/abst/meuVoto` que as telas
    já liam, então os renderizadores não mudaram. **O jsonb da pauta guarda só
    `id`, `titulo` e `desc`** — se voltar a gravar contagem ali, haverá duas fontes.
- **Avisos:** categoria (`urgentes` / `comunicados` / `manutencoes`) define ícone, cor e
  badge via `tiposAviso` — **não** duplique esses campos no registro. Aviso `fixado`
  sobe ao topo em todas as listas (`avisosOrdenados()`). Publicação respeita o toggle
  de notificações em `config.notificacoes`.
- **Manutenções:** status derivado da data (`Atrasada` < hoje, `Vence em Nd` ≤ 15 dias,
  senão `Em dia`). Registrar execução recalcula a próxima pela periodicidade.

## Service worker
`CACHE_NAME` é a versão — **subir a cada alteração no app**, senão o navegador
continua servindo a anterior.

Duas estratégias, de propósito:
- **index.html e navegação: rede primeiro**, caindo no cache só sem conexão.
  O app é um arquivo único, então servir o HTML do cache servia a versão
  inteira anterior — chegou a aparecer uma tela com o gráfico novo e os KPIs
  antigos ao mesmo tempo.
- **Ícones e manifesto: cache primeiro** com revalidação. Mudam pouco.
- **Outras origens passam direto**: cachear as respostas do Supabase devolveria
  dados desatualizados.

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

O hub do morador não tem mais placeholders. O morador **solicita reserva**
(`addReservaMorador`, nasce Pendente para a portaria confirmar) e **abre
ocorrência** (`addOcorrenciaMorador`). Ainda mostram só um toast: no financeiro —
Pix, 2ª via, histórico e os botões de pagamento.

Sidebar do síndico: 17 módulos · administrativo: 14 · portaria: 6.
Views do morador: 14.

## Próximos passos
1. ~~Autenticação real~~ e ~~RLS por unidade~~ — **feitos**
2. Trocar os dados de demonstração por dados reais do condomínio
3. Upload real de documentos (hoje o `<input type=file>` só lê o tamanho)
4. Envio real das notificações (Web Push) — hoje os toggles só controlam textos
5. QR code para a autorização (hoje o visitante apresenta o código digitado)
6. Lista de moradores visível ao morador, honrando `mostrarNaLista`
