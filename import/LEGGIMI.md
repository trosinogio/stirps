# Import da Wiktionary

L’importatore porta nel dizionario le etimologie del Wiktionary inglese, attraverso i dump strutturati di Kaikki (wiktextract). Tutto entra come strato `wiktionary` (CC BY-SA 4.0) con stato `importato`, separato dalla redazione.

## Uso

Servono `python3` (solo libreria standard), `curl` e `psql`. Il database deve avere già lo schema: `db/01`–`03` e `db/05_import_wiktionary.sql`.

```bash
DATABASE_URL="postgres://…" ./importa.sh            # italiano, con la chiusura su latino e francese antico
CHIUSURA="la:Latin" DATABASE_URL="postgres://…" ./importa.sh                  # chiusura sul solo latino
CHIUSURA="" DATABASE_URL="postgres://…" ./importa.sh                          # senza chiusura
WIKIZIONARIO=0 DATABASE_URL="postgres://…" ./importa.sh                       # senza glosse italiane
LINGUA=fr NOME=French CHIUSURA="la:Latin fro:Old French" DATABASE_URL="…" ./importa.sh   # un'altra lingua
INTERE="" DATABASE_URL="postgres://…" ./importa.sh                            # latino e greco solo dove arrivano le catene
CHIUSURA="… en:English enm:Middle English ang:Old English" CON_ETIMOLOGIA=en ./importa.sh   # anche l’inglese con etimologia
SOLO_ANALISI=1 ./importa.sh                         # solo le tabelle (dati/it/tsv), senza database
DATABASE_URL="postgres://…" ./collauda.sh           # test su voci reali (esempio/)
```

Lo script lavora in quattro fasi e impiega circa quattro minuti:

1. **Download e filtro, circa 2 minuti e mezzo.** `filtra.py` scarica in streaming i dump di Kaikki (italiano 779 MB, latino 1,25 GB, francese antico 37 MB). Tiene i lemmi con un’etimologia, l’elenco di tutti i lemmi con le forme che distinguono gli omografi, e per le lingue di chiusura la mappa forme flesse → lemma. `filtra_wikizionario.py` scarica il Wikizionario (665 MB) e tiene una glossa italiana per parola, lingua e parte del discorso.
2. **Analisi, circa 1 minuto.** `wiktionary.py` legge le etimologie e scrive i file delle tabelle di appoggio.
3. **Caricamento:** `psql \copy` riempie le tabelle di appoggio.
4. **Fusione, circa 30 secondi, più 8 di ricalcoli.** `importa_wiktionary()` fonde etimologie e attestazioni, `importa_dizionari()` aggiunge i lemmi del Perseus, `importa_glosse_wikizionario()` le glosse italiane; poi si ricalcolano allotropi e famiglie.

L’import si può rilanciare: è idempotente. E scrive solo ciò che cambia: voci, ipotesi, archi e glosse uguali restano dove sono (lo verifica un test sullo `xmin` delle righe). In Postgres ogni riga riscritta lascia una copia morta che occupa spazio fino al vacuum: prima, ogni reimport riscriveva quasi tutto e raddoppiava le tabelle, e il piano gratuito di Neon ha 0,5 GB. Dopo il commit `scripts/inizializza-db.mjs` svuota le tabelle di appoggio e fa il vacuum.

**Tre modi per una lingua di chiusura.** Di norma entrano solo le voci che una catena raggiunge. Con `INTERE` (latino, greco) entra tutta la lingua, anche i lemmi senza etimologia. Con `CON_ETIMOLOGIA` (inglese) entrano tutte le voci che hanno un’etimologia, ma non i lemmi vuoti: l’inglese ne ha centinaia di migliaia. Con `ELENCHI` (`en=../dati/frequenze_en.tsv.gz`) entrano da sole solo le voci dell’elenco, cioè il lessico comune: i lemmi tra le 50 mila forme più frequenti (FrequencyWords), senza nomi propri né locuzioni. Le parole che una catena raggiunge entrano sempre. Le 472 mila voci inglesi con etimologia occuperebbero circa 700 MB, oltre il piano gratuito di Neon; il lessico comune circa 80 MB (stima del 6 novembre 2026). Per l’inglese valgono il suo alfabeto in `lemma_valido()` (con æ, þ, ð, ƿ, ȝ dell’inglese antico e medio), le forme verbali in `FORMA` («simple past tense and past participle of») e, per tutte le lingue, `non_parola()` in `filtra.py`: sigle, abbreviazioni, simboli e segni non sono voci (NASA, BBC, SPQR); le sigle diventate parole minuscole (*laser*, *radar*) restano.

**Prima di un import grande, la stima.** `stima_import.py` confronta il pacchetto nuovo con quello di prima e moltiplica le righe nuove per i byte per riga del database vero (indici compresi, misurati il 6 novembre 2026: voce 510, ipotesi 425, passaggio 355 più 100 nella vista delle famiglie, glossa 340, attestazione 336). Per la lingua esaminata conta parti del discorso, nomi propri e locuzioni, dice in che lingua finiscono le catene e stampa un campione da guardare a mano. Il workflow Dati la esegue prima del commit del pacchetto; la misura vera resta quella della build in locale (`[db] spazio occupato`).

## La chiusura delle catene

Una voce italiana dice da dove viene la parola italiana, ma il legame tra un antenato e l’altro lo descrive bene solo la voce dell’antenato. Il caso esemplare è *burro*. La voce italiana scrive «from Old French *bure*, from Latin *butyrum*» con un `der`, che resta un legame indeterminato. È la voce del francese antico *bure* a dichiarare l’eredità da *butyrum*, e solo con quella *burro* e *butirro* risultano allotropi.

Per ogni lingua di chiusura (per impostazione predefinita latino e francese antico) l’importatore legge le etimologie delle voci già presenti nel dizionario, comprese le forme ricostruite del latino volgare. La voce dell’antenato prevale sulle spiegazioni che le voci italiane danno di passaggio. Il perimetro è un solo passaggio: le parole nuove che la chiusura introduce non vengono a loro volta chiuse, salvo con `--passi N`.

Il latino ha richiesto regole proprie:

- **Solo le forme di citazione sono la parola.** *noctem* è *nox*: nominativo e accusativo singolari e infinito si riconducono al lemma.
- **Participi, gerundi, supini, comparativi e superlativi sono parole a sé.** Derivano dalla loro base: *aperto* < *apertus* < *aperiō*. Fonderli faceva di *aprire*/*aperto* e *forte*/*fortissimo* due falsi allotropi.
- **Le altre forme flesse si legano al lemma con un legame indeterminato.** *loro* < *illōrum*, forma di *ille*: così *loro* non risulta allotropo di *egli*.
- **Una pagina che è un lemma non si riconduce a un altro lemma.** *pugnō* è un verbo, anche se è pure il dativo di *pugnus*. Per questo l’indice comprende tutti i lemmi latini (54.627), non solo i 10.068 con un’etimologia.
- **Gli omografi si distinguono con le forme citate.** Forma canonica, infinito e genitivo: *fondare* viene da *fundō* «fondare» (*fundāre*), *fondere* da *fundō* «versare» (*fundere*). A parità vince l’etimologia principale.
- **Più forme nello stesso template valgono come una.** In «ἀββα,ἀββᾶς» vale la forma già presente nel dizionario.

## Le glosse italiane del Wikizionario

Le glosse di Wiktionary sono inglesi. Il Wikizionario (it.wiktionary.org), estratto anch’esso da Kaikki, dà definizioni scritte in italiano: entrano come traduzioni nella tabella `glossa`, con lo strato `wikizionario` (CC BY-SA 4.0), e la voce lo cita tra le fonti quando ne mostra una, anche per le parole collegate.

- **Una definizione vera.** Per ogni voce vale la prima definizione che non sia una forma flessa o un rimando («plurale di…», «terza persona di…», «variante di…»), senza etichette iniziali come «(botanica)» e accorciata a un confine naturale.
- **Nessuna glossa indovinata.** Una glossa si assegna solo se la parte del discorso combacia, oppure se la parola non ha omografi e il Wikizionario ne dà una sola parte del discorso. *torta* e *torta*², entrambi sostantivi femminili, restano senza.
- **La redazione prevale.** Le parole con una glossa italiana di redazione non ricevono la glossa del Wikizionario.

Risultato, ottobre 2026:
- **Parole italiane:** 34.600 su 73.069 hanno una glossa italiana. Sono il 73% delle parole ereditate dal latino e il 58% dei prestiti; il resto sono in gran parte derivati rari che il Wikizionario non registra.
- **Etimi:** 4.975 hanno una glossa italiana, tra cui 2.833 latini e 953 greci.

Dove la glossa italiana manca, l’interfaccia mostra quella inglese e lo dichiara.

## Le voci sono parole

Prima di scrivere le tabelle il parser toglie le voci che non sono parole (`lemma_valido()`), con gli archi che le toccano e le ipotesi rimaste senza archi.
- **In ogni lingua:** niente frammenti di testo, cioè parentesi, uncini o virgolette.
- **Per latino e greco**, salvo le forme ricostruite, solo lettere dell’alfabeto con i loro diacritici, più spazi, trattini e apostrofi interni.

Restano fuori:
- le lettere isolate (A, α, Ϝ), salvo le parole di una lettera con i loro segni (ὁ, ὦ; latino ā, ē, ō);
- i simboli (☉), le abbreviazioni (A., ꝑ) e i numeri (6tus);
- il sillabario cipriota e le lettere epicoriche (ϝοῖκος, ͷοῖκος).

I modificatori in linea dei modelli (`scorciare<t:to shorten>`) si staccano dal termine in `lessema()`.

**Le forme flesse non sono voci, in nessuna lingua** (novembre 2026). Una voce è una forma flessa se ogni suo senso con una glossa lo è (`forma_flessa()` in `filtra.py`):
- lo dice Wiktionary: il modello `nonlemma`, oppure `form_of` o il tag `form-of`;
- oppure lo dice la glossa: «second-person plural present passive indicative/imperative of contemperō», «genitive singular of nox», «superlative degree of piccolo», «past participle of fare».

Serve la glossa perché Wiktionary non marca sempre il senso: prima di questa regola erano entrate così circa 5.000 forme latine, 322 greche e 103 italiane. Basta un senso lessicale perché la voce resti un lemma (*amatus*, «beloved»). Le varianti («alternative form of», «Epic form of») non sono forme flesse.

Una forma flessa non entra mai come voce, nemmeno quando ha un'etimologia sua (*vicinissimo* < *vicino* + *-issimo*, *fatta* < *facta*). Va solo in `forme.tsv`, con il suo lemma: da `form_of`, o dalla glossa quando Wiktionary non la marca («… of contemperō» → *contemperō*; `lemma_della_forma()`). Una catena che la cita si lega al lemma, con la forma citata accanto: *noctem* → *nox*, *battipanni* < *battere* («batti»). Le parole lessicalizzate restano perché hanno anche un senso lessicale: *ottimo* («very good»), *amatus* («loved one»).

Il registro del filtro riporta quante forme ha riconosciuto in tutto e quante dalla sola glossa: un numero che cambia molto da un import all'altro va guardato.

Le parole scritte nel sillabario cipriota, che Wiktionary mette sotto il greco antico, diventano voci del **greco arcadocipriota** (`grc-arp`, varietà del greco antico), con il loro indice per segni. Le parole con lettere epicoriche (ϝοῖκος) restano voci del greco, forme attestate, ma fuori dall’indice a 24 lettere, come nell’LSJ, che le cita sotto la forma comune; si trovano con la ricerca.

**Etimologie scritte solo nel testo.** Una voce senza modelli etimologici, ma con un testo che comincia con «From», «Derived from», «Deverbal from» o «Back-formation from» e un modello di menzione («From the verb {{m|it|segare}}»), non si scarta più. La prima menzione diventa un `der` (`menzione_come_der()` in `filtra.py`), cioè un legame indeterminato o una derivazione, mai un’eredità.

Le traduzioni automatiche valgono solo per la glossa inglese che è stata tradotta: se la glossa cambia, la traduzione aspetta il pacchetto successivo.

Per riapplicare le regole a un pacchetto già fatto, senza riscaricare i dump: `python3 filtra_pacchetto.py ../dati`.

Le traduzioni automatiche tentate restano nel pacchetto anche quando la verifica le scarta (terza colonna vuota): un nuovo pacchetto traduce solo le voci nuove o con la glossa cambiata.

## I dizionari del Perseus: latino e greco completi

Wiktionary dà circa 56 mila voci latine e 25 mila greche antiche (pacchetto del 1° novembre 2026, tutte le voci comprese, anche senza etimologia). Perché le due lingue siano complete entrano anche i lemmi dei due dizionari di riferimento che Wiktionary non ha: 22.329 latini dal Lewis & Short e 100.448 greci dall’LSJ. Il latino arriva così a 78 mila voci e il greco a 125 mila. I lemmi vengono dall’edizione digitale del Perseus Digital Library (Tufts University, http://www.perseus.tufts.edu/), con licenza CC BY-SA 4.0:

- *A Latin Dictionary* di Charlton T. Lewis e Charles Short (1879): `lat.ls.perseus-eng2.xml`;
- *A Greek-English Lexicon* di Henry George Liddell, Robert Scott e Henry Stuart Jones (9ª ed., 1940): `grc.lsj.perseus-eng1.xml` … `grc.lsj.perseus-eng27.xml`.

I file TEI vengono dal repository [PerseusDL/lexica](https://github.com/PerseusDL/lexica), fissati a un commit nel workflow «Dati». Entrano come strato `perseus`, con stato `importato` e senza etimologia: la redazione può aggiungerla.

```bash
python3 filtra_perseus.py dati/it/tsv/dizionari.tsv --escludi dati/it/tsv/lessemi.tsv lat.ls.perseus-eng2.xml grc.lsj.perseus-eng*.xml
```

`filtra_perseus.py` usa solo la libreria standard e scrive le stesse colonne di `lessemi.tsv`:

- **Il lemma come il titolo di Wiktionary.** Senza quantità, e per il latino *i* al posto di *j* (*iam*, non *jam*). Il greco dell’LSJ è in Beta Code (`*)/abrwn` → Ἄβρων) e diventa Unicode.
- **La glossa è la prima traduzione che dice qualcosa.** Nel Lewis & Short è il primo dei primi tre corsivi che sia una definizione, saltando le note grammaticali («doub. dim.», «P. a. fin.») e i pezzi di parola (POSIER*unt*). Nell’LSJ è la prima delle prime tre traduzioni del primo senso che ne ha, saltando i titoli citati («Aus Lydien»). Una glossa senza parole piene («of …», «to be») non basta, e una tronca cede a una completa. Le glosse lunghe si fermano al primo punto e virgola.
- **Misurata su Wiktionary.** Sui lemmi che hanno entrambi, il senso principale concorda con la glossa di Wiktionary nel 68% dei casi per il Lewis & Short e nel 76% per l’LSJ; quasi tutti i disaccordi sono sinonimi («an ascending» e «ascent»).
- **La traslitterazione del greco** segue lo schema di Wiktionary e dà l’indirizzo: ἀκρίς → `grc/akris`.
- **Gli omografi** si numerano nell’ordine del dizionario: *abactus*¹, *abactus*².
- **Restano fuori** le voci spurie del Lewis & Short, le voci dell’LSJ che non sono in greco (142) e, con `--escludi`, i lemmi che Wiktionary ha già, con la stessa forma.

Nel database li fonde `importa_dizionari()`, dopo `pulisci_wiktionary()`:

- **Le voci nuove** sono i lemmi che non ci sono già, né in Wiktionary con la stessa forma né nella redazione con la stessa forma normalizzata. Se l’indirizzo è occupato da un’altra parola (ἀκρίς «cavalletta» e ἄκρις «cima» danno entrambi `grc/akris`), la nuova prende il numero d’omografo libero successivo. Le voci già presenti tengono il loro.
- **Le voci che nessuno ha toccato** si aggiornano (glossa e parte del discorso), e si tolgono se il pacchetto non le ha più.
- **Quando Wiktionary arriva a una parola del dizionario,** `importa_wiktionary()` toglie la voce del dizionario e le prende il posto e l’indirizzo, se nessuno l’ha toccata. Se la redazione l’ha toccata (una glossa, un’ipotesi, un rimando), la voce resta e Wiktionary la abbina per lingua e lemma, senza doppioni.
- **Mai per forma normalizzata:** come tra voci di Wiktionary, maiuscola e accento distinguono parole diverse (*carus* e *Carus*).

Le glosse inglesi passano dalla stessa traduzione automatica delle voci di Wiktionary, con il segno ≈. La pagina della voce cita il Perseus tra le fonti, con la licenza.

**Licenza.** Il Perseus chiede di citare il Perseus Digital Library con un collegamento a http://www.perseus.tufts.edu/, di identificare ogni testo con il suo repository (qui sopra e nello strato `perseus`) e di offrirgli le correzioni: se la redazione corregge una glossa che viene da questi dizionari, va segnalata su https://github.com/PerseusDL/lexica/issues.

**Limiti.** La glossa è la prima traduzione della voce, non sempre la più rappresentativa. Quando il dizionario continua con una parola greca o latina la traduzione resta tronca, e porta i puntini: «like an …», «the daughter of a …» (il 4% delle glosse latine, il 7% delle greche). Qualche glossa ha un refuso della digitalizzazione («carue on» per «carve on»). Circa 9 mila voci del Lewis & Short e 25 mila dell’LSJ non hanno una glossa: soprattutto nomi propri e rimandi a un’altra voce.

## Le prime attestazioni

Wiktionary data poche parole italiane: il template `etydate` compare in 187 voci, e altre 50 hanno una data nella prosa («First attested in 1590», «Attested from the 1560s»). Le attestazioni importate sono 231. Si legge solo la data che ha per soggetto la parola stessa: «From Old French *bure* (attested 1150)» data l’etimo, non la parola italiana.

Entrano come attestazioni di tipo lessicografico, con la precisione dichiarata (anno, circa, ante, intervallo, secolo), e la voce le presenta «secondo Wiktionary». Le datazioni sistematiche delle parole italiane stanno nei dizionari storici (DELI, TLIO), che non hanno licenza libera: sono lavoro di redazione.

## Le regole generali

**Le catene si leggono dal testo, non solo dai template.** In «From Latin *carnem*, from Proto-Italic \*karō, from Proto-Indo-European \*(s)ker-» ogni «from» fa proseguire la catena. Le parole che la interrompono sono «or», «compare», «cf.», «cognate», «influenced». Si ferma anche quando il testo comincia a spiegare gli elementi di un composto: in «First element *con-* derives from *cum*…» quello che segue riguarda una parte, non la parola.

**Il tipo di un anello intermedio non viene dal template.** In una voce il template descrive il rapporto tra la parola e ciascun antenato, non quello tra un antenato e l’altro. Per gli anelli intermedi valgono quindi tre regole:
- un’eredità resta tale solo tra lingue in linea genealogica;
- qualunque trasmissione tra due parole diverse della stessa lingua (\*terraceus e *terra*) diventa un legame indeterminato;
- se la forma più recente allunga di almeno tre lettere quella più antica, è un derivato.

**`der` è un legame indeterminato, anche al primo livello.** Wiktionary lo usa sia per «la stessa parola per via non precisata» sia per le derivazioni. Un collaudo con `der` trattato come trasmissione ha raddoppiato gli allotropi calcolati, ma metà dei nuovi erano falsi. Gli allotropi si calcolano quindi solo su eredità e prestiti espliciti.

**Una radice non è una parola.** Dalla radice si arriva per formazione o per legame indeterminato, mai per eredità. Gli affissi (*ex-*, *-oso*) non diventano lessemi: restano testo dell’arco.

**Le radici dichiarate chiudono le catene, ma non sopra un’altra radice.** Se una voce dichiara la radice (template `root`) e la catena si ferma prima, la cima della catena viene attaccata alla radice con un legame indeterminato: «risale a questa radice, percorso da completare». Se la cima è già una radice, la dichiarazione è in conflitto e non si applica.

**Le radici omografe restano distinte.** \*(s)ker- «tagliare» e \*(s)ker- «girare» diventano due nodi grazie all’identificativo dei template (`id=cut`, `id=turn`), con numeri di omografo in ordine alfabetico dell’identificativo. Le citazioni senza identificativo restano su un nodo generico, senza glossa, da smistare in redazione.

**Wiktionary vale al massimo «probabile».** Quello che Wiktionary afferma vale 3, mai 4: la certezza è un giudizio di redazione. Gli altri casi:
- «perhaps», «possibly» o un «or» davanti al primo anello abbassano a 2 e l’ipotesi diventa alternativa;
- «uncertain» abbassa a 1;
- la catena vale quanto il suo anello più debole.

**I periodi del latino sono la stessa voce.** Latino tardo, medievale, classico ed ecclesiastico confluiscono nel latino. I titoli latini e greci perdono macron e brevi (*carō* → *caro*); la forma citata li conserva.

**Tra più spiegazioni di un etimo intermedio vince la più vicina, poi la più frequente.** Per *rēx* vince \*rēks, perché discende a sua volta da \*h₃rḗǵs; le altre spiegazioni restano ipotesi alternative.

**La redazione prevale sempre.** Il trattamento dei record dipende da chi li ha toccati:
- se una parola ha già un’ipotesi accolta, quella di Wiktionary entra come alternativa;
- i record di redazione non si toccano;
- i record importati che un redattore ha portato a «rivisto» o «verificato» sopravvivono al reimport.

**Niente cicli.** Il parser toglie l’arco che chiude un ciclo, tipicamente un prestito di ritorno; la fusione controlla i cicli che coinvolgono archi di redazione.

## Validazione

`v_validazione_wiktionary` confronta i calcoli con quello che Wiktionary dichiara. Italiano con chiusura su latino e francese antico, dump del 21 ottobre 2026:

| misura | valore |
|---|---|
| allotropi dichiarati da Wiktionary (`doublet`) | 971 |
| di questi, trovati anche dal calcolo | 279 |
| allotropi calcolati in totale | 822 |
| radici dichiarate da Wiktionary (`root`) | 1.453 |
| di queste, raggiunte dalle catene | 1.246 (86%) |

## Limiti noti

- **Prosa libera.** Le etimologie scritte in prosa senza template restano fuori: dei 54 mila lemmi latini solo 10 mila hanno un’etimologia strutturata. Gli altri entrano lo stesso, senza catena, perché latino e greco entrano interi.
- **Formazioni tra lingue.** 1.261 sono segnalate in `v_anomalie`: per lo più radici indoeuropee collegate direttamente a una parola latina, senza il derivato intermedio.
- **Traslitterazioni mancanti.** 477 parole in scritture non latine ne sono prive: il loro indirizzo contiene caratteri non latini.
- **Radici omografe.** 195 citazioni senza identificativo restano sul nodo generico.
- **Glosse.** Circa 38 mila parole italiane restano con la sola glossa inglese, perché il Wikizionario non le registra; l’interfaccia italiana lo dichiara. Le lingue rare hanno ancora il nome inglese.
- **Date.** Le prime attestazioni importate sono 231: la linea del tempo richiede il lavoro di redazione.

`esempio/` contiene voci reali di Wiktionary e del Wikizionario (CC BY-SA 4.0) usate dal collaudo. Per l’italiano ci sono `lemmi.jsonl` e `glosse.tsv`; per la chiusura `la_*`, `fro_*` e `grc_*`; per le glosse italiane `glosse_it.tsv`; per i dizionari del Perseus `dizionari.tsv`, l’uscita vera di `filtra_perseus.py` per dieci lemmi (CC BY-SA 4.0).

## Caricare i dati già analizzati, senza Python

`dati-wiktionary-it.tar.gz` contiene i file delle tabelle di appoggio prodotti dall’analisi di ottobre 2026, con la chiusura su latino e francese antico, le prime attestazioni e le glosse del Wikizionario (CC BY-SA 4.0). Basta `psql`; l’app fa lo stesso da sola al primo deploy (`scripts/inizializza-db.mjs`):

```bash
tar xzf dati-wiktionary-it.tar.gz && cd tsv
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
truncate stg_lingua, stg_lessema, stg_ipotesi, stg_relazione, stg_doppione, stg_radice, stg_attestazione, stg_wikizionario;
\copy stg_lingua from 'lingue.tsv'
\copy stg_lessema from 'lessemi.tsv'
\copy stg_ipotesi from 'ipotesi.tsv'
\copy stg_relazione from 'relazioni.tsv'
\copy stg_doppione from 'doppioni.tsv'
\copy stg_radice from 'radici.tsv'
\copy stg_attestazione from 'attestazioni.tsv'
\copy stg_wikizionario from 'glosse_it.tsv'
select importa_wiktionary();
select importa_glosse_wikizionario();
refresh materialized view mv_allotropi;
refresh materialized view mv_famiglia;
SQL
```

## Greco antico (ottobre 2026)

L'import chiude le catene anche sul greco antico (`CHIUSURA="la:Latin fro:Old French grc:Ancient Greek"`). La chiusura si ripete finché trova voci nuove (`PASSI=5`, si ferma da sola al quarto passaggio), perché il greco forma parole dentro sé stesso: *βούτυρον* da *βοῦς* e *τυρός*, *βοῦς* da \*gʷṓws.

- **Traslitterazione:** le parole greche citate senza `tr=` ricevono una traslitterazione con lo schema di Wiktionary (χ kh, φ ph, υ u, η ē, ω ō, spirito aspro h, γ nasale n). L'indirizzo resta in caratteri latini: *ὄφελος* diventa `grc/ophelos`.
- **Segni vocalici:** ebraico, aramaico, arabo e siriaco li perdono nei titoli, come in Wiktionary (*אַבָּא* → *אבא*). La hamza resta: è una lettera.
- **Incisi tra parentesi:** un inciso chiuso dentro un connettore non interrompe più la catena («from \*gʷous (compare Mycenaean qo-o), from \*gʷṓws»).
- **Radici ambigue:** una radice dichiarata da una voce formata con un prefisso o da più basi non va più in cima alla catena, perché può appartenere a un altro elemento. *Εὔβοια* dichiara \*h₁es- per *εὐ-*, non per *βοῦς*.

Risultati sui dati di ottobre 2026: le parole italiane che arrivano al protoindoeuropeo passano da 10.150 a 12.529 (+23%), quelle nelle famiglie indoeuropee da 14.515 a 19.620 (+35%), quelle che arrivano al protoellenico da 24 a 1.742.

## Glosse italiane aggiuntive (ottobre 2026)

- `filtra_wikidata.py` filtra il dump dei lessemi di Wikidata e ne tiene i lessemi italiani con una definizione in italiano: 21.377 su 65.130. Nel pacchetto dati entrano quelli i cui lemmi sono nel dizionario, ed entrano nel database solo con la stessa parte del discorso: 1.194 parole.
- `traduci_glosse.py` traduce le glosse inglesi degli etimi stranieri senza glossa italiana. Ne tiene 5.657 su 13.486, verificate per ritorno e con il dizionario rovesciato; sono segnate con ≈ nell'interfaccia. Comandi e controlli sono descritti nel README dell'app.
- `stg_glossa_wikidata` e `stg_glossa_tradotta` sono le tabelle di appoggio; `importa_glosse_aggiuntive()` va chiamata dopo `importa_glosse_wikizionario()`.
- Le traduzioni e le definizioni di Claude (`definisci.py`, novembre 2026) sono descritte nel README dell'app: tabella d'appoggio `stg_definizione`, `importa_definizioni()` dopo `importa_glosse_aggiuntive()`.

## Catene ricostruite meglio (31 ottobre 2026)

Quattro regole nuove del parser danno una catena a 3.425 parole italiane che ne erano prive. Le parole che arrivano al protoindoeuropeo passano da 12.529 a 17.767.

- **Le glosse non sono dubbi.** L'incertezza si legge senza le glosse tra virgolette e senza le parentesi: in *chiaroscuro* l'«obscure» della glossa di *oscuro* non è un dubbio.
- **Le voci-affisso hanno per etimo un affisso:** *foto-* < *φωτο-*, *-grafia* < *-γραφία*.
- **Le formazioni di soli elementi si legano agli elementi:** *fotografia* = *foto-* + *-grafia*, due passaggi di composizione. Così i composti dotti raggiungono le loro radici greche e latine (2.635 parole).
- **L'unica ipotesi è accolta, anche se incerta,** e conserva la sua certezza bassa (1 o 2). Il lettore vede l'etimologia con il suo dubbio, invece del vuoto; un'origine ignota diventa un'ipotesi accolta di origine ignota. Le storie del sito seguono solo i passaggi con certezza 3 o 4.

Restano fuori le etimologie scritte solo nel testo, come *sega*: «From the verb segare», senza modello. Il filtro non conserva i modelli di menzione (`m`, `l`); è un lavoro per un import futuro.

## Radici rigorose (novembre 2026)

Il controllo `controlla_radici.py` confronta, per le 2.941 parole che dichiarano la loro radice in Wiktionary (`{{root}}`), la radice dichiarata con la cima della loro catena. Solo il 73% arrivava alla radice giusta, per tre errori del parser:
- **anelli rovesciati.** Gli anelli intermedi incatenano in sequenza le forme citate in un'etimologia, e 211 radici avevano un falso etimo: *\*steh₂-* < *\*stnéh₂ti*, *\*dʰeh₁-* < *\*steh₂-*, *\*bʰoln-* < longobardo *\*palla*. La cima mostrata era sbagliata nel 14% dei casi;
- **omografe mescolate.** Il nodo generico di radici omografe (*\*(s)ker-*) mescolava famiglie diverse: *carne* finiva sotto «girare»;
- **ripiego a caso.** Il ripiego sulla radice dichiarata sceglieva a caso tra due radici (*audientia* sotto *\*dʰeh₁-* «porre»).

Le regole (`arco_impossibile()`, `precisa_omografe()`, `chiudi_su_radici()`), con le loro prove in `collauda.sh`:
- una radice (*\*meh₂-*) non ha etimi automatici;
- un tema (*\*meh₂-tu-*) deriva solo da una radice della stessa lingua;
- nessuna parola deriva da una lingua che discende dalla sua (`antenato_lingua()`, `discende_da()`; un prestito come *\*kaisaraz* < *Caesar* resta);
- un arco verso il nodo generico passa alla radice precisa se tutte le parole sotto la dichiarano;
- il ripiego collega solo con una maggioranza chiara.

Dopo: 86% giuste, 0 radici sotto un loro derivato, 0,4% su un nodo generico. Il resto è soprattutto incompletezza: composti con due radici, catene che si fermano a una parola di una lingua che non leggiamo (inglese), voci latine con l'etimologia nel nuovo modello `{{ety}}`, che il filtro non legge ancora (21.527).

## Il sistema nuovo di Wiktionary: {{ety}} e {{etymon}} (novembre 2026)

Nel dump latino 21.527 voci scrivono l'etimologia con `{{ety}}` o `{{etymon}}`, che il filtro non leggeva: restavano senza catena. Il modello ha come argomento 1 la lingua della voce, poi parole chiave con i due punti seguite dai loro termini: `{{ety|la|:af|fābula<id:discourse>|-lus<alt:-la>}}`, `{{ety|it|:inh|la:aquila}}`. Un termine senza prefisso è della stessa lingua; senza parola chiave vale `:from`. Dice solo il primo livello: gli etimi hanno le loro voci.

- `da_ety()` converte il primo etimo nel modello classico equivalente: `:inh` → `inh`, `:bor`/`:lbor`/`:ubor` → i prestiti, `:der`/`:from` → `der`, `:af` → `af`. `:influence` e le parole chiave che non danno un etimo non contano.
- **I preverbi.** Nei composti latini e greci un preverbo scritto come parola (`ad`, `κατά`), quando non è l'ultimo elemento, diventa un prefisso: *acquiēscō* va con *quiēscō*, non con *ad*.
- **Quando vale.** Solo se nessun modello classico dà già un etimo (`porta_etimo()`). `{{suffix|la|-ia}}` senza la base non lo dà, e allora vale `{{ety}}`: così *fabella* va con *fābula*. Un termine vuoto (`itc-pro:`) non è un etimo, e `lemma_valido()` non accetta lemmi vuoti.
- **Le abbreviazioni.** Quelle dei modelli classici (`suf`, `pre`, `com`, `con`, `univerbation`, `back-formation`…) diventano il modello pieno.
- **Il risultato.** Le voci latine con etimologia passano da 10.060 a 32.545, e le ipotesi del pacchetto da 97.847 a circa 120.300; le catene giuste nel controllo delle radici restano all'86%.
- **La diagnosi.** `SENZA=…` scrive le cause dei lemmi senza etimologia (nessuna, solo testo, modelli non letti), `DIAGNOSI_MODELLI=…` e `DIAGNOSI_PAROLE=…` stampano esempi grezzi nel registro.

*Audientia* resta senza catena: la sua pagina ha `{{suffix|la|-ia}}` e scrive la base *audiēns* solo nel testo. Servirà la lettura della prosa.

