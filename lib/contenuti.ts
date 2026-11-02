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
      { titolo: 'Lo stato delle voci', testo: ['Ogni voce dichiara da dove viene e a che punto è: in bozza, importata, rivista o verificata sulle fonti. La revisione comincia dalle parole più usate.'] },
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
      { titolo: 'The status of entries', testo: ['Every entry states where it comes from and how far along it is: draft, imported, reviewed or checked against the sources. Review starts from the most frequently used words.'] },
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
