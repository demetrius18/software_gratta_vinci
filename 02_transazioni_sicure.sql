-- V5: eseguire DOPO 01_chiusure_giornaliere.sql, su database di test prima della produzione.
-- Nessuna cancellazione dati. Le chiamate dirette alle tabelle rimangono temporaneamente
-- disponibili per retrocompatibilita: non usare client V4 insieme alla V5.
create or replace function public.gv_registra_movimento(
 p_sede uuid,p_id text,p_tipo text,p_gioco text,p_importo numeric default 0,p_note text default ''
) returns jsonb language plpgsql security definer set search_path='' as $$
declare g public.gv_games; q integer:=0; v_importo numeric:=0; v_data date; v_ora text; v_ts bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.gv_utenti_sedi where sede_id=p_sede and user_id=auth.uid()) then raise exception 'Sede non autorizzata'; end if;
 if p_id is null or length(p_id)<8 or length(p_id)>120 then raise exception 'ID non valido'; end if;
 if p_tipo not in ('VENDITA','VINCITA','RISCOSSIONE') then raise exception 'Tipo non valido'; end if;
 if p_tipo='RISCOSSIONE' and (p_importo is null or p_importo<=0 or p_importo>1000000) then raise exception 'Importo non valido'; end if;
 -- Serializza tutte le scritture e la chiusura per sede; idempotenza su ID.
 perform pg_advisory_xact_lock(hashtext(p_sede::text));
 if exists(select 1 from public.gv_operations where sede_id=p_sede and id=p_id) then
   return jsonb_build_object('duplicato',true,'id',p_id);
 end if;
 v_data := (now() at time zone 'Europe/Rome')::date;
 v_ora := to_char(now() at time zone 'Europe/Rome','HH24:MI:SS');
 v_ts := floor(extract(epoch from clock_timestamp())*1000)::bigint;
 if p_tipo in ('VENDITA','VINCITA') then
   select * into g from public.gv_games where sede_id=p_sede and nome=p_gioco for update;
   if not found then raise exception 'Gioco non trovato'; end if;
   if g.giacenza<1 then raise exception 'Giacenza insufficiente'; end if;
   update public.gv_games set giacenza=giacenza-1 where sede_id=p_sede and nome=p_gioco;
   q:=1;
   if p_tipo='VENDITA' then v_importo:=g.prezzo; end if;
 else v_importo:=p_importo; end if;
 insert into public.gv_operations(sede_id,id,data,ora,ts,tipo,gioco,quantita,importo,importo_vinto,schede,note)
 values(p_sede,p_id,v_data,v_ora,v_ts,p_tipo,coalesce(p_gioco,''),q,v_importo,
 case when p_tipo='VINCITA' then g.prezzo when p_tipo='RISCOSSIONE' then v_importo else null end,
 case when p_tipo='VINCITA' then jsonb_build_array(jsonb_build_object('gioco',p_gioco,'quantita',1,'prezzo',g.prezzo)) else '[]'::jsonb end,
 left(coalesce(p_note,''),1000));
 return jsonb_build_object('id',p_id,'tipo',p_tipo,'importo',v_importo,'data',v_data);
end $$;
revoke all on function public.gv_registra_movimento(uuid,text,text,text,numeric,text) from public,anon;
grant execute on function public.gv_registra_movimento(uuid,text,text,text,numeric,text) to authenticated;

create table if not exists public.gv_audit_annullamenti(
 id bigint generated always as identity primary key,sede_id uuid not null references public.gv_sedi(id),
 operation_id text not null,data date not null,tipo text not null,gioco text,quantita integer,importo numeric,
 annullato_da uuid not null references auth.users(id),motivo text not null,annullato_at timestamptz not null default now()
);
alter table public.gv_audit_annullamenti enable row level security;
revoke all on public.gv_audit_annullamenti from anon,authenticated;
grant select on public.gv_audit_annullamenti to authenticated;
create policy gv_audit_admin_read on public.gv_audit_annullamenti for select to authenticated using
 (exists(select 1 from public.gv_utenti_sedi m where m.sede_id=gv_audit_annullamenti.sede_id and m.user_id=auth.uid() and m.ruolo='admin'));

create or replace function public.gv_annulla_movimento(p_sede uuid,p_id text,p_motivo text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.gv_operations; item jsonb; g text; q integer;
begin
 if not exists(select 1 from public.gv_utenti_sedi where sede_id=p_sede and user_id=auth.uid() and ruolo='admin') then raise exception 'Solo Admin puo annullare'; end if;
 if length(trim(coalesce(p_motivo,'')))<5 then raise exception 'Motivo obbligatorio (minimo 5 caratteri)'; end if;
 perform pg_advisory_xact_lock(hashtext(p_sede::text));
 select * into o from public.gv_operations where sede_id=p_sede and id=p_id for update;
 if not found then raise exception 'Operazione non trovata'; end if;
 if exists(select 1 from public.gv_chiusure_giornaliere where sede_id=p_sede and data=o.data) then raise exception 'Giornata chiusa: usare rettifica'; end if;
 if o.tipo in ('VENDITA','VINCITA') then
   update public.gv_games set giacenza=giacenza+o.quantita where sede_id=p_sede and nome=o.gioco;
   if not found then raise exception 'Gioco mancante: annullamento bloccato'; end if;
 elsif o.tipo='PAGAMENTO VINCITA' then
   for item in select value from jsonb_array_elements(coalesce(o.schede,'[]'::jsonb)) loop
     g:=item->>'gioco';q:=(item->>'quantita')::integer;
     update public.gv_games set giacenza=giacenza+q where sede_id=p_sede and nome=g;
     if not found then raise exception 'Gioco mancante: annullamento bloccato'; end if;
   end loop;
 end if;
 insert into public.gv_audit_annullamenti(sede_id,operation_id,data,tipo,gioco,quantita,importo,annullato_da,motivo)
 values(p_sede,o.id,o.data,o.tipo,o.gioco,o.quantita,o.importo,auth.uid(),trim(p_motivo));
 delete from public.gv_operations where sede_id=p_sede and id=p_id;
 return jsonb_build_object('annullato',p_id);
end $$;
revoke all on function public.gv_annulla_movimento(uuid,text,text) from public,anon;
grant execute on function public.gv_annulla_movimento(uuid,text,text) to authenticated;
-- La funzione di chiusura della V4 va resa coerente con lo stesso advisory lock per sede.

-- Stesso lock della registrazione: chiusura e movimento non si sovrappongono.
create or replace function public.gv_chiudi_giornata(p_sede uuid,p_data date)
returns public.gv_chiusure_giornaliere language plpgsql security definer set search_path = '' as $$
declare v public.gv_chiusure_giornaliere;
begin
 if not exists(select 1 from public.gv_utenti_sedi where sede_id=p_sede and user_id=auth.uid() and ruolo='admin') then
   raise exception 'Accesso Admin richiesto';
 end if;
 if p_data > (now() at time zone 'Europe/Rome')::date then raise exception 'Data futura non consentita'; end if;
 -- Serializza chiusure concorrenti per la stessa sede/data.
 perform pg_advisory_xact_lock(hashtext(p_sede::text));
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


-- Impedisce scritture dirette che aggirerebbero le RPC; mantiene SELECT per RLS.
revoke insert,update,delete on public.gv_operations from authenticated;
revoke update on public.gv_games from authenticated;
-- Realtime richiede pubblicazione delle tabelle; polling ogni 15 secondi e fallback.
