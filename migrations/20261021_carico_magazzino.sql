-- CARICO MAGAZZINO: migrazione da applicare solo dopo test in ambiente separato.
-- Ogni carico incrementa la giacenza senza alterare vendite, vincite o fondo.
create or replace function public.gv_carico_magazzino(
 p_sede uuid, p_id text, p_gioco text, p_quantita integer
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_data date; v_ora text; v_ts bigint; v_nuova integer;
begin
 if auth.uid() is null or not exists (
  select 1 from public.gv_utenti_sedi
  where sede_id=p_sede and user_id=auth.uid() and ruolo='admin'
 ) then raise exception 'Solo amministratore autorizzato'; end if;
 if p_id is null or length(p_id)<8 or length(p_id)>120 then raise exception 'ID non valido'; end if;
 if p_gioco is null or length(trim(p_gioco))=0 then raise exception 'Gioco non valido'; end if;
 if p_quantita is null or p_quantita<1 or p_quantita>100000 then raise exception 'Quantita non valida'; end if;
 perform pg_advisory_xact_lock(hashtext(p_sede::text));
 if exists(select 1 from public.gv_operations where sede_id=p_sede and id=p_id) then
   return jsonb_build_object('duplicato',true,'id',p_id);
 end if;
 update public.gv_games
 set giacenza=giacenza+p_quantita
 where sede_id=p_sede and nome=p_gioco
 returning giacenza into v_nuova;
 if not found then raise exception 'Gioco non trovato'; end if;
 v_data := (now() at time zone 'Europe/Rome')::date;
 v_ora := to_char(now() at time zone 'Europe/Rome','HH24:MI:SS');
 v_ts := floor(extract(epoch from clock_timestamp())*1000)::bigint;
 insert into public.gv_operations(sede_id,id,data,ora,ts,tipo,gioco,quantita,importo,importo_vinto,schede,note)
 values(p_sede,p_id,v_data,v_ora,v_ts,'CARICO',p_gioco,p_quantita,0,null,'[]'::jsonb,'Carico magazzino');
 return jsonb_build_object('id',p_id,'quantita',p_quantita,'giacenza',v_nuova);
end $$;
revoke all on function public.gv_carico_magazzino(uuid,text,text,integer) from public, anon;
grant execute on function public.gv_carico_magazzino(uuid,text,text,integer) to authenticated;
