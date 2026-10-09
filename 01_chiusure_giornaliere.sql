-- V4: eseguire una sola volta nel SQL Editor del NUOVO progetto Supabase.
-- Non modifica né cancella operazioni, magazzino o archivio esistenti.
create table if not exists public.gv_chiusure_giornaliere (
  sede_id uuid not null references public.gv_sedi(id),
  data date not null,
  chiusa_at timestamptz not null default now(),
  chiusa_da uuid not null references auth.users(id),
  pezzi integer not null default 0,
  vendite numeric not null default 0,
  pagamenti numeric not null default 0,
  riscatti numeric not null default 0,
  netto numeric not null default 0,
  num_operazioni integer not null default 0,
  primary key (sede_id,data)
);
create table if not exists public.gv_rettifiche_giornaliere (
  id uuid primary key default gen_random_uuid(),
  sede_id uuid not null,
  data date not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  motivo text not null check (length(trim(motivo)) >= 5),
  delta numeric not null check (delta <> 0),
  foreign key (sede_id,data) references public.gv_chiusure_giornaliere(sede_id,data)
);
create index if not exists gv_rettifiche_sede_data_idx on public.gv_rettifiche_giornaliere(sede_id,data,created_at);
alter table public.gv_chiusure_giornaliere enable row level security;
alter table public.gv_rettifiche_giornaliere enable row level security;
revoke all on public.gv_chiusure_giornaliere from anon;
revoke all on public.gv_rettifiche_giornaliere from anon;
grant select on public.gv_chiusure_giornaliere to authenticated;
grant select on public.gv_rettifiche_giornaliere to authenticated;
drop policy if exists gv_chiusure_select on public.gv_chiusure_giornaliere;
create policy gv_chiusure_select on public.gv_chiusure_giornaliere for select to authenticated using
 (exists(select 1 from public.gv_utenti_sedi m where m.user_id=auth.uid() and m.sede_id=gv_chiusure_giornaliere.sede_id));
drop policy if exists gv_rettifiche_select on public.gv_rettifiche_giornaliere;
create policy gv_rettifiche_select on public.gv_rettifiche_giornaliere for select to authenticated using
 (exists(select 1 from public.gv_utenti_sedi m where m.user_id=auth.uid() and m.sede_id=gv_rettifiche_giornaliere.sede_id));

-- Chiusura atomica calcolata dal DB; duplicati impediti dalla chiave primaria.
create or replace function public.gv_chiudi_giornata(p_sede uuid,p_data date)
returns public.gv_chiusure_giornaliere language plpgsql security definer set search_path = '' as $$
declare v public.gv_chiusure_giornaliere;
begin
 if not exists(select 1 from public.gv_utenti_sedi where sede_id=p_sede and user_id=auth.uid() and ruolo='admin') then
   raise exception 'Accesso Admin richiesto';
 end if;
 if p_data > (now() at time zone 'Europe/Rome')::date then raise exception 'Data futura non consentita'; end if;
 -- Serializza chiusure concorrenti per la stessa sede/data.
 perform pg_advisory_xact_lock(hashtext(p_sede::text),hashtext(p_data::text));
 insert into public.gv_chiusure_giornaliere(sede_id,data,chiusa_da,pezzi,vendite,pagamenti,riscatti,netto,num_operazioni)
 select p_sede,p_data,auth.uid(),
 coalesce(sum(case when tipo='VENDITA' then quantita else 0 end),0),
 coalesce(sum(case when tipo='VENDITA' then importo else 0 end),0),
 coalesce(sum(case when tipo='RISCOSSIONE' or (tipo='PAGAMENTO VINCITA' and jsonb_array_length(schede)=0) then importo else 0 end),0),
 coalesce(sum(case when tipo='RISCATTO VINCITA' then importo else 0 end),0),
 coalesce(sum(case when tipo='VENDITA' or tipo='RISCATTO VINCITA' then importo when tipo='RISCOSSIONE' or (tipo='PAGAMENTO VINCITA' and jsonb_array_length(schede)=0) then -importo else 0 end),0),
 count(*)::integer
 from public.gv_operations where sede_id=p_sede and data=p_data
 on conflict(sede_id,data) do nothing;
 select * into v from public.gv_chiusure_giornaliere where sede_id=p_sede and data=p_data;
 return v;
end $$;
revoke all on function public.gv_chiudi_giornata(uuid,date) from public,anon;
grant execute on function public.gv_chiudi_giornata(uuid,date) to authenticated;

create or replace function public.gv_aggiungi_rettifica(p_sede uuid,p_data date,p_delta numeric,p_motivo text)
returns public.gv_rettifiche_giornaliere language plpgsql security definer set search_path = '' as $$
declare v public.gv_rettifiche_giornaliere;
begin
 if not exists(select 1 from public.gv_utenti_sedi where sede_id=p_sede and user_id=auth.uid() and ruolo='admin') then
   raise exception 'Accesso Admin richiesto';
 end if;
 if p_delta is null or p_delta=0 or length(trim(coalesce(p_motivo,'')))<5 then raise exception 'Importo e motivo obbligatori'; end if;
 insert into public.gv_rettifiche_giornaliere(sede_id,data,created_by,delta,motivo)
 values(p_sede,p_data,auth.uid(),p_delta,trim(p_motivo)) returning * into v;
 return v;
end $$;
revoke all on function public.gv_aggiungi_rettifica(uuid,date,numeric,text) from public,anon;
grant execute on function public.gv_aggiungi_rettifica(uuid,date,numeric,text) to authenticated;
