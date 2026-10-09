-- V5.1: eseguire SOLO dopo 01_chiusure_giornaliere.sql e 02_transazioni_sicure.sql.
-- Migrazione additiva: nessuna cancellazione dei movimenti esistenti.
BEGIN;
CREATE TABLE IF NOT EXISTS public.gv_movimenti_post_chiusura (
  sede_id uuid NOT NULL REFERENCES public.gv_sedi(id),
  operation_id text NOT NULL,
  data date NOT NULL,
  registrato_at timestamptz NOT NULL DEFAULT now(),
  registrato_da uuid REFERENCES auth.users(id),
  tipo text NOT NULL,
  importo numeric NOT NULL,
  PRIMARY KEY (sede_id, operation_id),
  FOREIGN KEY (sede_id, data) REFERENCES public.gv_chiusure_giornaliere(sede_id,data)
);
ALTER TABLE public.gv_movimenti_post_chiusura ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gv_movimenti_post_chiusura FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.gv_movimenti_post_chiusura TO authenticated;
DROP POLICY IF EXISTS gv_post_chiusura_admin ON public.gv_movimenti_post_chiusura;
CREATE POLICY gv_post_chiusura_admin ON public.gv_movimenti_post_chiusura FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.gv_utenti_sedi m WHERE m.user_id=(SELECT auth.uid()) AND m.sede_id=gv_movimenti_post_chiusura.sede_id AND m.ruolo='admin')
);
CREATE OR REPLACE FUNCTION public.gv_traccia_post_chiusura()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.gv_chiusure_giornaliere c WHERE c.sede_id=NEW.sede_id AND c.data=NEW.data) THEN
    INSERT INTO public.gv_movimenti_post_chiusura(sede_id,operation_id,data,registrato_da,tipo,importo)
    VALUES(NEW.sede_id,NEW.id,NEW.data,auth.uid(),NEW.tipo,NEW.importo)
    ON CONFLICT (sede_id,operation_id) DO NOTHING;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS gv_post_chiusura_trigger ON public.gv_operations;
CREATE TRIGGER gv_post_chiusura_trigger AFTER INSERT ON public.gv_operations
FOR EACH ROW EXECUTE FUNCTION public.gv_traccia_post_chiusura();
-- Nessun accesso diretto alle scritture contabili: usare solo RPC autorizzate.
REVOKE INSERT, UPDATE, DELETE ON public.gv_operations FROM PUBLIC, anon, authenticated;
REVOKE UPDATE, DELETE ON public.gv_games FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.gv_chiusure_giornaliere FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.gv_rettifiche_giornaliere FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.gv_audit_annullamenti FROM PUBLIC, anon, authenticated;
-- La lettura dei movimenti deve essere limitata alla sede assegnata.
DROP POLICY IF EXISTS gv_operations_read ON public.gv_operations;
CREATE POLICY gv_operations_read ON public.gv_operations FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.gv_utenti_sedi m WHERE m.user_id=(SELECT auth.uid()) AND m.sede_id=gv_operations.sede_id)
);
COMMIT;
