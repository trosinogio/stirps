# Stirps — app web

App Next.js di Stirps, il dizionario etimologico per radici. Legge il database Postgres attraverso tre funzioni SQL che restituiscono JSON pronto per la pagina:

- `scheda(slug, anteprima, lingua)`: una voce completa;
- `indice(lingua, anteprima)`: la pagina iniziale;
- `cerca_universale(q, lingua)`: la ricerca per lemma, in qualunque scrittura, e per significato.

L'interfaccia è in italiano e in inglese (`/it`, `/en`). Le pagine si generano alla prima visita e restano in cache per cinque minuti (ISR).

Collaudata con Next.js 16.4.2, React 19.3.1 e PostgreSQL 16: build di produzione riuscita, 82 test SQL sul seme e 33 sull'import superati, pagine verificate nel browser in entrambe le lingue, su desktop e telefono.

## Struttura

```
app/[lang]/page.tsx              pagina iniziale: radice in evidenza, radici, capostipiti, lingue
app/[lang]/r/[...slug]/page.tsx  famiglia di una radice: stemma, lingue, mappa
app/[lang]/w/[...slug]/page.tsx  voce: catena, ipotesi e fonti, sorelle, allotropi, viaggio, attestazioni
app/[lang]/l/[codice]/[[...iniziale]]/page.tsx   parole di una lingua, per iniziale
app/[lang]/radici/[[...resto]]/page.tsx         l’indice delle radici, per lingua della radice, e i capostipiti provvisori, a pagine
app/[lang]/lingue/page.tsx                      tutte le lingue, per famiglia e ramo
app/[lang]/storie, metodo, chi-siamo            storie di parole, metodo, chi siamo
app/[lang]/bibliografia/page.tsx                le opere di riferimento, per ambito
components/Marchio.tsx                          il logotipo: il segno di radice con la barra sopra il nome
components/Navigazione.tsx                      la barra di navigazione, con la sezione corrente
components/AlberoRami.tsx                       lo stemma delle lingue del dizionario, nella vetrina
lib/contenuti.ts                                i testi di Metodo e Chi siamo
app/[lang]/redazione/                           redazione: accesso, cruscotto, editor della voce, azioni
lib/auth/, proxy.ts                             Neon Auth: sessione, ruolo «redattore», protezione delle pagine
lib/redazione.ts, lib/testi-redazione.ts        interrogazioni e testi della redazione
lib/percorsi.ts                                 storie di parole ed esempi della pagina iniziale
app/api/cerca/route.ts           ricerca per la casella in testata
components/                      stemma (verticale sul server, orizzontale nel browser), mappa, ricerca
lib/i18n.ts                      testi dell'interfaccia: una sola fonte, anche per il prototipo statico
lib/dati.ts                      le chiamate SQL
db/                              schema, logica, seme pilota, import e collaudi
import/                          importatore da Wiktionary (Python), con banco di prova e rapporto
dati/                            etimologie, attestazioni, glosse italiane e frequenze già analizzate, caricate al primo deploy (CC BY-SA 4.0)
scripts/inizializza-db.mjs       prepara il database prima della build, se è vuoto
scripts/pubblica-vercel.sh       pubblica su Vercel dalla riga di comando
scripts/pubblica-vercel-api.sh   pubblica su Vercel con l'API REST: lo usa il workflow Pubblica
neon.ts, .neon                   servizi e collegamento del progetto Neon (neon init)
.agents/skills/                  skill di Neon per gli agenti di programmazione
```

Indirizzi: `/it/r/ine-pro/ped` (sintesi della famiglia), `/it/r/ine-pro/ped/stemma`, `/it/r/ine-pro/ped/lingue`, `/it/r/ine-pro/ped/mappa`, `/en/w/it/fegato` (voce), `/en/l/it/c` (le parole italiane con la C), `/it/radici` (le radici indoeuropee, a pagine), `/it/radici/gem-pro` (quelle di un’altra lingua), `/it/radici/tutte` e `/it/radici/provvisorie`.

Le etimologie hanno cinque provenienze, e la scheda dice quale: Wiktionary (con le lingue di chiusura, di cui entrano solo le voci che le catene raggiungono), il Lewis & Short e l’LSJ (il tag `<etym>`, citati come fonte, certezza 3), il Wikizionario per le voci italiane («dal latino avarus», «composto da ago e puntura», citato come fonte), l’«Analisi della forma» (un prefisso, un suffisso o un composto di parole note: καταδάπτω = κατα- + δάπτω, σκοτίζω = σκότος + -ίζω; certezza 2, senza fonte) e la redazione. Le prime quattro sono importate e si rifanno a ogni import; nessuna tocca una voce che ha già un’etimologia di un’altra provenienza.

L’indice di una lingua ha due sezioni: le parole, e i nomi propri e derivati, cioè i nomi e ogni altra voce con la maiuscola nelle lingue che scrivono i nomi comuni con la minuscola (*Romanus*, *Danish*; non il tedesco).

La lista di lavoro `catene-da-sistemare` si ricalcola a ogni deploy e ha cinque gruppi: le parole la cui catena salta subito a una radice, i passaggi sospetti (*torre*: τύρρις < φιλία), le catene che arrivano a una radice diversa da quella che Wiktionary dichiara, e le parole italiane e francesi su cui Wiktionary e il Wikizionario, o il Wiktionnaire, discordano. Si ricalcolano anche `senza-etimologia` (le parole comuni senza nessuna etimologia) e `aree-da-rivedere` (cinque radici per area, sempre le stesse: l’editor di una radice ha la sezione «Area di significato», e il cruscotto conta quante aree di Claude la redazione conferma).

Le norme redazionali hanno una pagina sul sito (`/it/norme`, testi in `NORME` di `lib/contenuti.ts`), versione per il lettore della bozza nel Claude Doc; le questioni aperte vi stanno «in discussione».

Il pacchetto dati va su Zenodo con il workflow Zenodo (a mano): `scripts/pacchetto_zenodo.py` fa lo zip dei file di `dati/` con le colonne (`COLONNE.txt`), la licenza e le impronte, `scripts/deposito_zenodo.py` lo deposita con i metadati di `.zenodo.json`, in bozza e per default sulla sandbox. Servono i segreti `ZENODO_SANDBOX_TOKEN` e `ZENODO_TOKEN`; la citazione è in `CITATION.cff`.

L’indice delle radici (`elenco_radici()`) mostra sotto ogni radice fino a quattro parole della lingua del lettore che ne discendono, le più usate per prime. La pagina di una famiglia si apre sulla sintesi: le parole della lingua del lettore, i rami principali (i figli diretti della radice, con quante parole portano) e le parole più vicine alla radice in ogni altra lingua; lo stemma si disegna fino a 150 parole (`LIMITE_DISEGNO`), oltre mostra i primi due livelli e ogni ramo ha la sua pagina.

## In locale

Servono Node 20.9 o successivo, PostgreSQL 14 o successivo e `psql`.

```bash
cp .env.example .env.local      # imposta DATABASE_URL; ANTEPRIMA=1 per vedere il seme in bozza
npm install
npm run db:init                 # schema, logica, seme pilota e tabelle d'import
npm run db:test                 # 82 test sul seme: si ferma al primo errore
npm run db:import               # etimologie di Wiktionary chiuse su latino e francese antico, glosse del Wikizionario: circa 4 minuti
npm run db:test-import          # 33 test dell'import, su un database con il solo seme
npm run dev                     # http://localhost:3000
```

L'import richiede anche `python3` e `curl`; le regole sono in `import/LEGGIMI.md`, i risultati in `import/RAPPORTO.md`. Senza import il sito mostra il solo seme pilota.

## Storie

La pagina `/it/storie` cambia a ogni visita. Le storie della redazione, scritte a mano (`lib/percorsi.ts`), stanno in fondo; sopra, le storie che il dizionario trova da sé nelle sue catene (`db/aggiornamenti/2026-10-31-storie.sql`). La vista `mv_storie` raccoglie i candidati tra le parole italiane d'uso comune, cioè le prime 30.000 per frequenza, e li divide in quattro tipi:

- **Due strade:** allotropi con un antenato attestato, come *esame* e *sciame* dal latino *examen*.
- **Parenti lontani:** parole della stessa famiglia indoeuropea arrivate per strade diverse e che non si somigliano, come *luna* e *lince* da \*lewk-.
- **Lungo viaggio:** parole passate per lingue di più famiglie o di più rami, o per almeno cinque lingue attestate, come *azzurro* dal persiano attraverso l'arabo e il latino.
- **Una radice, tante parole:** radici con almeno otto parole italiane d'uso comune.

Le storie seguono solo archi plausibili. Una forma ricostruita che «discende» da una lingua di un'altra famiglia è un confronto letto come origine, e le storie la scartano.

- **Scelta:** `storie(lingua, seme, n, tipo)` prende le migliori 300 di ogni tipo, le mescola secondo il seme e alterna i tipi. Lo stesso seme dà le stesse storie, quindi un link con `?s=` le ritrova.
- **La storia del giorno:** cambia a mezzanotte, e ogni giorno è di un tipo diverso. Compare anche nella home.
- **Il gioco:** `indovinello()` propone una parola, il suo parente vero e due parole d'uso comune che non lo sono.
- **Il testo:** titoli e racconti si compongono dalle catene vere (lingue attraversate, tipo di passaggio, glosse) in `components/StoriaCarta.tsx`, con tre varianti per tipo.
- **Aggiornamento:** `mv_storie` si ricalcola dopo ogni nuovo import e dopo le modifiche della redazione che cambiano un'ipotesi accolta.

## Glosse italiane

Ogni parola ha al più una glossa italiana. Le fonti, in ordine di rango:

1. la redazione;
2. il Wikizionario (CC BY-SA 4.0);
3. le definizioni dei lessemi di Wikidata (CC0), per le parole italiane senza voce nel Wikizionario: solo con la stessa parte del discorso, senza omografi e senza «etichette» con la maiuscola;
4. la traduzione automatica delle glosse inglesi di Wiktionary e dei dizionari del Perseus: prima quella di Claude, poi quella di OPUS-MT.

Una fonte di rango più basso non scavalca mai una più alta. Una glossa importata di Wikidata o della traduzione lascia il posto a quella del Wikizionario quando arriva; `importa_glosse_aggiuntive()` toglie quelle che non valgono più e aggiunge le nuove, lasciando dove sono le altre. Quelle riviste dalla redazione restano.

La traduzione automatica (`import/traduci_glosse.py`) usa un modello OPUS-MT di Argos Translate con CTranslate2, sul processore, senza servizi esterni. Lavora un senso alla volta, e tiene un senso solo se passa tutti i controlli:

- la traduzione di ritorno, con il modello italiano → inglese, ridà questo senso o un altro senso della stessa glossa;
- concorda con un dizionario rovesciato, ricavato dalle glosse inglesi delle parole italiane del dizionario («honey» → *miele*, non «tesoro»);
- ogni parola italiana esiste, nel lessico di frequenza o tra i lemmi del dizionario;
- un verbo inglese diventa un infinito;
- non restano parole inglesi e non compaiono parole volgari.

Su un campione casuale di cento traduzioni ne restano sbagliate circa sette. Per questo ogni glossa tradotta porta il segno ≈ (`components/Automatica.tsx`, `glossa_automatica` in `nodo_json` e nella scheda); le altre glosse restano in inglese.

Per rigenerare i due file del pacchetto dati:

```
curl -s https://dumps.wikimedia.org/wikidatawiki/entities/latest-lexemes.json.bz2 | bzcat | python3 import/filtra_wikidata.py wikidata_it.tsv
pip install ctranslate2 sentencepiece
curl -sLO https://argos-net.com/v1/translate-en_it-1_0.argosmodel && unzip translate-en_it-1_0.argosmodel   # → en_it/
curl -sLO https://argos-net.com/v1/translate-it_en-1_0.argosmodel && unzip translate-it_en-1_0.argosmodel   # → it_en/
python3 import/traduci_glosse.py lessemi.tsv en_it glosse_tradotte.tsv --chiavi chiavi.txt \
        --vocabolario dati/frequenze_it.tsv.gz,lessemi.tsv
```

`chiavi.txt` elenca le voci straniere senza glossa italiana. Con `--parte 1/3` il lavoro si divide; un processore traduce circa trenta glosse al secondo.

## Traduzioni e definizioni di Claude

Oltre alla glossa, una voce può avere una **definizione** (tabella `definizione`, una per lingua): della redazione, o scritta da Claude (strato `claude`, con il nome del modello in `modello`). Le scrive `import/definisci.py` con la Batch API di Anthropic e l'output strutturato: per ogni voce una traduzione breve (la glossa, che prende il posto di quella di OPUS-MT) e una definizione, vuote se il modello non conosce la parola con sicurezza. Il modello non scrive etimologie, date né autori: il dizionario li ha già, con le fonti.

- **Le radici** (le 4.662 della pagina «Radici») si definiscono con Opus 5.5, a partire dalla glossa della radice e dalle glosse dei discendenti più vicini, così il significato si ancora alla famiglia. Le altre voci aspettano il confronto tra Haiku, Sonnet e Opus su un campione di 300 (`import/claude/campione.jsonl.gz`).
- **Il workflow Definizioni** (`.github/workflows/definizioni.yml`) parte con un push su un ramo `definizioni-*` che cambia `import/claude/lotti.conf`, e serve il segreto `ANTHROPIC_API_KEY`. Manda solo le voci che non hanno ancora un risultato e salva l'id di ogni batch con le chiavi delle sue richieste: un'esecuzione interrotta lo riprende senza ripagare. I risultati per il dizionario vanno in `dati/definizioni.tsv.gz`, quelli dei confronti in `import/claude/esiti/`.
- **Nel database** `importa_definizioni()`, dopo `importa_glosse_aggiuntive()`, porta le definizioni per differenza. Valgono solo per la glossa da cui sono nate (colonna `originale`); una definizione della redazione o rivista non si tocca. La pagina della voce e quella della famiglia le mostrano sotto la glossa, con il segno ≈ e il nome del modello finché nessuno le rivede; sul sito inglese restano in italiano, dichiarate come tali.
- **Per rifare i lotti** da una copia locale del database: `python3 import/definisci.py estrai postgres://…/stirps radici import/claude/radici.jsonl.gz`.

## Liste di lavoro: le prime 100

La tabella `lista_lavoro` raccoglie le liste di lavoro della redazione: quali voci verificare, in che ordine, con un suggerimento per ciascuna. La prima lista, `prime-100`, si scrive con `db/aggiornamenti/2026-10-31-prime-100.sql`, a ogni deploy. Contiene cento parole d'uso comune scelte per provenienza, le stesse del file `stirps-prime-100.xlsx`.

Lo stato non sta nella lista: una voce è verificata quando lo è la sua ipotesi accolta.

- **Nel cruscotto della redazione:** la sezione «Prime 100» mostra l'avanzamento, in tutto e per gruppo, e per ogni voce lo stato, le fonti e le date.
- **Nell'editor:** una voce della lista mostra il suo numero, il gruppo, che cosa controllare e il link alla prossima voce non ancora verificata.

Una seconda lista, `catene-da-sistemare` (`db/aggiornamenti/2026-10-31-catene-da-sistemare.sql`), si ricalcola dai dati a ogni deploy. Raccoglie le parole italiane la cui catena va subito a una radice ricostruita (\*sek-), senza tappe, in ordine d'uso. Una catena sistemata esce dalla lista da sola.

## Redazione

L'area di redazione è su `/it/redazione` (e `/en/redazione`). L'accesso passa da Neon Auth, cioè Better Auth gestito da Neon: utenti e sessioni stanno nello schema `neon_auth` dello stesso database.

- **Chi entra.** Le registrazioni pubbliche sono chiuse. I redattori li crea l'amministratore con `neon neon-auth user create --email … --name …` e ricevono il ruolo con `neon neon-auth user set-role <id> --roles redattore`. Si entra con un codice di sei cifre inviato per email, oppure con una password.
- **Dove si controlla.** `proxy.ts` è la prima barriera; ogni pagina e ogni azione ricontrollano sessione e ruolo prima di leggere o modificare (`lib/auth/redattore.ts`).
- **Che cosa si fa.** La coda di verifica parte dalle parole più usate. Per ogni voce si regolano lo stato e la glossa italiana. Per ogni ipotesi si regolano stato, certezza, nota e fonti, cioè opera, «s.v.», luogo e posizione. «Segna come verificata» richiede almeno un'opera della bibliografia che propone o accoglie l'ipotesi, e due per la certezza 4; Wiktionary, Wikizionario, Etymonline e Logeion non contano. Il database lo impone comunque, anche quando cambiano la certezza o le fonti di un'ipotesi già verificata (`controlla_ipotesi_verificata()`, `opere_a_sostegno()`).
- **Catene.** Ogni ipotesi mostra i suoi passaggi, che si modificano o si tolgono. Un etimo si aggiunge scegliendolo tra le voci (la ricerca è la stessa del sito) o creando una voce nuova, ricostruita o no; se la lingua e il lemma esistono già, si usa la voce esistente. Si possono scrivere ipotesi della redazione, con origine, stato e certezza. Il database rifiuta i cicli e i doppioni, e l'editor lo dice in chiaro.
- **Date.** Le prime attestazioni hanno anno, precisione (esatta, circa, prima del, dopo il, intervallo, secolo), testo, tipo di testimonianza e, facoltativa, la fonte con posizione «attesta». La prima attestazione di ogni parola compare nella catena della voce pubblica. Anche un passaggio può avere la sua data, se una fonte la dà: nella catena compare accanto al tipo di passaggio («prestito, sec. XII»), distinta dalla prima attestazione, che resta accanto alla parola.
- **Firma.** Ogni modifica entra nello storico con l'indirizzo del redattore (`app.utente`). Le pagine pubbliche si aggiornano subito; se cambia l'ipotesi accolta, famiglie e allotropi si ricalcolano dopo la risposta.
- **Variabili.** `NEON_AUTH_BASE_URL` arriva da `neon deploy` con `auth: true` in `neon.ts`; `NEON_AUTH_COOKIE_SECRET` va generata (`openssl rand -base64 32`) e impostata anche su Vercel.

## Linea del tempo

Ogni voce con un'etimologia ha la sua linea del tempo, disegnata sul server in SVG (`components/LineaTempo.tsx`). Ogni nodo della catena è una riga, e le righe vanno dalla generazione più antica alla parola della voce.

- **Fascia:** il periodo della lingua, tratteggiata se la lingua è ricostruita. I periodi sono convenzionali e approssimativi: per le lingue attestate dalla prima testimonianza scritta, per le protolingue gli intervalli di solito citati. Stanno in `lingua.anno_da` e `lingua.anno_a`, e coprono il 98,8% dei nodi antenati delle parole italiane.
- **Punto pieno:** la prima attestazione datata, inserita dalla redazione o importata; una barra se la data è un secolo o un intervallo.
- **Cerchio vuoto:** per le parole senza data, il momento più antico possibile, cioè l'inizio del periodo della lingua ma non prima dell'etimo. È un limite inferiore, non una data.
- **Frecce:** partono dal punto della fascia dell'etimo più vicino alla nascita della parola nuova. Sono continue per eredità e formazione, tratteggiate per i prestiti, a puntini per i legami incerti.
- **Scala:** logaritmica sugli anni prima di oggi, perché le date si addensano negli ultimi secoli. La finestra si adatta alla catena.
- **Telefoni:** il grafico scorre e parte da destra, dalla parola di oggi.

## Aggiornare i dati

Il pacchetto `dati/*.tsv.gz` ha un'impronta (SHA-256 dei file e della logica d'import, `db/05_import_wiktionary.sql`), registrata nella tabella `meta`. A ogni deploy `scripts/inizializza-db.mjs` applica prima gli aggiornamenti datati; poi, se l'impronta è cambiata, rifà l'import in una sola transazione:

1. carica le tabelle di appoggio;
2. esegue `importa_wiktionary()`, che non tocca nulla di ciò che la redazione ha rivisto o verificato, nemmeno gli archi rimasti «importato» delle sue ipotesi;
3. esegue `pulisci_wiktionary()`, che toglie ipotesi e voci che Wiktionary non dà più se nessuno le ha toccate, riattiva le ipotesi accolte e toglie i numeri di omografo diventati inutili;
4. esegue `importa_dizionari()`, che aggiunge i lemmi latini e greci del Lewis & Short e del Liddell–Scott–Jones che Wiktionary non ha (strato `perseus`, vedi `import/LEGGIMI.md`);
5. aggiorna glosse e viste.

Se qualcosa va storto, il database resta com'era e il deploy si ferma. Dopo il commit svuota le tabelle di appoggio, fa il vacuum e scrive nel registro lo spazio occupato.

**Lo spazio.** Il piano gratuito di Neon ha 1 GB (era 0,5 GB). L'import scrive solo ciò che cambia: voci, ipotesi, archi e glosse uguali restano dove sono, perché in Postgres ogni riga riscritta lascia una copia morta fino al vacuum. Prima ogni reimport riscriveva quasi tutto. Con latino e greco completi (novembre 2026, 293 mila voci) un caricamento da zero occupa circa 290 MB, e un reimport con gli stessi dati non lo fa crescere.

Prima di un deploy che cambia i dati conviene una copia del ramo di produzione, che su Neon è istantanea:

```
neon branches create --name backup-AAAA-MM-GG --parent production --no-compute
```

Per tornare indietro: `neon branches restore production backup-AAAA-MM-GG`.

## Aggiornare un database già caricato

`scripts/inizializza-db.mjs` carica tutto da zero la prima volta. Le modifiche successive allo schema, alle funzioni o ai dati di riferimento sono file datati in `db/aggiornamenti/`, tutti ripetibili senza danni. Lo script li applica in ordine di data a ogni avvio, quindi anche a ogni build su Vercel: un aggiornamento arriva in produzione con il deploy. Per applicarli a mano, ciascuno in una transazione:

```
node scripts/applica-sql.mjs db/aggiornamenti/2026-10-30-periodi-lingue.sql
```

## Indirizzi delle voci

L'indirizzo di una voce è `lingua/forma`: `it/fegato`, `grc/obelos`, `ine-pro/nokwts`. Lo calcola la funzione `slug_di()` di `db/01_schema.sql`, l'unica fonte della regola: la usano la colonna `slug` e i controlli dell'import.

- **La forma:** quella normalizzata da `norm()`, minuscola, senza diacritici e in caratteri latini dove si può (*pnéwmə* → `pnewme`, *ʕarab* → `arab`). Le parole greche senza traslitterazione la ricevono dall'import.
- **Gli affissi tengono il trattino:** `it/foto-`, `it/-grafia`, così non coincidono con le parole *foto* e *grafia*. Le radici ricostruite no: `ine-pro/sek`.
- **Gli omografi** hanno un numero: `it/zefiro-2`.

Cambiare la regola cambia gli indirizzi. Prima del lancio si ricarica il database da zero (ottobre 2026: schema `public` azzerato, `neon_auth` intatto); dopo il lancio servirà una migrazione con i reindirizzamenti.

**Le famiglie** (`mv_famiglia`) si calcolano visitando le parole, non i percorsi: ogni parola entra una volta per profondità. Con i composti dotti (*-logia*, *-grafia*) i percorsi convergenti sono migliaia, e contarli uno per uno bloccava il calcolo.

## GitHub, collaudo e copie

Il codice vive in un repository GitHub privato. Vercel non è collegato a GitHub: il sito lo pubblica il workflow «Pubblica», dopo ogni collaudo riuscito su `main`.

- **Pubblicazione** (`.github/workflows/pubblica.yml`): parte dopo ogni collaudo riuscito su `main`, oppure a mano dalla scheda Actions.
  - Crea su Neon un ramo di riserva (`backup-AAAA-MM-GG-HHMM`, senza compute, che scade dopo 30 giorni).
  - Pubblica su Vercel con `scripts/pubblica-vercel-api.sh`, che usa l'API REST e non la CLI: il token è un token di progetto (`vcp_…`), che vede il progetto ma non l'utente, e la CLI con lui si ferma («User not found»). La build applica gli aggiornamenti datati.
  - Controlla che gli aggiornamenti siano nel database, elenca le ipotesi verificate che non rispettano le norme e riporta lo spazio occupato (il piano gratuito di Neon ha 1 GB).
  - Se un passo fallisce, i successivi non partono.
  - Richiede i segreti `VERCEL_TOKEN`, `NEON_API_KEY` e `DATABASE_URL_UNPOOLED`.
- **Dati** (`.github/workflows/dati.yml`): rigenera il pacchetto `dati/` con un push su un ramo `dati-*`, oppure a mano.
  - Scarica i dump di Kaikki e analizza le etimologie, con latino e greco interi (`import/importa.sh`, `SOLO_ANALISI=1`).
  - Aggiunge i lemmi del Lewis & Short e dell'LSJ che Wiktionary non ha, dai file TEI del Perseus fissati a un commit (`dati/dizionari.tsv.gz`).
  - Traduce solo le glosse delle voci nuove e compone `dati/*.tsv.gz` con `gzip -9 -n`.
  - Rimette il pacchetto sullo stesso ramo, con un commit.
  - Da una sandbox Kaikki di solito non si raggiunge: si passa da qui. Con il merge su `main` la pubblicazione rifà l'import, dopo il ramo di riserva.
- **Collaudo** (`.github/workflows/collaudo.yml`): a ogni push controlla i tipi TypeScript e fa girare `scripts/collauda.sh` su un Postgres di prova, cioè gli 89 test del seme e i 77 dell'import. In locale: `PGURL=postgres://utente:password@localhost:5432 scripts/collauda.sh`.
- **Copia della redazione** (`.github/workflows/copia-redazione.yml`): ogni notte `scripts/esporta-redazione.mjs` esporta tutto ciò che la redazione ha scritto o toccato (voci, ipotesi, passaggi, date, glosse, fonti, storico). Le righe sono JSON, ciascuna con gli indirizzi delle voci collegate. La copia va nel ramo `copia-redazione`, e ogni notte con dei cambiamenti diventa un commit. Il workflow richiede il segreto `DATABASE_URL_UNPOOLED` del repository, e si può lanciare a mano dalla scheda Actions.
- **Ripristino:** la prima via è un ramo di Neon (`neon branches restore`); la seconda è la copia, leggibile e indipendente dagli identificativi del database.

## Su Vercel con Neon

Pubblicata su https://dizionario-etimologico.vercel.app (progetto Neon `aged-truth-35630140`, ramo `production`, Francoforte).

1. **Neon.** Il progetto è collegato da `.neon` e descritto da `neon.ts` (`neon init`). `neon deploy` applica `neon.ts` e scarica in `.env.local` due variabili: `DATABASE_URL` (pooled, per l'app) e `DATABASE_URL_UNPOOLED` (diretta, per i caricamenti).
2. **Driver.** L'app usa `node-postgres` con la stringa pooled e `attachDatabasePool` di `@vercel/functions`, come raccomandano le skill di Neon per Vercel con Fluid compute (`lib/db.ts`). La variabile si legge con `parseEnv` di `@neon/env`. Sulle reti che chiudono la porta 5432, `NEON_WEBSOCKET=1` fa passare lo stesso pool dal driver serverless di Neon via WebSocket; su Vercel non va impostata.
3. **Vercel.** Variabili di produzione: `DATABASE_URL`, `DATABASE_URL_UNPOOLED` e `ANTEPRIMA=1`, finché i contenuti sono in bozza. Le funzioni girano a Francoforte (`vercel.json`), accanto al database. `.vercelignore` tiene fuori dal caricamento `.env.local` e i file di lavoro.
4. **Primo deploy.** La build prepara da sola il database se è vuoto (`scripts/inizializza-db.mjs`): schema, seme pilota, etimologie di Wiktionary e glosse italiane del Wikizionario, dai file in `dati/`. Usa la stringa diretta, legge anche `.env.local`, e dove la porta 5432 è chiusa ripiega sul WebSocket di Neon. Ai deploy successivi trova il database pronto e non lo tocca.

Per aggiornare le etimologie si rilancia l'import completo con `DATABASE_URL="…" npm run db:import` (vedi `import/LEGGIMI.md`).

Il piano Hobby di Vercel è riservato all'uso non commerciale.

## Le scelte

- **Una query per pagina.** Il database restituisce la voce già composta e localizzata; il frontend non ricalcola cognati, allotropi o catene.
- **Stemma progressivo.** Il server genera lo stemma verticale, leggibile anche senza JavaScript e dai motori di ricerca. Su schermo largo il browser lo sostituisce con lo stemma orizzontale interattivo.
- **Bozze protette.** Senza `ANTEPRIMA=1` restano visibili solo le voci importate, riviste o verificate, e le catene si fermano dove un antenato è in bozza.
- **Lingue dichiarate.** Se una glossa o una nota non esiste nella lingua dell'interfaccia, la pagina mostra quella disponibile e dice in che lingua è.
- **Fonti dichiarate.** Un'ipotesi importata mostra lo strato da cui viene e la sua licenza; i dati di Wiktionary e del Perseus restano CC BY-SA 4.0.
- **Pronta per la scala.** Le famiglie sono precalcolate (`mv_famiglia`), la pagina iniziale mostra le radici più ampie e rimanda agli elenchi completi, le lingue si sfogliano per iniziale secondo il loro alfabeto (23 lettere latine, 24 greche), oltre le 2000 parole per le prime due lettere, e i gruppi oltre le 500 voci in pagine con le parole guida; i nomi propri hanno un indice a parte. Le iniziali sono colonne generate e indicizzate di `lessema` (`chiave_indice`, `nome_proprio`). I link alle voci non si prefetchano: un elenco ne ha migliaia, e ognuno farebbe calcolare una pagina al server. Dopo un import o una modifica si rinfrescano `mv_allotropi` e `mv_famiglia`.

## Aggiungere una lingua d'interfaccia

1. Aggiungere il codice a `LINGUE_INTERFACCIA` e tradurre un blocco in `lib/i18n.ts`.
2. Inserire le glosse nella tabella `glossa` e le etichette dei vocabolari in `etichetta_lingua`.

Finché le glosse mancano, la pagina mostra quelle di base e le dichiara.

## Il prototipo statico

Il prototipo pubblicato (https://claude.ai/artifact/EjCxAgGZw1eBKiM9ea6UQi) usa gli stessi testi e lo stesso JSON, incorporati nella pagina: serve per provare l'interfaccia senza database.
