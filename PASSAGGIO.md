# Passaggio di sessione (13 novembre 2026)

Per la sessione che riprende il lavoro. Leggi prima `CLAUDE.md` (le regole del progetto), poi questo file: qui c'è solo
ciò che `CLAUDE.md` non dice (lo stato del lavoro, le abitudini con Giovanni, le ricette pratiche, le cose aperte).
Questo file sta solo sul ramo `passaggio` e non va unito a `main`.

## Dove siamo

- **In produzione** (https://dizionario-etimologico.vercel.app) ci sono la PR #23 (8 novembre) e la PR #24
  (13 novembre).
  - PR #23: analisi di un testo, numerali, ipotesi discusse, linea del senso, glosse degli omografi, traslitterazioni
    finte, Wiktionnaire, norme sul sito, aree delle radici nell'editor, strumenti dello stemma, file per Zenodo.
    Dopo la #23: database 929 MB su 1.024, 558.507 voci.
  - PR #24: le glosse dei numerali italiani; *cinque* aveva «cardinale» da Wikidata.
- **Da controllare subito:** la PR #24 è stata unita il 13 novembre (commit `ac5f03c`).
  1. Il collaudo è riuscito. Leggi l'esito del workflow «Pubblica» su `main` (annotazioni Spazio, Controllo, Deploy,
     Ramo di riserva):
     `gh api "repos/trosinogio/stirps/actions/runs?branch=main&per_page=6"`, poi
     `gh api repos/trosinogio/stirps/check-runs/<id del job>/annotations`.
  2. Controlla sul sito che `/it/w/it/cinque` mostri «numero naturale che segue quattro e precede sei», e così
     *quattro*, *uno*, *nove*, *due* (vedi «Sito pubblicato» più sotto).
- I rami di lavoro nuovi partono da `origin/main`.

## Come lavorare con Giovanni

- Tutto in italiano. Risposte brevi, prima l'esito, parole semplici, niente gergo inventato.
- Economia:
  - piano breve, una verifica per passo;
  - una sola attesa in background, che avvisa alla fine (mai cicli di controlli a mano);
  - non rileggere file senza motivo.
- **Su `main` si unisce solo con il suo via libera esplicito.** Prepara la PR e il collaudo, poi chiedi («La unisco e
  la pubblico?»). «Pubblica tutto» vale per il lavoro di quel momento, non per le correzioni successive.
- Quando segnala un errore su una voce:
  1. cerca la causa generale;
  2. misura quante altre voci ne soffrono (finora sono sempre state classi di errori: omografi, composti letti come
     catene, traslitterazioni, segnaposto);
  3. correggi alla fonte (parser o import), con un test.
- Messaggi di commit in italiano, con le righe di firma che indica l'ambiente; mai il nome del modello nei file.

## Ricette (per una macchina nuova)

- **Dipendenze:** `npm ci`. Postgres 16 è già nell'immagine:
  ```bash
  service postgresql start
  ```
  ```bash
  su postgres -c "psql -c \"alter user postgres password 'postgres'\""
  ```
  Si ferma spesso: se una query dice «connection refused», `service postgresql start`.
- **Collaudo:** `PGURL=postgres://postgres:postgres@localhost:5432 scripts/collauda.sh` (101 test del seme, 112
  dell'import) e `npx tsc --noEmit`.
- **Copia locale della produzione.** Si ricostruisce dal pacchetto di `main`, perché il lavoro della redazione oggi è
  vuoto: lo storico è vuoto. Il comando: `createdb`, poi `node scripts/inizializza-db.mjs` con `DATABASE_URL`,
  `DATABASE_URL_UNPOOLED`, `POSTGRES_URL`, `POSTGRES_URL_NON_POOLING` tutti verso
  `postgres://postgres:postgres@localhost:5432/<db>`. Ci vogliono alcuni minuti; lo spazio occupato è in
  `[db] spazio occupato` nel registro.
  - **Prima di lanciarlo,** controlla che l'indirizzo contenga `@localhost:`: `.env.local` punta alla produzione.
  - **Copie per le prove:** `create database prova template <db>`.
  - **Prima di ogni pubblicazione** che cambia il pacchetto `dati/`, `05` o un aggiornamento datato, rifai l'import su
    una copia: ha già scovato un aggiornamento datato che avrebbe fermato il deploy.
- **Sito in locale:** le stesse quattro variabili più
  `NEON_AUTH_COOKIE_SECRET=prova-locale-0123456789abcdef0123456789abcdef`, poi `npx next dev -p 3125`; foto con
  Playwright, già installato. La redazione in locale non si vede (Neon Auth).
- **Sito pubblicato:** da qui Vercel non si raggiunge, quindi si passa dal ramo di servizio `controllo-sito`.
  1. Cambia `.github/workflows/controllo-sito.yml`: per ogni pagina, una riga
     `prova <percorso> '<espressione da cercare>'`.
  2. Fai commit e push: il workflow parte da sé.
  3. Leggi il registro con `gh api repos/trosinogio/stirps/actions/jobs/<id>/logs`.

  Per tracciare quel ramo:
  ```bash
  git config --add remote.origin.fetch '+refs/heads/controllo-sito:refs/remotes/origin/controllo-sito'
  ```
  ```bash
  git fetch origin controllo-sito
  ```
- **Rete:**
  - **Non si raggiungono:** Kaikki, Neon, Vercel, LINDAT, ceur-ws.
  - **Wiktionary inglese:** si raggiunge, ma con limiti di frequenza: `curl --retry 4 --retry-delay 20 -A "stirps-ricerca/1.0"`.
  - **raw.githubusercontent.com:** si raggiunge (per i dati di nltk scarica con curl, non con nltk).
- **Git:**
  - Un ramo remoto si traccia solo con un refspec per ramo (come sopra), altrimenti l'hook di fine turno dice
    «no remote branch».
  - Il proxy non lascia cancellare rami.
  - Un push può cadere («remote end hung up»): riprova dopo 2, 4, 8, 16 s.
- **Workflow Dati** (rigenera il pacchetto `dati/`):
  1. Fai push su un ramo `dati-*`. Il giro dura circa 1,5 ore, e un nuovo push annulla quello in corso.
  2. L'esito sta nelle annotazioni.
  3. Il pacchetto torna come commit sul ramo: uniscilo al ramo di lavoro.
- **Funzioni dell'import sul database esistente:** vengono dall'ultimo file di `db/aggiornamenti/` che le definisce,
  in ordine di nome, non da `05`. Una correzione va in due posti:
  - in `05`;
  - in un file datato nuovo, con la funzione rigenerata da `05` e un nome che venga dopo gli altri
    (oggi l'ultimo è `2026-11-10-glosse-numerali.sql`).
- **Attesa di un workflow** (una sola, in background):
  `until gh api "repos/trosinogio/stirps/actions/runs?branch=<ramo>&per_page=3" --jq '.workflow_runs[0].status' | grep -q completed; do sleep 60; done`.

## Cose aperte (in ordine di utilità)

1. **Verifica della pubblicazione della PR #24** (vedi sopra).
2. **Glosse degli omografi in inglese.**
   - *Il problema:* circa 2.500 voci con omografi non prendono più la glossa del Wikizionario, che spesso era quella
     dell'altro omografo. Ora mostrano la glossa inglese, finché OPUS-MT non ne conferma la traduzione.
   - *Idea:* un lotto di traduzione di Claude solo per quelle voci (`import/definisci.py`, workflow Definizioni).
3. **Radici omografe senza identificativo.**
   - *I casi:*
     - *tewk-* «gonfiarsi» e *tewk-* «premere» sono un nodo solo, e sotto c'è *tъkati* «pungere»;
     - *tuber*² (un albero) sta sotto *tewh₂-*;
     - *Tityus* ha la glossa del fiume e la radice del gigante.
   - *Idea misurabile:* confrontare la glossa citata nel modello (`t=`) con quella del nodo (`legame_di_senso()`).
4. **Linea del senso.**
   - *Il problema:* 1.412 archi stanno nel gruppo «Senza linea di senso».
   - *Idea:* far ipotizzare a Claude il passaggio di significato, segnato ≈, misurando prima su un campione (un'analisi
     automatica si misura prima di usarla).
5. **Numerali:** *two* e *zwei* si fermano al germanico.
   - *Perché:*
     - *twai-* ha il trattino, e per le regole è una radice;
     - l'alto tedesco antico *zwei* non ha etimologia nel dump.
   - *Già provato:* una prova con il riquadro «PIE word» è stata ritirata, perché violava la regola delle radici.
6. **Parentele dubbie nelle famiglie.**
   - *Il problema:* un'etimologia con certezza 1, promossa ad accolta, mette la parola nella famiglia (*tucca*,
     *tъkati*).
   - *Da proporre a Giovanni:* tenerle fuori da `mv_famiglia`.
7. **Per Giovanni:**
   - i segreti Zenodo (`ZENODO_SANDBOX_TOKEN`, `ZENODO_TOKEN`);
   - i rami da cancellare: `analisi-forme`, `dati-analisi-forme`, `antenati-latini`, `glosse-numerali`, e alla fine
     `passaggio`;
   - le quattro questioni aperte delle norme: le proposte sono nel Claude Doc «Stirps — Norme redazionali (bozza)».
8. Il resto è in `CLAUDE.md`, «Prossimi passi».

## Dove leggere i dettagli

- `CLAUDE.md` (regole, trappole, liste di lavoro), `README.md`.
- `import/LEGGIMI.md`, nelle sezioni dell'8 e 9 novembre: numerali, ipotesi discusse, linea del senso, Wikizionario e
  omografi, Wiktionnaire, LatinISE.
- Le descrizioni delle PR #23 e #24 e i messaggi di commit: `git log origin/main`.
