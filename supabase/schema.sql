-- ============================================================
-- Condomínio Charles Miller — schema (prefixo cm_)
-- Idempotente: pode rodar várias vezes sem quebrar nada.
-- ============================================================

-- Configuração do condomínio (singleton key/value)
create table if not exists cm_config (
  chave text primary key,
  valor jsonb not null,
  atualizado_em timestamptz not null default now()
);

-- Perfil do morador logado (um registro por unidade)
create table if not exists cm_perfil (
  cod text primary key,                 -- 802-A
  nome text not null,
  nome_completo text not null,
  unidade text not null,
  papel text,
  email text,
  telefone text,
  notificacoes jsonb not null default '{}'::jsonb,
  mostrar_na_lista boolean not null default true
);

create table if not exists cm_moradores (
  id bigint generated always as identity primary key,
  nome text not null,
  unidade text not null,
  papel text,
  criado_em timestamptz not null default now()
);

create table if not exists cm_reservas (
  id bigint generated always as identity primary key,
  titulo text not null,                 -- área comum
  morador text,                         -- código da unidade
  data text not null,                   -- "05/09/2026 · 18:00 às 23:00"
  num text,
  tag text not null default 'Pendente',
  tag_class text not null default 'b-amber',
  ic text, cor text,
  criado_em timestamptz not null default now()
);

create table if not exists cm_boletos (
  id bigint generated always as identity primary key,
  unidade text not null,
  titulo text not null,
  venc text not null,
  val numeric(10,2) not null,
  criado_em timestamptz not null default now()
);

create table if not exists cm_boletos_mes (
  id bigint generated always as identity primary key,
  unidade text not null,
  morador text not null,
  venc text not null,
  val numeric(10,2) not null,
  status text not null default 'Pendente'
);

create table if not exists cm_avisos (
  id bigint generated always as identity primary key,
  titulo text not null,
  corpo text not null,
  cat text not null,                    -- urgentes | comunicados | manutencoes
  data text not null,
  fixado boolean not null default false,
  criado_em timestamptz not null default now()
);

create table if not exists cm_ocorrencias (
  id bigint generated always as identity primary key,
  titulo text not null,
  data text not null,
  local text,
  tag text not null default 'Aberta',
  tag_class text not null default 'b-blue',
  cat text,
  ic text, cor text,
  criado_em timestamptz not null default now()
);

create table if not exists cm_encomendas (
  id bigint generated always as identity primary key,
  titulo text not null,
  data text not null,
  loja text,
  tag text not null default 'Em armazenamento',
  tag_class text not null default 'b-amber',
  criado_em timestamptz not null default now()
);

create table if not exists cm_sugestoes (
  id bigint generated always as identity primary key,
  titulo text not null,
  corpo text,
  unidade text,
  data text not null,
  tag text not null default 'Em análise',
  tag_class text not null default 'b-amber',
  cat text,
  ic text, cor text,
  criado_em timestamptz not null default now()
);

create table if not exists cm_visitantes (
  id bigint generated always as identity primary key,
  nome text not null,
  unidade text not null,
  motivo text,
  entrada text not null,
  saida text,
  autorizado boolean not null default false,
  dia date not null default current_date
);

create table if not exists cm_autorizacoes (
  id bigint generated always as identity primary key,
  unidade text not null,
  nome text not null,
  doc text,
  motivo text,
  tipo text not null,                   -- unica | periodo | recorrente
  data text,                            -- tipo unica
  de text, ate text,                    -- periodo / recorrente
  dias jsonb,                           -- recorrente: [0..6]
  codigo text not null unique,
  cancelada boolean not null default false,
  usos jsonb not null default '[]'::jsonb,
  criado_em timestamptz not null default now()
);

create table if not exists cm_veiculos (
  id bigint generated always as identity primary key,
  placa text not null unique,
  modelo text not null,
  cor text,
  tipo text not null default 'Carro',
  unidade text not null,
  vaga text
);

create table if not exists cm_assembleias (
  id bigint generated always as identity primary key,
  titulo text not null,
  data text not null,
  hora text,
  local text,
  status text not null default 'Agendada',
  pauta jsonb not null default '[]'::jsonb,
  criado_em timestamptz not null default now()
);

create table if not exists cm_documentos (
  id bigint generated always as identity primary key,
  nome text not null,
  cat text not null,
  tipo text not null default 'PDF',
  tam text,
  data text not null,
  criado_em timestamptz not null default now()
);

create table if not exists cm_manutencoes (
  id bigint generated always as identity primary key,
  item text not null,
  cat text,
  period text not null,
  ultima text not null,
  prox text not null,
  resp text,
  custo numeric(10,2) not null default 0
);

create table if not exists cm_conversas (
  id bigint generated always as identity primary key,
  unidade text not null,
  morador text not null,
  assunto text not null,
  categoria text,
  encerrada boolean not null default false,
  mensagens jsonb not null default '[]'::jsonb,
  criado_em timestamptz not null default now()
);

-- índices de leitura mais comum
create index if not exists cm_boletos_unidade_idx      on cm_boletos(unidade);
create index if not exists cm_veiculos_unidade_idx     on cm_veiculos(unidade);
create index if not exists cm_autorizacoes_unidade_idx on cm_autorizacoes(unidade);
create index if not exists cm_autorizacoes_codigo_idx  on cm_autorizacoes(codigo);
create index if not exists cm_conversas_unidade_idx    on cm_conversas(unidade);
create index if not exists cm_visitantes_dia_idx       on cm_visitantes(dia);

-- ============================================================
-- RLS: aberto, como nos outros projetos internos do Rodrigo.
-- ATENÇÃO: sem autenticação, qualquer um com a chave anon lê e
-- grava tudo. Restringir por unidade exige Supabase Auth —
-- ver "Próximos passos" no CLAUDE.md.
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array[
    'cm_config','cm_perfil','cm_moradores','cm_reservas','cm_boletos','cm_boletos_mes',
    'cm_avisos','cm_ocorrencias','cm_encomendas','cm_sugestoes','cm_visitantes',
    'cm_autorizacoes','cm_veiculos','cm_assembleias','cm_documentos','cm_manutencoes',
    'cm_conversas'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t||'_all', t);
    execute format('create policy %I on %I for all using (true) with check (true)', t||'_all', t);
  end loop;
end $$;


-- ============================================================
-- ETAPA 2 — AUTENTICAÇÃO E RLS POR PAPEL
-- (migrations charles_miller_auth_usuarios_e_votos,
--  charles_miller_rls_por_papel e charles_miller_registro_de_conta)
--
-- cm_usuarios liga cada conta do Supabase Auth a um papel e a uma
-- unidade. Conta sem vínculo aqui, ou com ativo=false, não lê nada.
-- A PRIMEIRA conta criada vira síndico ativo (bootstrap); as demais
-- entram pendentes até o síndico liberar em "Contas de acesso".
--
-- Helpers usados pelas policies (SECURITY DEFINER para não recursar):
--   cm_papel()  cm_unidade()  cm_logado()  cm_eh(text[])
--   cm_registrar(nome, unidade)  cm_eu()
--
-- Resumo das regras:
--   público geral (logado): avisos, documentos, assembleias, moradores,
--                           reservas, ocorrências, sugestões, encomendas, config
--   própria unidade:        boletos, veículos, autorizações, conversas, perfil
--   staff:                  visitantes
--   síndico + administrativo: boletos_mes, publicar avisos/documentos
--   só síndico:             manutenções, config (escrita), contas, assembleias (escrita)
--
-- O SQL completo está nas migrations do projeto; este arquivo é a
-- referência da etapa 1. Ao alterar policies, replicar aqui.
-- ============================================================
