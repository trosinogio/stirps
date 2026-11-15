# Programma di import

Come si porta in produzione un cambiamento dei dati: un pacchetto nuovo (`dati/*.tsv.gz`), una regola del parser o del
filtro, la logica dell'import (`db/05_import_wiktionary.sql`), un aggiornamento datato. Ogni tappa ha un cancello: se
non passa, ci si ferma lì. Lo strumento centrale è la prova dell'import (`scripts/prova-import.sh`), in locale e su un
ramo di Neon.

## Perché: gli errori già fatti

| Quando | Che cosa è successo | Chi se n'è accorto | Il cancello che ora lo ferma |
|---|---|---|---|
| Fine ottobre | Un import difettoso è finito in produzione (su Neon resta il ramo `import-difettoso-30-10`). | A cose fatte. | La prova dell'import su una copia, prima (tappe 5 e 6). |
| Novembre, con le lingue nuove | Le glosse inglesi di voci già pubblicate cambiavano, e 249 definizioni cadevano. | Il registro della build. | «Definizioni cadute: 0» e «glossa della voce cambiata» nel confronto. |
| 8 novembre | Un aggiornamento datato usava una funzione prima di definirla: avrebbe fermato il deploy. | L'import di prova in locale. | L'import di prova applica tutti gli aggiornamenti datati (tappa 5). |
| 8 novembre | Glosse dell'omografo sbagliato (*brew*²), 2.901 segnaposto come glosse, 162 indirizzi nati da traslitterazioni finte. | Giovanni, sul sito. | Il campione delle voci cambiate (tappa 3) e «indirizzi cambiati» nel confronto. |
| 13 novembre | Le etimologie ad albero di Wiktionary lette male: 16 delle prime 60 cime greche senza etimologia. | Guardando le cime a mano. | La misura delle voci senza etimologia per lingua e le cime più grandi (tappa 2). |
| 13–14 novembre | Il giro Dati fermo due volte: il parser teneva in memoria tutte le voci delle lingue di chiusura (7,0 GB, il limite della macchina), e il registro non diceva dove. | Il workflow fallito. | I tempi e la memoria di ogni passo nel registro (`[parser] …`); le voci di chiusura restano nel file (`VociChiusura`): 2,8 GB. |

Da questi errori vengono tre regole:

- **Una cosa alla volta.** Ogni pubblicazione di dati porta un solo cambiamento (una lingua, una regola, una fonte),
  così ogni numero che si muove ha una causa sola.
- **Si scrive prima che cosa ci si aspetta.** «Più 4.600 varianti latine legate, nessuna voce persa, nessuna glossa
  cambiata». Poi si confronta con ciò che la prova trova.
- **Ciò che cambia senza essere atteso si spiega o si corregge.** Non si pubblica con un numero che nessuno sa spiegare.

## Le tappe

1. **L'attesa.** Nella descrizione del lavoro (poi della pull request): che cosa cambia, quante voci tocca secondo le
   misure che già abbiamo, che cosa non deve cambiare. Per una lingua nuova o una fonte nuova, la stima con
   `import/stima_import.py` (voci, spazio, voci senza etimologia per lingua).
2. **Il giro Dati** (push su un ramo `dati-*`). Si leggono le annotazioni:
   - Parser: voci, ipotesi, passaggi, e i tempi `[parser]` di ogni passo;
   - Voci per lingua, prima e dopo;
   - Radici: quante catene arrivano alla radice dichiarata;
   - Linea del senso, Radici omografe, Due Wiktionary;
   - Stima: righe e spazio in più.

   *Cancello:* nessuna misura peggiora senza una spiegazione.
3. **Il campione.** Trenta voci a caso tra le nuove e le cambiate, guardate una per una; per ogni classe di
   cambiamento attesa, almeno cinque esempi. *Cancello:* nessun errore di classe (lo stesso errore in più voci). Un
   errore di classe si corregge alla fonte, con un test, e si torna alla tappa 2.
4. **Il collaudo:** `scripts/collauda.sh` e `npx tsc --noEmit`. *Cancello:* tutti i test passano; ogni cambiamento di
   comportamento ha il suo test.
5. **La prova dell'import in locale** su una copia della produzione:
   ```bash
   DATABASE_URL=postgres://postgres:postgres@localhost:5432/copia scripts/prova-import.sh
   ```
   Fa la fotografia prima (`db/prove/prima.sql`), l'import come lo fa il deploy (`scripts/inizializza-db.mjs`: tutti
   gli aggiornamenti datati, poi l'import se il pacchetto è cambiato), il confronto dopo (`db/prove/dopo.sql`).
   Il rapporto dice: voci perse e nuove per lingua, indirizzi cambiati, etimologie perse, nuove e cambiate con esempi,
   glosse sparite e cambiate per provenienza, definizioni cadute, famiglie e storie, spazio, righe della redazione
   toccate, secondi dell'import. *Cancelli* (la prova esce con un errore se uno ferma):

   | Cancello | Soglia |
   |---|---|
   | Righe della redazione toccate | 0 |
   | Storico della redazione cambiato | 0 |
   | Definizioni cadute | 0 |
   | Voci perse | 0,5% delle voci (`PERSE`) |
   | Etimologie perse | 0,5% delle accolte (`ETIMI`) |
   | Indirizzi cambiati o spariti | 0,5% delle voci (`INDIRIZZI`) |
   | Spazio dopo l'import | `LIMITE_MB`, se impostato |

   Una soglia si alza solo per un cambiamento atteso e scritto alla tappa 1 (togliere le forme flesse fa perdere
   voci: è voluto), mai per far passare una prova.
6. **La pull request verso `main`**, con l'attesa, il rapporto della prova locale e gli esempi. La stessa prova parte
   da sé su Neon (`.github/workflows/prova-import.yml`): crea un ramo dalla produzione, ci fa l'import, confronta,
   cancella il ramo. Lì il database è quello vero: Postgres 18, i dati di oggi, il lavoro della redazione.
   *Cancello:* la prova su Neon passa, e i suoi numeri sono quelli della prova locale.
7. **Il via libera di Giovanni**, poi l'unione. `pubblica.yml` crea il ramo di riserva, pubblica e controlla.
8. **Dopo la pubblicazione:** le annotazioni (Spazio, Controllo, Deploy, Ramo di riserva) e le pagine toccate sul
   sito, dal ramo di servizio `controllo-sito`: almeno una pagina per classe di cambiamento.

## Se qualcosa va male in produzione

- **Se il deploy fallisce durante l'import,** il database resta com'era: l'import è in una transazione. Si legge il
  registro, si corregge, si riparte dalla tappa 4.
- **Se l'import è riuscito ma i dati sono sbagliati,** si torna al ramo di riserva creato da `pubblica.yml` prima del
  deploy. Prima si chiede a Giovanni: il ripristino cancella ciò che la redazione ha scritto dopo la riserva.
  ```bash
  neon branches restore production backup-AAAA-MM-GG-HHMM --preserve-under-name produzione-prima-del-ripristino --project-id aged-truth-35630140
  ```
  Poi si riporta `main` al commit precedente e si ripubblica, altrimenti il deploy successivo rifà lo stesso import.
- **La finestra di ripristino istantaneo** di Neon è di 6 ore: dentro quella finestra si può tornare a un istante
  preciso (`production ^self@<ora>`).

## Neon, in breve

- Progetto `aged-truth-35630140` (Dizionario Etimologico), regione Francoforte, Postgres 18, piano Launch dal 14
  novembre 2026: lo spazio non ha più il tetto di 1 GB, ma si paga a consumo, e ogni ramo in più conta.
- I rami di prova si chiamano `prova-import-<numero>`, nascono con una scadenza di un giorno e il workflow li cancella
  alla fine. I rami di riserva si chiamano `backup-…` e li gestisce `pubblica.yml`.
- Dalla sessione di Claude la CLI `neon` funziona con la chiave salvata nell'ambiente (`NEON_API_KEY=proxy-injected`):
  elenca, misura, crea e cancella rami di prova. Sulla produzione non si scrive da lì: si passa dalla pull request.
