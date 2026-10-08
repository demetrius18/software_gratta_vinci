GESTIONALE GRATTA E VINCI - PACCHETTO MULTISEDE DI TEST

File da caricare nella radice del ramo di sviluppo GitHub:
index.html, app.js, admin.html, login.html, gv-config.js, gv-auth.js

1. NON pubblicare su main prima dei test.
2. Usa SOLO il nuovo Supabase kwidkukwvnqozunkiogp; il vecchio non viene contattato.
3. Gli utenti devono esistere in Supabase Auth ed essere associati alle sedi in gv_utenti_sedi.
4. Le policy RLS devono consentire all'utente di leggere la propria appartenenza, leggere la sede e accedere solo ai dati autorizzati.
5. Accedi da login.html, seleziona sede e apri cassa o direzione.
6. Alla prima apertura di una sede senza dati, la cassa mostra biglietti di esempio: verificare e correggere tutte le giacenze PRIMA del primo invio cloud.
7. La sincronizzazione è incrementale per sede e NON elimina le righe cloud. Le eliminazioni di giochi/operazioni effettuate nel browser potrebbero non riflettersi nel cloud.
8. IMPORTANTE: la sincronizzazione non è transazionale: due casse sulla stessa sede possono sovrascrivere le giacenze. Per uso contemporaneo serve una RPC atomica lato database.
9. Esegui backup di ciascuna sede e verifica vendite, vincite, riscossioni, chiusura, import/export e permessi prima dell'utilizzo reale.
10. Nessun account, password o credenziale di amministrazione segreta è incluso nel pacchetto. La chiave pubblicabile Supabase NON è una password.
