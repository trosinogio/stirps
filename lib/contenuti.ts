// Testi delle pagine «Metodo» e «Chi siamo». Nei testi _parola_ è una forma citata, in corsivo.
import type { Lang } from './i18n';

export interface Sezione { titolo: string; testo: string[]; legenda?: boolean; tipi?: [string, string][]; collegamento?: [string, string] }
export interface Pagina { titolo: string; intro: string; sezioni: Sezione[] }

export const METODO: Record<Lang, Pagina> = {
  it: {
    titolo: 'Metodo',
    intro: 'Ogni voce di Stirps risponde a tre domande: da dove viene la parola, per quali lingue è passata, quanto ne siamo sicuri.',
    sezioni: [
      { titolo: 'Radici e famiglie', testo: ['Una famiglia raccoglie tutte le parole che discendono dallo stesso capostipite. Spesso è una radice ricostruita, segnata con l’asterisco perché nessun testo la attesta: _*ped-_, «piede». Lo stemma mostra la famiglia dalla radice alle lingue di oggi; la mappa ne segue il viaggio.'] },
      {
        titolo: 'I passaggi', legenda: true,
        testo: ['Ogni legame tra due parole ha un tipo, e nello stemma ogni tipo ha il suo tratto.'],
        tipi: [
          ['eredità', 'la stessa parola, trasmessa di generazione in generazione (latino _nox_ > _notte_);'],
          ['prestito', 'una parola presa da un’altra lingua (francese antico _bure_ > _burro_);'],
          ['prestito dotto', 'ripresa dai libri, di solito dal latino o dal greco (latino _podium_ > _podio_);'],
          ['derivazione o composizione', 'una parola nuova costruita su altre (_astro_ > _disastro_);'],
          ['legame indeterminato', 'una discendenza certa, ma di natura non precisata.'],
        ],
      },
      { titolo: 'La certezza', testo: ['Ogni ipotesi ha un grado di certezza: certa, probabile, possibile, dubbia. Una catena vale quanto il suo anello più debole.', 'Quello che viene da Wiktionary vale al massimo «probabile»: la certezza piena la attribuisce la redazione, sulle fonti.'] },
      { titolo: 'Ipotesi e fonti', testo: ['Quando gli studiosi non sono d’accordo, le ipotesi convivono: una accolta, le altre alternative, ciascuna con le sue fonti e la loro posizione, che propone, accoglie, discute o respinge.', 'Le opere di riferimento sono raccolte nella bibliografia; quelle in rete si aprono da ogni voce, nella sezione «Da consultare».'], collegamento: ['Bibliografia', 'bibliografia'] },
      { titolo: 'Parole sorelle e allotropi', testo: ['Non si scrivono a mano: si calcolano. Le parole sorelle sono la stessa parola giunta in lingue diverse per eredità, come _notte_, _nuit_ e _night_. Gli allotropi sono parole della stessa lingua venute dallo stesso etimo per vie diverse, come _podio_ e _poggio_.'] },
      { titolo: 'Lo stato delle voci', testo: ['Ogni voce dichiara da dove viene e a che punto è: in bozza, importata, rivista o verificata sulle fonti. La revisione comincia dalle parole più usate.'], collegamento: ['Norme redazionali', 'norme'] },
    ],
  },
  en: {
    titolo: 'Method',
    intro: 'Every entry in Stirps answers three questions: where the word comes from, which languages it passed through, and how sure we are.',
    sezioni: [
      { titolo: 'Roots and families', testo: ['A family gathers every word that descends from the same ancestor. Often it is a reconstructed root, marked with an asterisk because no text attests it: _*ped-_, ‘foot’. The tree shows the family from the root to today’s languages; the map follows its journey.'] },
      {
        titolo: 'The steps', legenda: true,
        testo: ['Every link between two words has a type, and in the tree each type has its own line.'],
        tipi: [
          ['inheritance', 'the same word, handed down from generation to generation (Latin _nox_ > _notte_);'],
          ['borrowing', 'a word taken from another language (Old French _bure_ > _burro_);'],
          ['learned borrowing', 'taken from books, usually from Latin or Greek (Latin _podium_ > _podio_);'],
          ['derivation or compound', 'a new word built on others (_astro_ > _disastro_);'],
          ['indeterminate link', 'a certain descent of unspecified nature.'],
        ],
      },
      { titolo: 'Certainty', testo: ['Every hypothesis has a degree of certainty: certain, probable, possible, doubtful. A chain is only as strong as its weakest link.', 'What comes from Wiktionary counts at most as probable: full certainty is assigned by the editors, on the sources.'] },
      { titolo: 'Hypotheses and sources', testo: ['When scholars disagree, hypotheses stand side by side: one accepted, the others alternatives, each with its sources and their position, which proposes, accepts, discusses or rejects.', 'The reference works are listed in the bibliography; those available online open from every entry, under «Look it up».'], collegamento: ['Bibliography', 'bibliografia'] },
      { titolo: 'Sister words and doublets', testo: ['They are not written by hand: they are computed. Sister words are the same word inherited by different languages, like _notte_, _nuit_ and _night_. Doublets are words of the same language that came from the same etymon by different routes, like _podio_ and _poggio_.'] },
      { titolo: 'The status of entries', testo: ['Every entry states where it comes from and how far along it is: draft, imported, reviewed or checked against the sources. Review starts from the most frequently used words.'], collegamento: ['Editorial guidelines', 'norme'] },
    ],
  },
};

export const CHI_SIAMO: Record<Lang, Pagina> = {
  it: {
    titolo: 'Chi siamo',
    intro: 'Stirps è un dizionario etimologico che ragiona per radici. Invece di elencare le parole in ordine alfabetico, ricostruisce le famiglie che discendono da una stessa radice e le segue attraverso le lingue, passaggio per passaggio.',
    sezioni: [
      { titolo: 'Il nome', testo: ['_Stirps_, in latino, è la parte del tronco con le radici, e insieme la discendenza che ne nasce. Da qui l’italiano _stirpe_; nel diritto, _per stirpes_ vuol dire «per rami di famiglia». Il segno √ del logotipo è quello della radice in matematica, con la sua barra stesa sopra il nome.'] },
      { titolo: 'Perché per radici', testo: ['Un dizionario alfabetico spiega una parola alla volta. Per radici si vede il disegno: _piede_, _pedone_ e _podio_, il francese _pied_ e l’inglese _foot_ sono rami della stessa pianta. Ogni passaggio ha un tipo e una fonte, e ogni ipotesi dichiara quanto è sicura.'] },
      { titolo: 'Chi cura il progetto', testo: ['Stirps è ideato e diretto da Giovanni Maria Trosino, storico dell’arte a Roma. La redazione è aperta: linguisti, filologi e studiosi possono rivedere le voci e firmarle.'] },
      { titolo: 'Da dove vengono i dati', testo: ['La base è aperta: le etimologie di Wiktionary e le glosse del Wikizionario, estratte con Kaikki. La redazione le rivede, le corregge e le verifica sulle opere di riferimento, dal DELI al LEI, dal REW ai dizionari etimologici del latino e del greco.', 'Le glosse italiane vengono prima dal Wikizionario. Per le parole italiane che non vi hanno una voce si usano le definizioni dei lessemi di Wikidata, nel pubblico dominio (CC0), solo con la stessa parte del discorso. Per gli etimi stranieri, dove la sola glossa disponibile è quella inglese di Wiktionary, una traduzione automatica (OPUS-MT, con Argos Translate) dà una glossa italiana: si tiene solo se la traduzione di ritorno ridà l’inglese e se le parole italiane esistono e corrispondono al dizionario rovesciato, e porta sempre il segno ≈. Le altre restano in inglese.', 'Le radici hanno anche una traduzione e una definizione italiane scritte da Claude Opus 5.5, il modello di Anthropic, a partire dalla glossa della radice e dalle glosse dei suoi discendenti più vicini. Il modello ha l’istruzione di non scrivere etimologie, date o autori, e di lasciare la voce vuota quando non conosce la parola con sicurezza. La traduzione di Claude prende il posto di quella di OPUS-MT; la definizione porta il segno ≈ con il nome del modello, finché la redazione non la rivede.', 'Le frequenze d’uso, che decidono l’ordine della revisione, vengono da FrequencyWords di Hermit Dave, ricavate dai sottotitoli di OpenSubtitles, con licenza CC BY-SA 4.0.', 'Il latino e il greco antico sono completi. Oltre alle voci di Wiktionary entrano tutti i lemmi del Lewis & Short (_A Latin Dictionary_, 1879) e del Liddell–Scott–Jones (_A Greek-English Lexicon_, 9ª ed., 1940) che Wiktionary non ha, con la loro glossa inglese, dall’edizione digitale del Perseus Digital Library (Tufts University, http://www.perseus.tufts.edu/). Sono voci senza etimologia, finché la redazione non la scrive.'], collegamento: ['Bibliografia', 'bibliografia'] },
      { titolo: 'Licenza', testo: ['I dati tratti da Wiktionary e dal Wikizionario, e le glosse tradotte e le definizioni scritte da quelli in automatico, restano con licenza CC BY-SA 4.0, e chi li riusa deve citarli. Così i lemmi e le glosse del Lewis & Short e del Liddell–Scott–Jones, che vengono dal Perseus Digital Library (http://www.perseus.tufts.edu/; file TEI di github.com/PerseusDL/lexica) con licenza CC BY-SA 4.0. Le definizioni di Wikidata sono nel pubblico dominio (CC0). La licenza dei contenuti scritti dalla redazione è in via di definizione.'] },
    ],
  },
  en: {
    titolo: 'About',
    intro: 'Stirps is an etymological dictionary that reasons by roots. Instead of listing words in alphabetical order, it reconstructs the families that descend from a common root and follows them across languages, step by step.',
    sezioni: [
      { titolo: 'The name', testo: ['In Latin, _stirps_ is the part of the trunk with the roots, and also the lineage that grows from it. Italian _stirpe_ comes from it; in law, _per stirpes_ means ‘by branches of the family’. The √ in the logo is the mathematical root sign, its bar stretched over the name.'] },
      { titolo: 'Why roots', testo: ['An alphabetical dictionary explains one word at a time. By roots, the pattern shows: _piede_, _pedone_ and _podio_, French _pied_ and English _foot_ are branches of the same plant. Every step has a type and a source, and every hypothesis states how certain it is.'] },
      { titolo: 'Who runs it', testo: ['Stirps is conceived and directed by Giovanni Maria Trosino, an art historian in Rome. The editorial team is open: linguists, philologists and scholars can review entries and sign them.'] },
      { titolo: 'Where the data comes from', testo: ['The foundation is open: Wiktionary’s etymologies and the Italian Wiktionary’s glosses, extracted with Kaikki. The editors review them, correct them and check them against the reference works, from the DELI to the LEI, from the REW to the etymological dictionaries of Latin and Greek.', 'Italian glosses come first from the Italian Wiktionary. For Italian words without an entry there, definitions come from Wikidata lexemes, in the public domain (CC0), only with the same part of speech. For foreign etyma, whose only gloss is Wiktionary’s English one, a machine translation (OPUS-MT, via Argos Translate) gives an Italian gloss: it is kept only if the back-translation returns the English and the Italian words exist and agree with the reversed dictionary, and it always carries the sign ≈. The others stay in English.', 'Roots also have an Italian translation and definition written by Claude Opus 5.5, Anthropic’s model, from the root’s gloss and the glosses of its nearest descendants. The model is instructed not to write etymologies, dates or authors, and to leave the entry empty when it does not know the word with certainty. Claude’s translation replaces OPUS-MT’s; the definition carries the sign ≈ with the model’s name until the editors review it.', 'Word frequencies, which set the order of review, come from Hermit Dave’s FrequencyWords, drawn from OpenSubtitles subtitles, under CC BY-SA 4.0.', 'Latin and Ancient Greek are complete. Besides the Wiktionary entries, every headword of Lewis & Short (_A Latin Dictionary_, 1879) and of Liddell–Scott–Jones (_A Greek-English Lexicon_, 9th ed., 1940) that Wiktionary lacks comes in, with its English gloss, from the digital edition of the Perseus Digital Library (Tufts University, http://www.perseus.tufts.edu/). These entries have no etymology until the editors write one.'], collegamento: ['Bibliography', 'bibliografia'] },
      { titolo: 'Licence', testo: ['Data from Wiktionary and the Italian Wiktionary, and the glosses translated and the definitions written from it automatically, remains under CC BY-SA 4.0, and anyone reusing it must credit it. So do the headwords and glosses of Lewis & Short and Liddell–Scott–Jones, which come from the Perseus Digital Library (http://www.perseus.tufts.edu/; TEI files from github.com/PerseusDL/lexica) under CC BY-SA 4.0. Wikidata definitions are in the public domain (CC0). The licence for content written by the editors is being defined.'] },
    ],
  },
};

// Le norme redazionali (bozza del Claude Doc «Stirps — Norme redazionali»): la versione per il lettore. Le questioni
// ancora aperte stanno nella sezione «In discussione», con la proposta, finché la redazione non le decide.
export const NORME: Record<Lang, Pagina> = {
  it: {
    titolo: 'Norme redazionali',
    intro: 'Come la redazione verifica e scrive una voce di Stirps, perché ogni voce segua le stesse regole chiunque la firmi. È una bozza: le prime cento voci sono il suo banco di prova, e le questioni ancora aperte sono segnate «in discussione».',
    sezioni: [
      {
        titolo: 'Principi', testo: [],
        tipi: [
          ['ogni affermazione ha una fonte', 'una catena, una data, una glossa valgono quanto l’opera che le sostiene, citata con la sua posizione;'],
          ['il dato e l’ipotesi restano distinti', 'una prima attestazione è un fatto documentato, un’etimologia è un’ipotesi con il suo grado di certezza;'],
          ['l’incertezza si dichiara', 'meglio un’origine incerta con due ipotesi che una catena sicura senza fondamento;'],
          ['la provenienza resta visibile', 'ogni dato dice da dove viene: Wiktionary, Wikizionario, Wikidata, traduzione automatica o redazione;'],
          ['si verifica sulle opere', 'Wiktionary è il punto di partenza, mai la fonte di una verifica;'],
          ['nulla si cancella senza traccia', 'ogni modifica è firmata nello storico, e un’ipotesi abbandonata si segna come respinta o superata.'],
        ],
      },
      {
        titolo: 'Il lemma',
        testo: ['Il lemma è la forma di citazione della sua lingua, scritta come il titolo della pagina di Wiktionary: così le voci importate e quelle della redazione si incontrano invece di sdoppiarsi. Una voce nuova si crea solo per una parola che le fonti citano davvero come anello della catena.'],
        tipi: [
          ['italiano', 'l’infinito per i verbi, il maschile singolare per nomi e aggettivi variabili; una variante grafica è una voce a sé, collegata con il passaggio «variante»;'],
          ['latino', 'la forma del dizionario senza segni di quantità (_caro_, non _carō_), i verbi alla prima persona del presente (_moveo_); quantità e forme flesse vanno nella forma citata del passaggio (_carnem_);'],
          ['greco antico', 'accenti e spiriti sì, macron e breve no (_πούς_), con la traslitterazione di Wiktionary;'],
          ['ebraico, aramaico, arabo, siriaco', 'senza segni vocalici nel lemma, con la traslitterazione accanto;'],
          ['forme ricostruite', 'senza asterisco nel lemma e nella notazione di Wiktionary (h₁ h₂ h₃, kʷ, gʷ); la forma della fonte di riferimento va nella citazione, nel campo «s.v.»;'],
          ['omografi', 'parole diverse con la stessa forma sono voci diverse, numerate da Stirps (_zefiro²_).'],
        ],
      },
      {
        titolo: 'I passaggi',
        testo: ['Ogni passaggio dice come una parola nasce da un’altra; nel dubbio tra due tipi vale il più prudente, motivato nella nota. Si registrano solo le tappe che le fonti attestano o ricostruiscono, mai tappe supposte, e tra eredità e prestito dotto decide la fonetica: _poggio_ ha gli esiti popolari, _podio_ conserva la forma latina. Un influsso non è un etimo: entra come passaggio in più, accanto all’etimo vero.'],
        tipi: [
          ['eredità', 'tradizione ininterrotta, con gli esiti fonetici regolari: latino _podium_ > _poggio_;'],
          ['prestito', 'parola entrata da un’altra lingua: francese antico _bure_ > _burro_;'],
          ['prestito dotto', 'ripresa colta dal latino o dal greco, senza gli esiti popolari: latino _podium_ > _podio_;'],
          ['voce semidotta', 'ripresa colta adattata solo in parte: latino _saeculum_ > _secolo_;'],
          ['variante', 'altra forma della stessa parola nella stessa lingua, grafica, sincopata o ridotta: _zefiro_ > _zero_;'],
          ['trasmissione non specificata', 'eredità o prestito, ma le fonti non dicono quale;'],
          ['derivazione', 'base più prefisso o suffisso: _casa_ > _casetta_;'],
          ['composizione', 'unione di due o più elementi: _βοῦς_ + _τυρός_ > _βούτυρον_;'],
          ['accorciamento', 'riduzione di una parola più lunga: _bicicletta_ > _bici_;'],
          ['retroformazione', 'sottrazione di un presunto affisso: _deliberare_ > _delibera_;'],
          ['da nome proprio', 'parola tratta da un nome di persona o di luogo: Galvani > _galvanizzare_;'],
          ['calco', 'parola tradotta elemento per elemento: inglese _skyscraper_ > _grattacielo_;'],
          ['calco semantico', 'significato nuovo su modello straniero: _realizzare_ «rendersi conto», sull’inglese _realize_;'],
          ['incrocio o influsso', 'una forma rimodellata da un’altra: latino _gravis_ > _grevis_, su _levis_;'],
          ['paretimologia', 'rianalisi per falsa associazione: inglese _crayfish_, dal francese antico _crevice_ rifatto su _fish_;'],
          ['filiazione non specificata', 'legame certo di natura ignota, di solito una radice senza tappe, da sostituire appena le fonti danno le tappe.'],
        ],
      },
      {
        titolo: 'Ipotesi e certezza',
        testo: [
          'Ogni parola ha una sola ipotesi accolta, quella che la catena mostra; le altre restano visibili con le loro fonti: alternative, sostenute da fonti autorevoli ma non scelte; minoritarie; respinte, conservate se la letteratura le discute. L’origine può essere un etimo, un’onomatopea, una formazione espressiva, il sostrato o l’origine ignota, che si registra anch’essa come ipotesi.',
          'I dati importati entrano con certezza 3: la verifica la conferma o la corregge. Con una sola fonte la certezza arriva al massimo a 3, e per il 4 servono due opere di riferimento che propongono o accolgono l’ipotesi. Una catena vale quanto il suo anello più debole.',
        ],
        tipi: [
          ['4, certa', 'le fonti principali concordano, la trafila è regolare, nessuna obiezione nota;'],
          ['3, probabile', 'accolta dalle fonti principali con riserve minori, o sostenuta da una sola fonte autorevole;'],
          ['2, possibile', 'proposta e discussa in letteratura, con alternative di peso simile;'],
          ['1, dubbia', 'congettura isolata o superata, registrata per completezza.'],
        ],
      },
      {
        titolo: 'Fonti e citazioni',
        testo: [
          'Una fonte si cita con sigla, lemma e luogo («DELI, s.v. _fegato_, p. 000») e con la sua posizione sull’ipotesi: la propone, la accoglie, la discute, la respinge, o attesta una data. Una fonte nota solo attraverso un’altra si cita come la si è letta, nominando l’originale nella nota.',
          'Le opere di base per ambito: per l’italiano il DELI e il LEI dove ha la voce, con il Nocentini, il DEI e il VEI, e il TLIO e il GDLI per le attestazioni; per il latino de Vaan ed Ernout–Meillet, con il Du Cange per il latino medievale; per il greco Beekes e Chantraine; per le lingue romanze il REW, il FEW, il TLFi e il DCECH; per il germanico il Kroonen; per gli arabismi il Pellegrini; per le radici indoeuropee il LIV² e il NIL, e l’IEW solo con cautela.',
        ],
        collegamento: ['Bibliografia', 'bibliografia'],
      },
      {
        titolo: 'Quando un’ipotesi è verificata',
        testo: [
          'Quando valgono tutte e quattro le condizioni: almeno un’opera di riferimento del suo ambito, consultata direttamente, la propone o la accoglie; la catena corrisponde alla fonte in ogni tappa, o le differenze sono motivate nella nota; se le fonti principali divergono, sono registrate tutte; per le parole italiane, una delle fonti è il DELI, o il LEI dove ha la voce.',
          'Wiktionary, il Wikizionario, Etymonline e Logeion non bastano mai a verificare. Stirps lo controlla da sé: un’ipotesi verificata ha almeno un’opera della bibliografia che la propone o la accoglie, e due se la certezza è 4.',
        ],
      },
      {
        titolo: 'Date',
        testo: [
          'La data di una parola è la sua prima attestazione documentata, con la fonte che la attesta: il TLIO fino al 1400, il DELI, il GDLI e il LEI per i secoli successivi. Se un’opera retrodata, vale la data più antica, con la sua fonte. Si sceglie la precisione più stretta che la fonte permette: esatta (_1294_), circa, prima del (_ante 1300_), dopo il, intervallo, secolo.',
          'L’anno di un passaggio si annota solo se una fonte data proprio il passaggio, come l’ingresso di un prestito, e nella catena sta accanto al tipo («prestito, sec. XII»); la prima attestazione resta accanto alla parola. Gli etimi stranieri si datano solo quando la data dice qualcosa: lo _zephirum_ di Fibonacci (1202) sì, il latino classico _caro_ no. Le date trovate in automatico sono stime («almeno dal …») finché la redazione non le verifica.',
        ],
      },
      {
        titolo: 'Glosse e note',
        testo: [
          'La glossa dice in poche parole che cosa significa la parola: per una parola italiana il senso principale, per un etimo straniero il significato che conta per la catena (latino _caro_: carne). Le glosse tradotte in automatico portano il segno ≈ finché la redazione non le rivede.',
          'La nota spiega la scelta, non la ripete: perché questa ipotesi, dove le fonti divergono, che cosa resta aperto. Si scrive solo in italiano, in una-quattro frasi, con le fonti citate per sigla, senza riassumere né copiare i testi delle fonti.',
        ],
      },
      {
        titolo: 'Stati della voce',
        testo: ['Ogni ipotesi, glossa e voce ha uno stato, e solo «verificata» dice che una persona l’ha controllata sulle fonti. Ogni modifica entra nello storico firmata da chi l’ha fatta.'],
        tipi: [
          ['importata', 'arrivata da Wiktionary, dal Wikizionario o da Wikidata, e non ancora controllata;'],
          ['bozza', 'scritta dalla redazione, non ancora riletta;'],
          ['rivista', 'controllata e ritoccata, senza tutte le condizioni della verifica;'],
          ['verificata', 'soddisfa le quattro condizioni della verifica;'],
          ['superata', 'sostituita da una versione nuova, conservata per la storia.'],
        ],
      },
      {
        titolo: 'Casi particolari', testo: [],
        tipi: [
          ['allotropi', 'si dichiarano con catene parallele fino all’antenato comune (_burro_ e _butirro_ fino a _butyrum_), mai con un legame tra le due parole italiane: Stirps li riconosce da sé;'],
          ['forestierismi non adattati', '_film_, _bar_: un prestito dalla lingua di partenza, con la data d’ingresso;'],
          ['origine incerta', 'tutte le proposte serie entrano come ipotesi, nessuna con certezza oltre 2; se nessuna prevale, si accoglie l’origine ignota;'],
          ['dialetti', 'una forma dialettale è una voce del suo dialetto, solo se le fonti la citano come tappa, collegata con eredità o prestito, mai con «variante»;'],
          ['nomi propri', 'in un deonimico l’etimo è il nome stesso, come voce della sua lingua d’origine.'],
        ],
      },
      {
        titolo: 'La verifica di una voce',
        testo: ['Una voce si verifica in nove passi, tutti nell’editor di Stirps.'],
        tipi: [
          ['1', 'si apre la voce dal cruscotto e si legge la catena accolta;'],
          ['2', 'la si confronta con la fonte di base (il DELI per l’italiano) e, se la voce è discussa, con almeno un’altra opera;'],
          ['3', 'si corregge la catena se serve; se l’etimo cambia, si scrive un’ipotesi della redazione e la si accoglie;'],
          ['4', 'si registrano le fonti, con il luogo e la posizione, anche quelle che discutono o respingono;'],
          ['5', 'si inserisce la prima attestazione, con la precisione, il testo e la fonte;'],
          ['6', 'si corregge o si conferma la glossa italiana;'],
          ['7', 'si scrive la nota;'],
          ['8', 'si fissa la certezza, si segna l’ipotesi come verificata e si aggiorna lo stato della voce;'],
          ['9', 'si passa alla voce successiva.'],
        ],
      },
      {
        titolo: 'In discussione',
        testo: [
          'Quattro questioni sono ancora aperte. Per ciascuna c’è una proposta, che non vale finché la redazione non la approva; intanto resta la soluzione di oggi. Altre cinque sono state decise il 1° novembre 2026 (le fonti per «verificata», la variante, la notazione delle ricostruzioni, la data del passaggio, la lingua delle note), e le norme qui sopra le seguono.',
        ],
        tipi: [
          ['l’italiano antico', 'oggi è una varietà dell’italiano; la proposta ne fa una lingua a sé, antenato dell’italiano come in Wiktionary: latino › italiano antico › italiano;'],
          ['i dialetti', 'oggi sono lingue a sé, sorelle dell’italiano e figlie del latino, e la proposta le lascia così: _ciao_ è un prestito dal veneto _s-ciao_;'],
          ['una voce verificata da un altro redattore', 'la proposta è discuterne prima, con un’ipotesi alternativa e le sue fonti; si correggono subito solo i refusi, le pagine delle citazioni e le glosse;'],
          ['la licenza dei testi della redazione', 'la proposta è la CC BY-SA 4.0, la stessa dei dati importati, da cui le voci rivedute derivano.'],
        ],
      },
    ],
  },
  en: {
    titolo: 'Editorial guidelines',
    intro: 'How the editors check and write a Stirps entry, so that every entry follows the same rules whoever signs it. It is a draft: the first hundred entries are its test bench, and the questions still open are marked «under discussion». Editorial notes are written in Italian only.',
    sezioni: [
      {
        titolo: 'Principles', testo: [],
        tipi: [
          ['every claim has a source', 'a chain, a date, a gloss are worth what the work behind them is worth, cited with its position;'],
          ['data and hypothesis stay apart', 'a first attestation is a documented fact, an etymology is a hypothesis with its degree of certainty;'],
          ['uncertainty is stated', 'better an uncertain origin with two hypotheses than a confident chain without grounds;'],
          ['provenance stays visible', 'every datum says where it comes from: Wiktionary, the Italian Wiktionary, Wikidata, machine translation or the editors;'],
          ['checks are made on the works', 'Wiktionary is the starting point, never the source of a check;'],
          ['nothing is deleted without a trace', 'every change is signed in the history, and an abandoned hypothesis is marked rejected or superseded.'],
        ],
      },
      {
        titolo: 'The headword',
        testo: ['The headword is the citation form of its language, written as the title of the Wiktionary page: this way imported entries and the editors’ entries meet instead of splitting in two. A new entry is created only for a word the sources actually cite as a link in the chain.'],
        tipi: [
          ['Italian', 'the infinitive for verbs, the masculine singular for variable nouns and adjectives; a spelling variant is an entry of its own, linked by a «variant» step;'],
          ['Latin', 'the dictionary form without vowel-length marks (_caro_, not _carō_), verbs in the first person present (_moveo_); length and inflected forms go in the cited form of the step (_carnem_);'],
          ['Ancient Greek', 'accents and breathings yes, macron and breve no (_πούς_), with Wiktionary’s transliteration;'],
          ['Hebrew, Aramaic, Arabic, Syriac', 'no vowel points in the headword, with the transliteration beside it;'],
          ['reconstructed forms', 'no asterisk in the headword, in Wiktionary’s notation (h₁ h₂ h₃, kʷ, gʷ); the form of the reference work goes in the citation, under «s.v.»;'],
          ['homographs', 'different words with the same form are different entries, numbered by Stirps (_zefiro²_).'],
        ],
      },
      {
        titolo: 'The steps',
        testo: ['Every step says how one word arises from another; when two types are possible, the more cautious one applies, explained in the note. Only stages the sources attest or reconstruct are recorded, never assumed ones, and phonetics decides between inheritance and learned borrowing: _poggio_ shows the popular outcomes, _podio_ keeps the Latin form. An influence is not an etymon: it enters as an extra step beside the true etymon.'],
        tipi: [
          ['inheritance', 'unbroken transmission, with the regular sound changes: Latin _podium_ > _poggio_;'],
          ['borrowing', 'a word taken from another language: Old French _bure_ > _burro_;'],
          ['learned borrowing', 'taken from Latin or Greek through books, without the popular outcomes: Latin _podium_ > _podio_;'],
          ['semi-learned word', 'a learned borrowing adapted only in part: Latin _saeculum_ > _secolo_;'],
          ['variant', 'another form of the same word in the same language, spelling, syncopated or reduced: _zefiro_ > _zero_;'],
          ['unspecified transmission', 'inheritance or borrowing, but the sources do not say which;'],
          ['derivation', 'a base plus prefix or suffix: _casa_ > _casetta_;'],
          ['compounding', 'two or more elements joined: _βοῦς_ + _τυρός_ > _βούτυρον_;'],
          ['clipping', 'a longer word shortened: _bicicletta_ > _bici_;'],
          ['back-formation', 'a supposed affix removed: _deliberare_ > _delibera_;'],
          ['from a proper name', 'a word drawn from the name of a person or place: Galvani > _galvanizzare_;'],
          ['calque', 'a word translated element by element: English _skyscraper_ > _grattacielo_;'],
          ['semantic calque', 'a new meaning on a foreign model: _realizzare_ ‘to become aware’, on English _realize_;'],
          ['blend or influence', 'a form reshaped by another: Latin _gravis_ > _grevis_, on _levis_;'],
          ['folk etymology', 'reanalysis by false association: English _crayfish_, from Old French _crevice_ remade on _fish_;'],
          ['unspecified descent', 'a certain link of unknown nature, usually a root without stages, to be replaced as soon as the sources give the stages.'],
        ],
      },
      {
        titolo: 'Hypotheses and certainty',
        testo: [
          'Every word has a single accepted hypothesis, the one the chain shows; the others stay visible with their sources: alternatives, backed by authoritative sources but not chosen; minority views; rejected ones, kept if the literature discusses them. The origin can be an etymon, an onomatopoeia, an expressive formation, a substrate or an unknown origin, which is recorded as a hypothesis too.',
          'Imported data comes in with certainty 3: the check confirms or corrects it. With a single source certainty reaches 3 at most, and 4 needs two reference works that propose or accept the hypothesis. A chain is only as strong as its weakest link.',
        ],
        tipi: [
          ['4, certain', 'the main sources agree, the development is regular, no known objection;'],
          ['3, probable', 'accepted by the main sources with minor reservations, or backed by a single authoritative source;'],
          ['2, possible', 'proposed and discussed in the literature, with alternatives of similar weight;'],
          ['1, doubtful', 'an isolated or outdated conjecture, recorded for completeness.'],
        ],
      },
      {
        titolo: 'Sources and citations',
        testo: [
          'A source is cited with its abbreviation, headword and place («DELI, s.v. _fegato_, p. 000») and with its position on the hypothesis: it proposes, accepts, discusses or rejects it, or attests a date. A source known only through another is cited as it was read, naming the original in the note.',
          'The basic works by field: for Italian the DELI, and the LEI where it has the entry, with Nocentini, the DEI and the VEI, and the TLIO and the GDLI for attestations; for Latin de Vaan and Ernout–Meillet, with Du Cange for Medieval Latin; for Greek Beekes and Chantraine; for the Romance languages the REW, the FEW, the TLFi and the DCECH; for Germanic Kroonen; for Arabisms Pellegrini; for Indo-European roots the LIV² and the NIL, and the IEW only with caution.',
        ],
        collegamento: ['Bibliography', 'bibliografia'],
      },
      {
        titolo: 'When a hypothesis is checked',
        testo: [
          'When all four conditions hold: at least one reference work of its field, consulted directly, proposes or accepts it; the chain matches the source at every stage, or the differences are explained in the note; if the main sources disagree, all of them are recorded; for Italian words, one of the sources is the DELI, or the LEI where it has the entry.',
          'Wiktionary, the Italian Wiktionary, Etymonline and Logeion are never enough for a check. Stirps enforces it: a checked hypothesis has at least one work of the bibliography that proposes or accepts it, and two if its certainty is 4.',
        ],
      },
      {
        titolo: 'Dates',
        testo: [
          'The date of a word is its first documented attestation, with the source that attests it: the TLIO up to 1400, the DELI, the GDLI and the LEI for later centuries. If a work gives an earlier date, the earliest date applies, with its source. The narrowest precision the source allows is chosen: exact (_1294_), about, before (_ante 1300_), after, range, century.',
          'The year of a step is recorded only if a source dates the step itself, such as the arrival of a borrowing, and in the chain it stands beside the type («borrowing, 12th c.»); the first attestation stays beside the word. Foreign etyma are dated only when the date tells something: Fibonacci’s _zephirum_ (1202) yes, Classical Latin _caro_ no. Dates found automatically are estimates («since at least …») until the editors check them.',
        ],
      },
      {
        titolo: 'Glosses and notes',
        testo: [
          'The gloss says in a few words what the word means: for an Italian word its main sense, for a foreign etymon the meaning that matters for the chain (Latin _caro_: flesh). Machine-translated glosses carry the sign ≈ until the editors review them.',
          'The note explains the choice instead of repeating it: why this hypothesis, where the sources disagree, what remains open. It is written in Italian only, in one to four sentences, citing the sources by abbreviation, without summarising or copying their texts.',
        ],
      },
      {
        titolo: 'Status of an entry',
        testo: ['Every hypothesis, gloss and entry has a status, and only «checked» means that a person has verified it against the sources. Every change enters the history signed by whoever made it.'],
        tipi: [
          ['imported', 'arrived from Wiktionary, the Italian Wiktionary or Wikidata, and not yet checked;'],
          ['draft', 'written by the editors, not yet reread;'],
          ['reviewed', 'checked and touched up, without all the conditions of a check;'],
          ['checked', 'meets the four conditions of a check;'],
          ['superseded', 'replaced by a new version, kept for the record.'],
        ],
      },
      {
        titolo: 'Special cases', testo: [],
        tipi: [
          ['doublets', 'declared with parallel chains down to the common ancestor (_burro_ and _butirro_ down to _butyrum_), never with a link between the two Italian words: Stirps recognises them by itself;'],
          ['unadapted foreign words', '_film_, _bar_: a borrowing from the source language, with the date of entry;'],
          ['uncertain origin', 'every serious proposal enters as a hypothesis, none with certainty above 2; if none prevails, the unknown origin is accepted;'],
          ['dialects', 'a dialect form is an entry of its dialect, only if the sources cite it as a stage, linked by inheritance or borrowing, never by «variant»;'],
          ['proper names', 'in a word derived from a name the etymon is the name itself, as an entry of its language of origin.'],
        ],
      },
      {
        titolo: 'Checking an entry',
        testo: ['An entry is checked in nine steps, all in the Stirps editor.'],
        tipi: [
          ['1', 'open the entry from the dashboard and read the accepted chain;'],
          ['2', 'compare it with the basic source (the DELI for Italian) and, if the entry is debated, with at least one other work;'],
          ['3', 'correct the chain if needed; if the etymon changes, write an editors’ hypothesis and accept it;'],
          ['4', 'record the sources, with place and position, including those that discuss or reject it;'],
          ['5', 'enter the first attestation, with its precision, text and source;'],
          ['6', 'correct or confirm the Italian gloss;'],
          ['7', 'write the note;'],
          ['8', 'set the certainty, mark the hypothesis as checked and update the status of the entry;'],
          ['9', 'move on to the next entry.'],
        ],
      },
      {
        titolo: 'Under discussion',
        testo: [
          'Four questions are still open. Each has a proposal, which does not apply until the editors approve it; meanwhile today’s solution stays. Five more were decided on 1 November 2026 (the sources for «checked», the variant, the notation of reconstructions, the date of a step, the language of the notes), and the guidelines above follow them.',
        ],
        tipi: [
          ['Old Italian', 'today a variety of Italian; the proposal makes it a language of its own, the ancestor of Italian as in Wiktionary: Latin › Old Italian › Italian;'],
          ['the dialects', 'today languages of their own, sisters of Italian and daughters of Latin, and the proposal keeps them so: _ciao_ is a borrowing from Venetian _s-ciao_;'],
          ['an entry checked by another editor', 'the proposal is to discuss first, with an alternative hypothesis and its sources; only typos, citation pages and glosses are corrected at once;'],
          ['the licence of the editors’ texts', 'the proposal is CC BY-SA 4.0, the same as the imported data, from which the reviewed entries derive.'],
        ],
      },
    ],
  },
};
