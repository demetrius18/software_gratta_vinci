V5.1 - FASI 1, 2, 3 - BUILD DI COLLAUDO, NON PRODUZIONE

ACCESSI
- Admin generale: buruian@hippogroup.it; autorizzato sulle 4 sedi.
- Bologna: hipposlot@gmail.com; operatore SOLO Bologna.
- Nessuna password inclusa nei file.
- Direzione nascosta in cassa agli operatori e contenuto delle pagine admin protetto.
- Le RLS e le RPC devono comunque essere applicate al database; nascondere una pagina NON è un controllo di sicurezza sufficiente.

INSTALLAZIONE SU AMBIENTE DI TEST (NON SUL DATABASE OPERATIVO)
1. Esegui un backup verificato di Supabase.
2. Usa un progetto Supabase di prova con copia dei dati.
3. Esegui 01_chiusure_giornaliere.sql, poi 02_transazioni_sicure.sql, poi 03_sicurezza_audit_post_chiusura.sql.
4. Aggiorna gv-config.js con URL e chiave pubblica del progetto di prova.
5. Pubblica questi file su ramo GitHub di test, senza mescolare client V4 e V5.
6. Test: operatore Bologna NON vede Direzione e non può aprire URL admin; Admin vede tutte le sedi.
7. Test: giacenza 1 e due vendite simultanee: una sola deve riuscire; riconnessione, vendita, vincita, riscossione, annullamento.
8. Test: chiusura unica e movimento successivo: verifica gv_movimenti_post_chiusura; rettifica manuale distinta.
9. Abilita Supabase Realtime per gv_operations e gv_games oppure usa fallback polling 15 s.

LIMITI APERTI
- Il codice V5 è stato controllato staticamente, NON con un browser multiutente reale.
- Le nuove operazioni post-chiusura vengono tracciate automaticamente ma NON trasformate automaticamente in rettifiche monetarie; quelle restano atti amministrativi separati.
- La gestione catalogo e l'importazione diretta di backup restano disabilitate in V5 per protezione.
- Il vecchio archivio per turni resta solo per compatibilità: non usarlo come chiusura ufficiale.
- Alcune operazioni storiche potrebbero non essere ancora migrate alle RPC: eseguire test end-to-end.
- Il ripristino offline delle transazioni non è implementato; in assenza di cloud le operazioni vanno bloccate.
- Non applicare gli script su produzione senza test, backup e finestra di migrazione.
