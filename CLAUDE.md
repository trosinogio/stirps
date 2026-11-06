# Stirps — istruzioni per Claude Code

Stirps è un dizionario etimologico per radici: per ogni parola mostra la catena degli etimi fino alla radice, la famiglia, la linea del tempo, le fonti. In produzione su https://dizionario-etimologico.vercel.app (Next.js su Vercel, Postgres su Neon, regione Francoforte). Lo cura Giovanni, che è anche il primo redattore.

Tutto il progetto è in italiano: identificatori, commenti, messaggi di commit, testi dell’interfaccia, risposte. L’inglese compare solo nei testi `en` dell’interfaccia.

Per i dettagli: `README.md` (app, database, redazione, storie, glosse, indirizzi, deploy) e `import/LEGGIMI.md` (parser e import da Wiktionary). Leggili prima di toccare le parti che descrivono.

## Come si lavora: economia e rigore

- **Economia.** Ogni sessione costa: prima un piano breve, poi i passi, con una sola verifica per passo. Niente esplorazioni ripetute, niente file riletti senza motivo, niente attese a colpi di controlli (una sola attesa in background che avvisa alla fine). Gli strumenti che servono più di una volta stanno nel repository (`import/filtra_pacchetto.py`, il registro delle traduzioni tentate), non si riscrivono.
- **Rigore scientifico prima della quantità.** Una voce è una parola della sua lingua. Per latino e greco solo lemmi nel loro alfabeto (`lemma_valido()` in `import/wiktionary.py`): niente lettere isolate, simboli, abbreviazioni, sillabario cipriota, lettere epicoriche, frammenti di testo. In ogni lingua solo lemmi, non forme flesse (*amamus*, *noctem*, *vicinissimo*): le riconosce `forma_flessa()` in `import/filtra.py`, dai segni di Wiktionary o dalla glossa, su tutti i sensi. Basta un senso lessicale perché la voce resti (*ottimo*, «very good»); una forma citata in una catena si lega al suo lemma (`forme.tsv`: *battipanni* < *battere*, forma citata «batti»); le varianti («alternative form of») restano. Dopo ogni import si guarda un campione dei dati nuovi prima di pubblicare, e i conti del filtro («forme flesse … riconosciute dalla sola glossa») nel registro del workflow Dati.
- **Le catene non si rovesciano e non scelgono a caso** (`import/wiktionary.py`): una radice ricostruita è la cima della sua famiglia e non ha etimi automatici; un tema (*\*meh₂-tu-*) deriva solo dalla sua radice; nessuna parola deriva da una lingua che discende dalla sua (genealogia in `antenato_lingua()`); un arco verso il nodo generico di radici omografe passa alla radice precisa solo se tutte le parole sotto la dichiarano (`precisa_omografe()`); il ripiego sulla radice dichiarata collega solo con una maggioranza chiara. Il controllo `import/controlla_radici.py` (nel workflow Dati) misura quante catene arrivano alla radice dichiarata: 86% a novembre 2026, ed era il 73%; con l’inglese l’81%, perché abbondano i composti e le ricostruzioni diverse della stessa radice in Wiktionary (\*kap- e \*keh₂p-). Il controllo le conta a parte («variante di notazione», «per un altro etimo», «si ferma su una parola ricostruita»): le catene verso un’altra radice sono il 6%.
- **Le date trovate in automatico sono stime:** un terminus ante quem («almeno dal …», `attestazione.stima`, con la fonte e la confidenza), mai la prima attestazione finché la redazione non la verifica. Fonti e strumento di datazione: `import/DATAZIONI.md`.
- **Gli indici seguono l’alfabeto:** 23 lettere per il latino (J sotto I, U sotto V), 24 per il greco; i nomi propri in un indice a parte; pagine da 500 voci (`parole_lingua()`, colonne `chiave_indice` e `nome_proprio`).

## Prima di tutto: sicurezza dei dati

- **`.env.local` punta al database di produzione.** `npm run build` esegue prima `scripts/inizializza-db.mjs`, che scrive nel database: per prove in locale passa sempre `DATABASE_URL` e `DATABASE_URL_UNPOOLED` espliciti verso un Postgres locale.
- **Il lavoro della redazione non si ricostruisce.** Prima di qualunque operazione che cambi i dati di produzione (nuovo import, migrazione, ricalcoli pesanti) crea un ramo di riserva su Neon: `neon branches create --name backup-AAAA-MM-GG --parent production --no-compute`. Non azzerare mai lo schema `public`: è stato fatto una volta, prima che la redazione cominciasse, e non va ripetuto.
- **Mai segreti nel codice, nei log o in chat.** Le variabili stanno nelle impostazioni di Vercel e nei segreti di GitHub.
- **Prima di un’operazione rischiosa in produzione chiedi conferma a Giovanni.**
- **Un push su `main` va in produzione:** dopo il collaudo lo pubblica `.github/workflows/pubblica.yml`, che crea da sé il ramo di riserva. Si lavora su un ramo, e si unisce a `main` solo con il via libera di Giovanni.

## Comandi

- `npm run dev`: sviluppo (con un `DATABASE_URL` locale).
- `npx tsc --noEmit`: controllo dei tipi.
- `PGURL=postgres://utente:password@localhost:5432 scripts/collauda.sh`: tutti i test su un Postgres vuoto, i 91 del seme (`db/04_test.sql`) e i 93 dell’import (`db/06_test_import.sql`). Devono passare prima di ogni push; la stessa cosa la fa `.github/workflows/collaudo.yml`.
- `node scripts/applica-sql.mjs file.sql`: applica un file SQL in una transazione.
- `node scripts/esporta-redazione.mjs cartella`: copia del lavoro della redazione in JSON; ogni notte la fa `.github/workflows/copia-redazione.yml` nel ramo `copia-redazione`.
- Import completo da Wiktionary: `import/importa.sh` (scarica i dump di Kaikki; latino e greco entrano interi, `INTERE=la,grc`, con i lemmi del Lewis & Short e dell’LSJ che Wiktionary non ha, dal Perseus: `DIZIONARI=1`; l’inglese con il lessico comune e le parole di etimo esterno, senza nomi propri né locuzioni: `CON_ETIMOLOGIA=en`, `ELENCHI`, `ESTERNI`, e le glosse già pubblicate stabili con `PRECEDENTI`); collaudo del parser: `import/collauda.sh`. Prima di un import grande, la stima: `import/stima_import.py` (righe, spazio, ambiti, campione di catene). Vedi `import/LEGGIMI.md`.
- Traduzioni e definizioni di Claude: `import/definisci.py`, con il workflow Definizioni (push su un ramo `definizioni-*` che cambia `import/claude/lotti.conf`; segreto `ANTHROPIC_API_KEY`). Le voci già fatte non si rimandano. Vedi il README.
- Pacchetto dati: si rigenera su GitHub con un push su un ramo `dati-*` (`.github/workflows/dati.yml`), che rimette `dati/*.tsv.gz` sul ramo. Da una sandbox Kaikki di solito non si raggiunge.
- Pubblicazione: `.github/workflows/pubblica.yml`, dopo ogni collaudo riuscito su `main`, o a mano (`gh api repos/trosinogio/stirps/actions/workflows/pubblica.yml/dispatches -X POST -f ref=main`). Fa ramo di riserva su Neon, deploy su Vercel e controllo; l’esito sta nelle annotazioni del job. Il deploy passa da `scripts/pubblica-vercel-api.sh` (API REST): `VERCEL_TOKEN` è un token di progetto, e la CLI di Vercel con lui non funziona. Vercel non è collegato a GitHub, e da una sandbox Neon e Vercel di solito non si raggiungono: si pubblica da qui.

## Mappa

- `app/[lang]/`: le pagine (`w/` voce, `r/` famiglia, `l/` lingua, `radici`, `lingue`, `storie`, `metodo`, `chi-siamo`, `bibliografia`) e `redazione/` (accesso, cruscotto, editor, `azioni.ts`).
- `components/`: `LineaTempo`, `StoriaCarta`, `Indovinello`, `StemmaAdattivo`, `Mappa`, `Ricerca`, `Automatica` (il segno ≈)…
- `lib/`: `dati.ts` (letture), `redazione.ts` (letture della redazione), `storie.ts`, `db.ts` (`query`, `transazione`), `auth/` (Neon Auth), testi in `i18n.ts`, `testi-redazione.ts`, `testi-storie.ts`.
- `db/`: `01_schema.sql`, `02_logica.sql`, `03_seed_pilota.sql`, `05_import_wiktionary.sql`, i test `04` e `06`, e `aggiornamenti/` (file datati).
- `dati/`: il pacchetto dati compresso (TSV di Wiktionary, glosse del Wikizionario, di Wikidata e tradotte, frequenze).
- `import/`: parser (`wiktionary.py`), filtri dei dump e dei dizionari del Perseus (`filtra_perseus.py`), traduzione delle glosse, banco di prova di voci reali (`esempio/`).
- `scripts/`: inizializzazione del database, aggiornamenti, collaudo, copia.

## Il database

Tabelle principali: `lessema` (le voci, con `slug` generato), `ipotesi` (una sola `accolta` per voce), `relazione` (i passaggi), `attestazione`, `glossa`, `definizione` (della redazione o di Claude), `rimando` (le fonti, con posizione), `opera`, `strato` (provenienze e licenze), `frequenza`, `lista_lavoro`, `storico` (firmato), `meta`. Viste materializzate: `mv_famiglia`, `mv_allotropi`, `mv_storie`. Funzioni principali: `scheda()`, `nodo_json()`, `storie()`, `indovinello()`, `importa_wiktionary()`, `pulisci_wiktionary()`, `importa_dizionari()`, `importa_glosse_wikizionario()`, `importa_glosse_aggiuntive()`, `importa_definizioni()`, `importa_stime()`.

Come cambia il database:

1. **Due posti.** La modifica va nel file canonico (`db/01`, `02`, `05`) per le installazioni nuove, e in un file datato di `db/aggiornamenti/` per il database esistente. Il file datato dev’essere ripetibile senza danni: `create or replace`, `if not exists`, aggiornamenti idempotenti.
2. **Gli aggiornamenti si applicano da soli** a ogni build (`scripts/inizializza-db.mjs`), in ordine di nome, dopo l’eventuale primo caricamento. Una vista materializzata si ricrea solo se cambia la versione scritta nel suo commento (vedi `2026-10-31-storie.sql`).
3. **Dati nuovi, nuovo import.** L’impronta del pacchetto `dati/` e di `05_import_wiktionary.sql` sta in `meta`: se cambia, la build rifà l’import in una transazione (import, pulizia, dizionari, glosse, viste), poi svuota le tabelle di appoggio e fa il vacuum. Se fallisce, il database resta com’era e il deploy si ferma. I file del pacchetto si comprimono con `gzip -9 -n`, così l’impronta dipende solo dal contenuto.
4. **Un file datato che contiene una funzione dell’import** va rigenerato dal file canonico, altrimenti riporta la versione vecchia.
5. **Ogni cambiamento di comportamento ha il suo test** in `04` o `06`, e i test girano prima del push.

## Regole che non si violano

- **L’import tocca solo ciò che non è stato toccato:** record con `provenienza` `'wiktionary'` o `'perseus'` e `stato_editoriale = 'importato'`. Un’ipotesi rivista o verificata resta congelata con tutti i suoi passaggi; `pulisci_wiktionary()` e `importa_dizionari()` tolgono solo ciò che nessuno ha toccato (`voce_intatta()`).
- **Tra voci importate l’abbinamento è esatto.** La forma normalizzata abbina solo voci della redazione, mai di Wiktionary o del Perseus (Τύρος, la città, non è τυρός, il formaggio). Una voce del Perseus intatta cede il posto a Wiktionary quando Wiktionary ha la stessa parola.
- **Ogni azione della redazione** passa da `richiediRedattore()` e da `transazione(email, …)`, che firma lo storico. Se cambia un’ipotesi accolta, dopo la risposta si ricalcolano `mv_famiglia`, `mv_allotropi` e `mv_storie` (`after()`).
- **Le glosse italiane hanno un ordine di rango:** redazione, poi Wikizionario, poi Wikidata, poi traduzione automatica (Claude, poi OPUS-MT). Le tradotte portano il segno ≈ (`glossa_automatica`); salvarle nell’editor le rende «riviste».
- **Un’ipotesi verificata ha almeno un’opera della bibliografia che la propone o la accoglie,** e due se la certezza è 4; Wiktionary, Wikizionario, Etymonline e Logeion (opere `in_rete`) non contano. Lo impone `controlla_ipotesi_verificata()` al commit, anche quando cambiano la certezza o le fonti di un’ipotesi già verificata; l’editor lo dice con gli esiti `servono-fonti` e `servono-due-fonti`.
- **Le storie usano solo passaggi con certezza 3 o 4,** e mai archi «sospetti» (una forma ricostruita che discende da un’altra famiglia linguistica).
- **Gli indirizzi li calcola solo `slug_di()`.** Cambiarla, o cambiare `norm()`, cambia gli URL: dopo il lancio pubblico serve una migrazione con i reindirizzamenti.

## Interfaccia

- **Componenti:** server per default; client solo per l’interazione (`'use client'`). A un componente client non si passano funzioni: solo dati serializzabili.
- **HTML valido:** niente `<p>` dentro `<p>` (una `Catena` è un paragrafo).
- **Server actions:** `redirect()` va fuori dal `try/catch`, perché funziona lanciando un’eccezione.
- **Testi:** nei file di testi, mai sparsi nei componenti. Nel testo per il lettore apostrofo tipografico (’) e caporali (« »); nel codice apici diritti.
- **Colori:** variabili CSS in `app/globals.css`. La classe `r-<ramo>` imposta `--pig`, il colore del ramo linguistico.
- **Pagine dinamiche:** `storie` e `redazione` sono `force-dynamic`; le voci usano ISR (`revalidate`).
- **Stemma:** i nomi propri da cui non derivano parole comuni restano nascosti finché il lettore non li chiede (`nomiNascondibili()` in `lib/albero.ts`); oltre 12 figli se ne disegnano 6, quelli con i rami più grandi, e gli altri vanno in una lista a tendina con il filtro (`dividiFigli()`), un `<details>` nello stemma verticale.
- **Prefetch:** i link negli elenchi (`VoceLink`, iniziali, pagine) hanno `prefetch={false}`. Con il valore predefinito ogni link visibile fa calcolare al server una pagina intera, e su 540 mila voci quasi nessuna è in cache.
- **Pagine pesanti:** prima di pubblicare un elenco, misura il peso dell’HTML e il tempo della prima visita (`next build` e `next start` in locale, con `NEON_AUTH_COOKIE_SECRET` di prova).

## Trappole già incontrate

- **Wiktionary cambia i modelli etimologici:** dal 2026 molte voci (22 mila latine) usano `{{ety}}`/`{{etymon}}` (`:inh|la:aquila`, `:af|fābula|-lus`). `filtra.py` li converte nel modello classico (`da_ety()`), solo dove un modello classico non dà già un etimo (`porta_etimo()`). Il registro del filtro conta le voci lette «da {{ety}}» e le cause dei lemmi senza etimologia, con i «modelli non letti più frequenti»: se ne compare uno nuovo, si guardano esempi grezzi con `DIAGNOSI_MODELLI=nome` o `DIAGNOSI_PAROLE=parola` nel workflow Dati.
- **Il lessico di frequenza conta forme, non lemmi,** e viene dai sottotitoli: *stia*, *sulla*, *era* sono forme di altre parole, e ci sono molte volgarità. Filtrare prima di usarlo per scegliere parole.
- **Ricorsioni sul grafo:** si visitano le parole, non i percorsi (`union`, non `union all` con l’array del cammino). I composti dotti (*-logia*, *-grafia*) creano migliaia di percorsi convergenti, e contarli bloccava `mv_famiglia`.
- **Da una sandbox la porta 5432 di Neon può essere chiusa:** gli script ricadono sul driver WebSocket `@neondatabase/serverless`.
- **Wiktionary scrive l’incertezza nel testo** («possibly», «uncertain»): il parser la legge senza le glosse tra virgolette, perché «obscure» in una glossa non è un dubbio.
- **Il Postgres locale della sandbox si ferma spesso:** se una query dice «connection refused», riavvialo.
- **Lo spazio su Neon (1 GB nel piano gratuito, dato di Giovanni del 6 novembre 2026; prima era 0,5):** l’import scrive solo ciò che cambia, perché ogni riga riscritta lascia una copia morta fino al vacuum; un test controlla lo `xmin` delle righe. Prima di un import grande misura in locale (`[db] spazio occupato` nel registro della build).
- **Una lingua nuova cambia le glosse delle voci che ci sono già:** le menzioni inglesi (`t=bee`) superavano nei voti la glossa pubblicata (*apis*, *vacca*, \*h₁es-), e 249 definizioni di Opus, legate alla glossa da cui sono nate, cadevano. `scegli_glossa()` tiene la glossa già pubblicata se è ancora tra le candidate (`PRECEDENTI`, il pacchetto di `main`); dopo un import si controlla che `[db] definizioni` non ne tolga.
- **Durante l’import il database passa per quasi il doppio della sua dimensione finale** (con l’inglese 1.000 MB in locale, 571 a import finito): tabelle d’appoggio e temporanee, che su Neon stanno sul disco locale del calcolo. Le tabelle d’appoggio sono tutte unlogged; i file normali arrivano a 584 MB.
- **Una sottoquery correlata per riga su un import grande** (`importa_stime()`, 108 mila stime) costava dieci minuti: join con tabelle temporanee piccole e indicizzate, e `analyze`. I secondi di ogni passo sono nel registro della build.
- **Un confronto per forma normalizzata su molte righe** (`lemma_norm = norm(x)`) usa l’indice a trigrammi una riga alla volta e diventa lentissimo: confronta con un insieme piccolo e precalcolato (vedi `importa_dizionari()`).

## Lavoro editoriale

- **Le norme redazionali** sono una bozza in un Claude Doc di Giovanni («Stirps — Norme redazionali (bozza)»). Restano aperte quattro questioni: l’italiano antico, i dialetti, chi corregge una voce verificata da altri, la licenza dei testi della redazione. Non decidere al suo posto: proponi.
- **Le cinque questioni decise il 1° novembre 2026:**
  - per «verificata» basta un’opera della bibliografia che propone o accoglie l’ipotesi, e ne servono due per la certezza 4; le opere in rete non contano;
  - la variante è un tipo di passaggio solo dentro una lingua; una forma dialettale è una voce del suo dialetto, collegata con eredità o prestito;
  - il lemma di una ricostruzione segue la notazione di Wiktionary, e la forma della fonte va nel campo «s.v.» della citazione;
  - la data del passaggio sta nella catena accanto al tipo, distinta dalla prima attestazione;
  - le note si scrivono solo in italiano.
- **Le liste di lavoro:** `prime-100` (cento voci scelte per provenienza, da `db/aggiornamenti/2026-10-31-prime-100.sql`) e `catene-da-sistemare` (ricalcolata a ogni deploy).

## Prossimi passi

- Pubblicare le norme sul sito, accanto al Metodo, quando Giovanni le avrà approvate.
- Ritocchi all’editor che emergeranno dalle prime 100.
- Un nuovo filtro del dump italiano che conservi i modelli di menzione (`m`, `l`), per le etimologie scritte solo nel testo («From the verb segare»).
- Licenza, «Chi siamo», dominio, mappa del sito, «come citare questa voce».
- Il dataset su Zenodo con DOI.
- La traduzione automatica delle note per il sito inglese, segnata ≈ come le glosse: le note si scrivono solo in italiano, e oggi il sito inglese le mostra con «(in Italian)».
