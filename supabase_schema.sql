-- Schema per Gestionale Gratta e Vinci
-- Da eseguire in Supabase > SQL Editor > Run

create table if not exists public.gv_games (
  nome text primary key,
  prezzo numeric not null default 0,
  giacenza integer not null default 0,
  colore text,
  immagine text,
  ordine integer not null default 0
);

create table if not exists public.gv_operations (
  id text primary key,
  data date not null,
  ora text,
  ts bigint,
  tipo text not null,
  gioco text,
  quantita integer not null default 0,
  importo numeric not null default 0,
  importo_vinto numeric,
  schede jsonb not null default '[]'::jsonb,
  note text
);

create table if not exists public.gv_settings (
  key text primary key,
  value text
);

create table if not exists public.gv_archivio (
  data date not null,
  turno text not null,
  pezzi integer not null default 0,
  incasso_vendite numeric not null default 0,
  pagamenti numeric not null default 0,
  cassa_netta numeric not null default 0,
  num_operazioni integer not null default 0,
  primary key (data, turno)
);

create index if not exists gv_operations_data_idx on public.gv_operations(data);
create index if not exists gv_operations_ts_idx on public.gv_operations(ts);
create index if not exists gv_archivio_data_idx on public.gv_archivio(data);

-- RLS: per un gestionale usato da un solo punto vendita tramite publishable key,
-- abilitiamo RLS e permettiamo le operazioni anonime sulle sole tabelle del gestionale.
-- IMPORTANTE: la publishable key e' destinata al frontend; non usare service_role/secret key.

alter table public.gv_games enable row level security;
alter table public.gv_operations enable row level security;
alter table public.gv_settings enable row level security;
alter table public.gv_archivio enable row level security;

drop policy if exists gv_games_public_all on public.gv_games;
create policy gv_games_public_all on public.gv_games for all to anon using (true) with check (true);

drop policy if exists gv_operations_public_all on public.gv_operations;
create policy gv_operations_public_all on public.gv_operations for all to anon using (true) with check (true);

drop policy if exists gv_settings_public_all on public.gv_settings;
create policy gv_settings_public_all on public.gv_settings for all to anon using (true) with check (true);

drop policy if exists gv_archivio_public_all on public.gv_archivio;
create policy gv_archivio_public_all on public.gv_archivio for all to anon using (true) with check (true);
