## Plan: FastCalc MVP Base

Impostare una base solida macOS (AppKit puro) con rotolo virtuale editabile, finestra a toggle su F16, logica calcolatrice con totalizzatore automatico e test interfaccia iniziali. L'approccio consigliato separa chiaramente Core (business logic) e UI, così da testare bene il motore di calcolo e mantenere la UI evolvibile.

**Steps**
1. Fase 1 - Rifondazione struttura pacchetto (*blocca tutte le fasi successive*): aggiornare il package per macOS 14+, separare target Core e target App, mantenendo eventuale target eseguibile minimo per bootstrap.
2. Fase 1 - Definizione dominio Core (*dipende da 1*): progettare stati e transizioni della calcolatrice (input corrente, operatore pendente, subtotal, totalizzatore, cronologia righe rotolo, stato tasto Delete singolo/doppio).
3. Fase 1 - Specifica formale regole input (*dipende da 2*): mappare equivalenze tasti risultato (Invio, =, T), comportamento Backspace, Delete singolo (reset sessione corrente senza cancellare storico), Delete doppio (clear totale + reset dimensione/posizione finestra minima in basso a destra).
4. Fase 2 - UI Shell AppKit (*dipende da 1, parallel con 5*): implementare app menu bar con icona, finestra non visibile all'avvio, toggle con F16, ripristino stato precedente, ancoraggio apertura da angolo inferiore destro display primario.
5. Fase 2 - Componente rotolo virtuale editabile (*dipende da 1, parallel con 4*): realizzare area documento lineare editabile con scrolling tastiera e mouse, cursore, editing retroattivo, append di nuove righe calcolo.
6. Fase 2 - Persistenza stato (*dipende da 4 e 5*): salvare contenuto rotolo, posizione cursore/scroll, geometria finestra e stato visibilità; ripristino al toggle successivo.
7. Fase 3 - Implementazione motore calcolo (*dipende da 2 e 3*): integrare accumulatore automatico (totalizzatore), logica doppia pressione risultato per richiamo totale, e aggiornamento rotolo con righe formula/risultato.
8. Fase 3 - Integrazione input UI-Core (*dipende da 5 e 7*): collegare key events e editing del rotolo al motore, con invalidazione/coerenza quando si modifica storico.
9. Fase 4 - Test automatici base interfaccia (*dipende da 4, 5, 6*): validare startup invisibile, toggle F16 open/close, posizione iniziale angolo inferiore destro, persistenza stato finestra/rotolo, reset dimensione su Delete doppio.
10. Fase 4 - Test business logic con esempi specifica (*dipende da 7*): coprire scenari equivalenza Invio/= /T, accumulo automatico, richiamo totalizzatore con seconda pressione risultato, Backspace, Delete singolo/doppio.
11. Fase 4 - Checklist manuale UX (*dipende da 8, 9*): verificare usabilità reale di scroll/editing rotolo con tastiera e mouse in attesa dei dettagli di interazione avanzata.

**Relevant files**
- /Volumes/mm4-data/fcs/fastcalc/Package.swift - da estendere per piattaforma macOS 14+, target modulari e target test.
- /Volumes/mm4-data/fcs/fastcalc/Sources/fastcalc/fastcalc.swift - da sostituire come bootstrap temporaneo nella transizione alla app AppKit.

**Verification**
1. Eseguire suite unit test del Core: aritmetica base, stato operatori, totalizzatore automatico, seconda pressione risultato per totale.
2. Eseguire test interfaccia base: app invisibile in avvio, icona menu bar presente, F16 toggle corretto, riapertura con stato precedente.
3. Validare persistenza: chiusura/rilancio, contenuto rotolo e geometria finestra ripristinati.
4. Validare reset: Delete singolo non cancella storico; Delete doppio azzera tutto e riporta finestra alla dimensione minima in basso a destra.
5. Eseguire checklist manuale su display primario con più risoluzioni per ancoraggio e resize.

**Esempi specifica logica (da tradurre in test)**
1. Accumulo automatico base: input `12`, `+`, `8`, `Invio` produce risultato 20; nuova sequenza `5`, `Invio` accumula a 25 nel totalizzatore.
2. Richiamo totalizzatore: dopo uno o più risultati, una seconda pressione consecutiva di `Invio` (o `=` o `T`) mostra il totale accumulato senza richiedere M+.
3. Equivalenza tasti risultato: la stessa sequenza con `Invio`, `=` o `T` deve produrre identico stato interno e identica riga sul rotolo.
4. Backspace: su input corrente `123`, `Backspace` porta a `12`; ripetendo fino a vuoto non altera le righe storiche già confermate.
5. Delete singolo: durante una nuova operazione in corso, `Delete` resetta solo il calcolo corrente e lascia inalterato lo storico del rotolo.
6. Delete doppio: `Delete` seguito da `Delete` entro finestra temporale definita azzera stato + storico e riporta UI alla dimensione minima ancorata in basso a destra.

**Decisions**
- UI: AppKit puro.
- Target OS: macOS 14+.
- Test UI in MVP: automazione base + checklist manuale.
- Persistenza MVP: contenuto rotolo + posizione cursore/scroll + geometria/stato finestra.
- Scope incluso: architettura base, specifica comportamento tasti fondamentali, piano test.
- Scope escluso (fase successiva): dettagli completi gesture/interazioni avanzate tastiera-mouse, rifiniture grafiche finali.

**Further Considerations**
1. Definire con precisione la finestra minima del rotolo (dimensioni e padding dal bordo schermo) prima dell'implementazione UI.
2. Stabilire regola per modifiche retroattive nel rotolo: ricalcolo automatico immediato vs ricalcolo solo alla conferma con risultato.
3. Decidere se la cronologia deve supportare esportazione/stampa in una fase successiva.
