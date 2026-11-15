// Testi dell'interfaccia. Una sola fonte: l'app Next.js li importa, lo script
// del prototipo statico estrae l'oggetto compreso tra i marcatori.
// Per aggiungere una lingua d'interfaccia: aggiungerla a LINGUE_INTERFACCIA,
// tradurre un blocco qui sotto e inserire le glosse nella tabella «glossa».

export const LINGUE_INTERFACCIA = ['it', 'en'] as const;
export type Lang = (typeof LINGUE_INTERFACCIA)[number];
export const isLang = (x: string): x is Lang => (LINGUE_INTERFACCIA as readonly string[]).includes(x);

export interface Testi {
  nomeInterfaccia: string;
  titolo: string;
  tornaIndice: string;
  cercaEtichetta: string;
  cercaSegnaposto: string;
  nessunRisultato: string;
  perSignificato: string;
  cambiaLingua: string;
  eroeAria: string;
  eroeDidascalia: (n: number) => string;
  apriStemma: string;
  altraRadice: string;
  radici: string;
  radiciNota: string;
  aree: { titolo: string; tutte: (n: number) => string; senzaArea: string; conto: (n: number, area: string) => string;
          nota: string; tutteLeAree: string; iniziali: string };
  paroleLingue: (p: number, l: number) => string;
  paroleInLingue: (p: number, l: number) => string;
  capostipitiProvvisori: string;
  capostipitiNota: string;
  radiciPerLingua: string;
  tutteLeLingueChip: string;
  altreLingueN: (n: number) => string;
  radiciConto: (n: number, provvisorie: boolean) => string;
  radiceEsempi: (parole: string[]) => string;
  discendentiN: (n: number) => string;
  lingue: string;
  lingueNota: string;
  alberoL: { conta: (lingue: number, parole: number) => string; varieta: string; altre: (n: number) => string; altreLingue: string;
             altreFamiglie: string; altreFamiglieN: (famiglie: number, lingue: number) => string; indoeuropee: string };
  famiglia: (f: string) => string;
  indietro: string;
  stemmaTitolo: (lemma: string) => string;
  schede: { sintesi: string; stemma: string; lingue: string; mappa: string };
  sintesi: { nellaLingua: (n: number) => string; perUso: string; tutte: (n: number) => string; rami: string; ramiNota: (lemma: string) => string;
    altriRami: (n: number) => string; altreLingue: (n: number) => string; altreLingueNota: string; apriFamiglia: (lemma: string) => string };
  stemmaRidotto: string;
  vistaFamiglia: string;
  nessunDiscendente: string;
  apriVoceDi: (lemma: string) => string;
  discendeDa: string;
  ipotesiAccolta: string;
  inAlternativa: string;
  radiceRicostruita: string;
  formaRicostruitaCapo: string;
  radiceFormale: string;
  capoProvvisorio: string;
  origini: Record<string, string>;
  legenda: { eredita: string; prestito: string; dotto: string; formazione: string; indeterminata: string; ricostruita: string; dubbio: string };
  legameDubbio: string;
  perLegameDubbio: string;
  paroleDubbie: (n: number) => string;
  stemmaSuggerimento: string;
  stemmaDi: (lemma: string) => string;
  nomiPropriMostra: (n: number) => string;
  nomiPropriNascondi: string;
  altreParole: (n: number) => string;
  eNomiPropri: (n: number) => string;
  altreDa: (n: number, lemma: string) => string;
  filtraParole: string;
  chiudi: string;
  nessunaParola: string;
  apriStemmaDi: (lemma: string) => string;
  mappaPochi: string;
  mappaNota: string;
  mappaProto: string;
  mappaAria: string;
  formaRicostruita: string;
  formaAntiquata: string;
  pronuncia: { titolo: string; sillabazione: string; ascolta: string; audio: string; varieta: (etichette: string) => string };
  inBreve: { titolo: string; origine: string; radice: string; radici: string; attestazione: string; parenti: string; parentiN: (n: number, lingue: number) => string };
  scheda: { etichette: (etichette: string) => string; grammatica: (testo: string) => string; sensiWiktionary: string };
  dati: (nome: string, licenza: string) => string;
  sezioni: {
    origine: string; ipotesi: string; ipotesiFonti: string; significati: string; mito: string; sorelle: string;
    allotropi: string; viaggio: string; attestazioni: string; discendenti: string; connessioni: string; fonti: string; tempo: string;
  };
  etimologiaAperta: string;
  eRadice: string;
  etimologiaAssente: string;
  certezzaCatena: string;
  anelloDebole: string;
  capostipite: string;
  capostipiti: string;
  toccaCapo: (n: number) => string;
  ipotesiPrincipale: string;
  stati: Record<string, string>;
  fiducia: Record<number, string>;
  nessunEtimo: string;
  da: string;
  dallaForma: string;
  con: string;
  nelSenso: (g: string) => string;
  per: (p: string) => string;
  fonti: string;
  nessunaFonte: string;
  posizioni: Record<string, string>;
  riguarda: string;
  nellaCatena: string;
  sorelleNota: string;
  perEredita: string;
  attraversoPrestito: string;
  allotropiNota: string;
  stessoEtimo: string;
  nessunaAttestazione: string;
  primaAttestazione: string;
  dataPassaggio: string;
  forma: string;
  apriStemmaDa: string;
  famigliaDi: (radice: string) => string;
  strumentiStemma: {
    titolo: string; cerca: string; trovati: (n: number, nascosti: number) => string; nessuno: string; prossima: string;
    lingue: string; tutte: string; altre: string; generazioni: string; tutteGen: string; risali: (x: string) => string;
    paroleIn: (lingua: string) => string;
  };
  legame: (tipo: string) => string;
  tipiConnessione: Record<string, string>;
  inLingua: (nome: string) => string;
  automaticaGlossa: string;
  automaticaDefinizione: (modello: string) => string;
  nomiLingue: Record<string, string>;
  aC: string;
  tempo: { dC: string; oggi: string; aria: (parole: string) => string; legenda: string; senzaData: string; scorri: string };
  dC: string;
  circa: string;
  ante: string;
  post: string;
  secolo: (n: number) => string;
  famigliaRamo: (famiglia: string | null, ramo: string | null) => string;
  varietaDi: (l: string) => string;
  discendeDaLingua: (l: string) => string;
  paroleN: (n: number) => string;
  pos: Record<string, string>;
  anteprima: string;
  nonTrovato: string;
  tornaHome: string;
  descrizioneSito: string;
  etimologiaDi: (lemma: string, lingua: string) => string;
  totaliHome: (lessemi: number, lingue: number, radici: number) => string;
  tutteLeRadici: (n: number) => string;
  tuttiICapostipiti: (n: number) => string;
  paginaDi: (p: number, tot: number) => string;
  precedenti: string;
  successive: string;
  iniziali: string;
  sottoIniziali: string;
  indiceSezioni: string; indiceParole: string; indiceNomi: string; pagineIndice: string;
  fonteStrato: (nome: string, licenza: string) => string;
  glosseAltrove: (lingua: string) => string;
  secondo: (fonte: string) => string;
  almenoDal: (data: string) => string; stimaNota: string;
  homeIntro: string;
  prova: string;
  storie: string;
  comeSiLegge: string;
  lettura: { titolo: string; testo: string }[];
  esplora: string;
  radiciAmpie: string;
  lingueAmpie: string;
  tutteLeLingue: (n: number) => string;
  datiTitolo: string;
  datiTesto: (parole: number, lingue: number, radici: number) => string;
  sottotitolo: string;
  nav: { radici: string; lingue: string; storie: string; metodo: string; norme: string; chiSiamo: string; analisi: string; analisiBreve: string };
  analisi: {
    titolo: string; intro: string; segnaposto: string; pulsante: string; inCorso: string; limite: (n: number) => string;
    errore: string; vuoto: string; riepilogo: (riconosciute: number, occorrenze: number, lemmi: number) => string;
    occorrenze: (n: number) => string; lemmi: (n: number) => string; vie: { popolare: string; dotta: string; prestito: string; altro: string };
    senzaOrigine: string; sconosciute: string; metodo: string;
  };
  navAria: string;
  cercaGrande: string;
  heroLead: string;
  heroNome: { glossa: string; daQui: string };
  esploraRadici: string;
  comeFunziona: string;
  ramiAria: string;
  ramiNota: (lingue: number) => string;
  altreLingue: string;
  progettoTitolo: string;
  progetto: { titolo: string; testo: string }[];
  statoTitolo: string;
  statoTesto: (redazione: number, importate: number) => string;
  statoLegenda: { redazione: string; importate: string };
  paroleTitolo: string;
  tutteLeStorie: string;
  storieNota: string;
  chiSiamoTeaser: string;
  leggiChiSiamo: string;
  piede: { progetto: string; esplora: string; dati: string; datiTesto: string; prototipo: string };
  daConsultare: string;
  daConsultareNota: string;
  bibliografia: string;
  bibliografiaIntro: string;
  ambiti: Record<string, string>;
  inRete: string;
  pubblicoDominio: string;
  dalleVoci: string;
}

// le varietà delle trascrizioni di Wiktionary («Classical-Latin», «Received-Pronunciation»): le più frequenti in italiano,
// le altre come le scrive Wiktionary, senza trattini
const VARIETA_IT: Record<string, string> = {
  'Classical-Latin': 'latino classico', 'Ecclesiastical-Latin': 'latino ecclesiastico', 'Vulgar-Latin': 'latino volgare',
  'Received-Pronunciation': 'britannico', 'General-American': 'americano', UK: 'Regno Unito', US: 'Stati Uniti',
  Canada: 'Canada', Australia: 'Australia', Ireland: 'Irlanda', Scotland: 'Scozia', 'New-Zealand': 'Nuova Zelanda',
  'Standard-German': 'tedesco standard', Germany: 'Germania', Austria: 'Austria', Switzerland: 'Svizzera',
  France: 'Francia', Quebec: 'Québec', Belgium: 'Belgio', Paris: 'Parigi', Attic: 'attico', Koine: 'koinè',
  Byzantine: 'bizantino', Epic: 'epico', Doric: 'dorico', Ionic: 'ionico', Aeolic: 'eolico', Egyptian: 'egiziano',
  Classical: 'classico', Ecclesiastical: 'ecclesiastico', Italy: 'Italia', Rome: 'Roma', Tuscany: 'Toscana',
  Northern: 'settentrionale', Southern: 'meridionale', Moscow: 'Mosca', phoneme: 'fonematica', phonetic: 'fonetica',
  '5th-BCE': 'V sec. a.C.', '4th-BCE': 'IV sec. a.C.', '1st-CE': 'I sec. d.C.', '4th-CE': 'IV sec. d.C.', '10th-CE': 'X sec. d.C.',
  '15th-CE': 'XV sec. d.C.',
};
const varieta = (mappa: Record<string, string> | null) => (etichette: string) =>
  etichette.split(',').filter(Boolean).map((e) => mappa?.[e] ?? e.replace(/-/g, ' ')).join(', ');

// le etichette d'uso e gli ambiti delle accezioni di Wiktionary, e i termini grammaticali della riga delle forme
const ETICHETTE_IT: Record<string, string> = {
  archaic: 'arcaico', obsolete: 'obsoleto', dated: 'datato', rare: 'raro', figuratively: 'figurato', metaphorically: 'metaforico',
  colloquial: 'colloquiale', informal: 'informale', slang: 'gergale', vulgar: 'volgare', derogatory: 'spregiativo',
  pejorative: 'peggiorativo', offensive: 'offensivo', poetic: 'poetico', literary: 'letterario', formal: 'formale',
  humorous: 'scherzoso', euphemistic: 'eufemistico', dialectal: 'dialettale', regional: 'regionale', historical: 'storico',
  transitive: 'transitivo', intransitive: 'intransitivo', reflexive: 'riflessivo', pronominal: 'pronominale',
  uncountable: 'non numerabile', countable: 'numerabile', idiomatic: 'idiomatico', ironic: 'ironico', childish: 'infantile',
  nonstandard: 'non standard', proscribed: 'sconsigliato', 'Late-Latin': 'latino tardo', 'Medieval-Latin': 'latino medievale',
  'Ecclesiastical-Latin': 'latino ecclesiastico', 'New-Latin': 'latino moderno', 'Classical-Latin': 'latino classico',
  Epic: 'epico', Attic: 'attico', Ionic: 'ionico', Doric: 'dorico', Koine: 'koinè', Byzantine: 'bizantino',
  medicine: 'medicina', law: 'diritto', botany: 'botanica', zoology: 'zoologia', music: 'musica', religion: 'religione',
  mathematics: 'matematica', physics: 'fisica', chemistry: 'chimica', anatomy: 'anatomia', military: 'ambito militare',
  nautical: 'marineria', grammar: 'grammatica', linguistics: 'linguistica', philosophy: 'filosofia', architecture: 'architettura',
  economics: 'economia', mythology: 'mitologia', astronomy: 'astronomia', geography: 'geografia', biology: 'biologia',
  computing: 'informatica', sports: 'sport', cooking: 'cucina', agriculture: 'agricoltura', rhetoric: 'retorica',
  Christianity: 'cristianesimo', theology: 'teologia', politics: 'politica', geology: 'geologia', pathology: 'patologia',
};
const GRAMMATICA_IT: Record<string, string> = {
  genitive: 'genitivo', dative: 'dativo', accusative: 'accusativo', nominative: 'nominativo', ablative: 'ablativo',
  plural: 'plurale', singular: 'singolare', feminine: 'femminile', masculine: 'maschile', neuter: 'neutro',
  declension: 'declinazione', conjugation: 'coniugazione', first: 'prima', second: 'seconda', third: 'terza',
  fourth: 'quarta', fifth: 'quinta', present: 'presente', infinitive: 'infinito', perfect: 'perfetto', active: 'attivo',
  passive: 'passivo', supine: 'supino', participle: 'participio', comparative: 'comparativo', superlative: 'superlativo',
  diminutive: 'diminutivo', indeclinable: 'indeclinabile', imperfective: 'imperfettivo', perfective: 'perfettivo',
  past: 'passato', 'past participle': 'participio passato', 'present participle': 'participio presente', and: 'e', or: 'o',
  'not comparable': 'non comparabile', irregular: 'irregolare', future: 'futuro', aorist: 'aoristo', strong: 'forte', weak: 'debole',
  auxiliary: 'ausiliare', 'no plural': 'senza plurale', 'plural only': 'solo plurale', animate: 'animato', inanimate: 'inanimato',
};
const etichette = (mappa: Record<string, string> | null) => (e: string) =>
  e.split(',').filter(Boolean).map((x) => mappa?.[x] ?? x.replace(/-/g, ' ')).join(', ');
// i termini grammatici inglesi della riga delle forme, parola per parola (le locuzioni prima): la forma resta com'è
const GRAMMATICA_RE = new RegExp(`\\b(${Object.keys(GRAMMATICA_IT).sort((a, b) => b.length - a.length).join('|')})\\b`, 'g');
const grammaticaIt = (testo: string) => testo.replace(GRAMMATICA_RE, (m) => GRAMMATICA_IT[m] ?? m);

export const TESTI: Record<Lang, Testi> = /*@@TESTI*/{
  it: {
    nomeInterfaccia: 'Italiano',
    titolo: 'Stirps',
    tornaIndice: 'Torna all’indice delle radici',
    cercaEtichetta: 'Cerca una parola in qualunque lingua, o un significato',
    cercaSegnaposto: 'Cerca: piede, foot, πούς, мать, fegato',
    nessunRisultato: 'Nessuna parola trovata. Prova senza accenti o con la traslitterazione.',
    perSignificato: 'per significato',
    cambiaLingua: 'Lingua dell’interfaccia',
    eroeAria: 'Una radice in evidenza',
    eroeDidascalia: (n) => `La stessa parola, trasmessa per eredità, in ${n} lingue.`,
    apriStemma: 'Apri la famiglia',
    altraRadice: 'Un’altra radice',
    radici: 'Radici',
    radiciNota: 'Ogni radice è la capostipite di una famiglia di parole, in tutte le lingue in cui è arrivata. Sotto ciascuna, alcune parole italiane che ne discendono.',
    aree: {
      titolo: 'Aree di significato',
      tutte: (n) => `tutte le ${n.toLocaleString('it-IT')} radici dell’area ›`,
      senzaArea: 'Senza area',
      conto: (n, a) => `${n.toLocaleString('it-IT')} ${n === 1 ? 'radice' : 'radici'} · ${a}, in ordine alfabetico`,
      nota: 'Le aree di significato le ha proposte Claude dalle glosse e dai discendenti di ogni radice; la redazione può correggerle.',
      tutteLeAree: '‹ tutte le aree',
      iniziali: 'Iniziali',
    },
    radiciPerLingua: 'Lingua della radice',
    tutteLeLingueChip: 'tutte',
    altreLingueN: (n) => `altre ${n} lingue`,
    radiciConto: (n, p) => `${n.toLocaleString('it-IT')} ${p ? (n === 1 ? 'capostipite' : 'capostipiti') : n === 1 ? 'radice' : 'radici'}, dalla famiglia più numerosa`,
    radiceEsempi: (ps) => `in italiano: ${ps.join(', ')}`,
    paroleLingue: (p, l) => `${p.toLocaleString('it-IT')} ${p === 1 ? 'parola' : 'parole'}, ${l} ${l === 1 ? 'lingua' : 'lingue'}`,
    paroleInLingue: (p, l) => `${p} ${p === 1 ? 'parola' : 'parole'} in ${l} ${l === 1 ? 'lingua' : 'lingue'}`,
    capostipitiProvvisori: 'Capostipiti provvisori',
    capostipitiNota: 'Parole da cui discende una famiglia, ma la cui etimologia non è ancora stata risalita.',
    discendentiN: (n) => `${n} ${n === 1 ? 'discendente' : 'discendenti'}`,
    lingue: 'Lingue',
    lingueNota: 'Le lingue del dizionario nel loro albero genealogico: famiglia, ramo e discendenza, dalla protolingua alle lingue di oggi. Si può entrare da qualunque lingua.',
    alberoL: {
      conta: (l, p) => `${l.toLocaleString('it-IT')} ${l === 1 ? 'lingua' : 'lingue'} · ${p.toLocaleString('it-IT')} parole`,
      varieta: 'varietà',
      altre: (n) => (n === 1 ? 'e un’altra' : `e altre ${n}`),
      altreLingue: 'Altre lingue della famiglia',
      altreFamiglie: 'Altre famiglie',
      altreFamiglieN: (f, l) => `altre ${f} famiglie · ${l.toLocaleString('it-IT')} lingue`,
      indoeuropee: 'Lingue indoeuropee',
    },
    famiglia: (f) => `Famiglia ${f.toLowerCase()}`,
    indietro: 'Indietro',
    stemmaTitolo: (l) => `${l}, famiglia di parole`,
    schede: { sintesi: 'Sintesi', stemma: 'Stemma', lingue: 'Lingue', mappa: 'Mappa' },
    sintesi: {
      nellaLingua: (n) => `In italiano · ${n.toLocaleString('it-IT')} ${n === 1 ? 'parola' : 'parole'}`,
      perUso: 'Prima le parole più usate.',
      tutte: (n) => `tutte le ${n.toLocaleString('it-IT')} parole italiane`,
      rami: 'Rami principali',
      ramiNota: (l) => `Le parole che derivano direttamente da ${l}, con quante altre ne portano.`,
      altriRami: (n) => `+ ${n.toLocaleString('it-IT')} ${n === 1 ? 'altra derivata diretta' : 'altre derivate dirette'}, nello stemma`,
      altreLingue: (n) => `Nelle altre lingue · ${n}`,
      altreLingueNota: 'Per ogni lingua, prima le parole più vicine all’origine.',
      apriFamiglia: (l) => `Apri la famiglia di ${l}`,
    },
    stemmaRidotto: 'Una famiglia grande: qui i primi due livelli. Ogni ramo si apre nella sua pagina.',
    vistaFamiglia: 'Vista della famiglia',
    nessunDiscendente: 'Nei dati attuali nessuna parola discende da questa forma.',
    apriVoceDi: (l) => `Apri la voce di ${l}`,
    discendeDa: 'Discende da ',
    ipotesiAccolta: 'ipotesi accolta',
    inAlternativa: 'In alternativa: ',
    radiceRicostruita: 'Radice ricostruita.',
    formaRicostruitaCapo: 'Forma ricostruita, capostipite della famiglia.',
    radiceFormale: 'Radice.',
    capoProvvisorio: 'Capostipite provvisorio: l’etimologia non è ancora stata risalita.',
    origini: { ignota: 'Origine ignota', sostrato: 'Voce di sostrato', onomatopea: 'Onomatopea', espressiva: 'Formazione espressiva' },
    legenda: { eredita: 'eredità', prestito: 'prestito', dotto: 'prestito dotto', formazione: 'derivazione o composizione', indeterminata: 'legame indeterminato', ricostruita: 'forma ricostruita', dubbio: 'legame dubbio' },
    legameDubbio: 'legame dubbio: l’etimologia è incerta',
    perLegameDubbio: 'sta in questa famiglia per un’etimologia dubbia',
    paroleDubbie: (n) => `Di queste, ${n.toLocaleString('it-IT')} ${n === 1 ? 'vi sta' : 'vi stanno'} per un’etimologia dubbia.`,
    stemmaSuggerimento: 'Passa sopra una parola per seguirne il percorso dalla radice. Fai clic per aprire la voce.',
    stemmaDi: (l) => `Stemma della famiglia di ${l}`,
    nomiPropriMostra: (n) => `Mostra i nomi propri (${n.toLocaleString('it-IT')})`,
    nomiPropriNascondi: 'Nascondi i nomi propri',
    altreParole: (n) => `+ ${n.toLocaleString('it-IT')} ${n === 1 ? 'parola' : 'parole'}`,
    eNomiPropri: (n) => `e ${n.toLocaleString('it-IT')} ${n === 1 ? 'nome proprio' : 'nomi propri'}`,
    altreDa: (n, l) => `${n === 1 ? 'Un’altra parola' : `Altre ${n.toLocaleString('it-IT')} parole`} da ${l}`,
    filtraParole: 'Filtra le parole',
    chiudi: 'Chiudi',
    nessunaParola: 'Nessuna parola corrisponde.',
    apriStemmaDi: (l) => `Apri lo stemma di ${l}`,
    mappaPochi: 'Servono almeno due lingue con un luogo per disegnare una mappa. Le protolingue non hanno una collocazione.',
    mappaNota: 'Luoghi indicativi, un punto per lingua; le frecce vanno dalla forma più antica alla più recente.',
    mappaProto: ' Le protolingue non hanno una collocazione e non compaiono.',
    mappaAria: 'Mappa dei passaggi tra le lingue',
    formaRicostruita: 'forma ricostruita',
    formaAntiquata: 'forma antiquata',
    pronuncia: { titolo: 'Pronuncia', sillabazione: 'sillabazione', ascolta: 'Ascolta la pronuncia',
                 audio: 'audio: Wikimedia Commons', varieta: varieta(VARIETA_IT) },
    inBreve: { titolo: 'In breve', origine: 'Origine', radice: 'Capostipite', radici: 'Capostipiti', attestazione: 'Prima attestazione', parenti: 'Parole imparentate',
               parentiN: (n, l) => `${n} ${n === 1 ? 'parola' : 'parole'} in ${l} ${l === 1 ? 'lingua' : 'lingue'}` },
    scheda: { etichette: etichette(ETICHETTE_IT), grammatica: grammaticaIt, sensiWiktionary: 'Accezioni di Wiktionary, in inglese.' },
    dati: (n, l) => `dati ${n}, ${l}`,
    sezioni: {
      origine: 'Da dove viene', ipotesi: 'Ipotesi', ipotesiFonti: 'Ipotesi e fonti', significati: 'Significati', mito: 'Falso mito',
      sorelle: 'Parole sorelle', allotropi: 'Allotropi', viaggio: 'Il viaggio', attestazioni: 'Attestazioni', discendenti: 'Discendenti',
      connessioni: 'Connessioni', fonti: 'Fonti dei dati', tempo: 'Linea del tempo',
    },
    etimologiaAperta: 'Etimologia aperta: nessuna ipotesi è accolta. Le alternative sono qui sotto, con le loro fonti.',
    eRadice: 'È una radice: da qui parte la famiglia.',
    etimologiaAssente: 'L’etimologia di questa parola non è ancora stata inserita.',
    certezzaCatena: 'Certezza della catena:',
    anelloDebole: 'Una catena vale quanto il suo anello più debole.',
    capostipite: 'Capostipite:',
    capostipiti: 'Capostipiti:',
    toccaCapo: (n) => (n > 1 ? 'Tocca un capostipite per vederne lo stemma, con tutta la famiglia.' : 'Toccalo per vederne lo stemma, con tutta la famiglia.'),
    ipotesiPrincipale: 'Ipotesi principale',
    stati: { accolta: 'accolta', alternativa: 'alternativa', minoritaria: 'minoritaria', respinta: 'respinta' },
    fiducia: { 4: 'certa', 3: 'probabile', 2: 'possibile', 1: 'dubbia' },
    nessunEtimo: 'nessun etimo.',
    da: 'da',
    dallaForma: ', dalla forma ',
    con: ', con ',
    nelSenso: (g) => `, nel senso di ${g}`,
    per: (p) => `, per ${p}`,
    fonti: 'Fonti: ',
    nessunaFonte: 'Nessuna fonte ancora citata.',
    posizioni: { propone: 'propone', accoglie: 'accoglie', discute: 'discute', respinge: 'respinge', attesta: 'attesta' },
    riguarda: 'Riguarda',
    nellaCatena: ', nella catena di questa parola.',
    sorelleNota: 'Calcolate dal grafo: la stessa parola giunta in altre lingue.',
    perEredita: 'Per eredità diretta',
    attraversoPrestito: 'Attraverso un prestito',
    allotropiNota: 'Parole della stessa lingua venute dallo stesso etimo per vie diverse.',
    stessoEtimo: 'stesso etimo:',
    nessunaAttestazione: 'Nessuna attestazione ancora inserita.',
    primaAttestazione: 'prima attestazione',
    dataPassaggio: 'data del passaggio, secondo le fonti',
    forma: 'forma',
    apriStemmaDa: 'Apri la famiglia di questa parola',
    famigliaDi: (r) => `Famiglia di ${r}`,
    strumentiStemma: {
      titolo: 'Strumenti dello stemma', cerca: 'Cerca nello stemma', nessuno: 'nessuna parola trovata', prossima: 'Invio: la prossima',
      trovati: (n, h) => `${n.toLocaleString('it-IT')} ${n === 1 ? 'trovata' : 'trovate'}${h ? `, ${h} nelle liste` : ''}`,
      lingue: 'Lingua', tutte: 'Tutte', altre: 'Altre lingue…', generazioni: 'Generazioni', tutteGen: 'tutte',
      risali: (x) => `Risali alla famiglia di ${x}`, paroleIn: (l) => `Tutte le parole in ${l}`,
    },
    legame: (t) => `legame ${t} con`,
    tipiConnessione: { culturale: 'culturale', semantica: 'semantico', omonimia: 'di omonimia', paronimia: 'di paronimia', falso_amico: 'di falso amico', altro: '' },
    inLingua: (n) => `in ${n}`,
    automaticaGlossa: 'Traduzione automatica della glossa inglese, da verificare',
    automaticaDefinizione: (m) => `Definizione scritta da ${m} (Anthropic), non ancora rivista dalla redazione`,
    nomiLingue: { it: 'italiano', en: 'inglese' },
    aC: 'a.C.',
    tempo: {
      dC: 'd.C.', oggi: 'oggi', aria: (p) => `Linea del tempo: ${p}`,
      legenda: 'Fascia: il periodo della lingua, tratteggiata se la lingua è ricostruita; i periodi sono convenzionali. Punto pieno: la prima attestazione datata; cerchio vuoto: per le parole senza data, il momento più antico possibile, cioè l’inizio del periodo della lingua ma non prima dell’etimo. Frecce: continue per eredità e formazione, tratteggiate per i prestiti, a puntini per i legami incerti. La scala si stringe andando indietro nel tempo.',
      senzaData: 'Senza collocazione nel tempo:',
      scorri: '‹ Scorri verso sinistra per tornare indietro nel tempo',
    },
    dC: 'd.C.',
    circa: 'c.',
    ante: 'ante',
    post: 'post',
    secolo: (n) => {
      const V = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
      const C = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
      let r = '', x = n;
      for (let i = 0; i < V.length; i++) while (x >= V[i]) { r += C[i]; x -= V[i]; }
      return 'sec. ' + r;
    },
    famigliaRamo: (f, r) => (f ? `Famiglia ${f.toLowerCase()}` : 'Famiglia non classificata') + (r ? `, ramo ${r.toLowerCase()}` : ''),
    varietaDi: (l) => (/^[aeiouh]/i.test(l) ? `varietà dell’${l}` : `varietà del ${l}`),
    discendeDaLingua: (l) => (/^[aeiouh]/i.test(l) ? `discende dall’${l}` : `discende dal ${l}`),
    paroleN: (n) => `${n.toLocaleString('it-IT')} ${n === 1 ? 'parola' : 'parole'}`,
    pos: { 's.m.': 's.m.', 's.f.': 's.f.', 's.n.': 's.n.', 's.': 's.', 'agg.': 'agg.', 'v.': 'v.', 'avv.': 'avv.', 'prep.': 'prep.', np: 'nome proprio', 'rad.': 'radice',
      'pron.': 'pron.', 'cong.': 'cong.', 'inter.': 'inter.', 'num.': 'num.', 'det.': 'det.', 'loc.': 'locuzione', 'suff.': 'suffisso', 'pref.': 'prefisso' },
    anteprima: 'Anteprima: sono visibili anche le voci in bozza.',
    nonTrovato: 'Voce non trovata.',
    tornaHome: 'Torna alle radici',
    descrizioneSito: 'Stirps, dizionario etimologico per radici: ogni parola discende da una radice e si segue in tutte le lingue, con le fonti e il grado di certezza di ogni passaggio.',
    etimologiaDi: (lemma, lingua) => `${lemma} (${lingua}): etimologia`,
    totaliHome: (p, l, r) => `${p.toLocaleString('it-IT')} parole in ${l} lingue, ${r.toLocaleString('it-IT')} radici.`,
    tutteLeRadici: (n) => `Tutte le radici (${n.toLocaleString('it-IT')})`,
    tuttiICapostipiti: (n) => `Tutti i capostipiti provvisori (${n.toLocaleString('it-IT')})`,
    paginaDi: (p, tot) => `Pagina ${p} di ${tot}`,
    precedenti: '‹ Precedenti',
    successive: 'Successive ›',
    iniziali: 'Iniziali',
    sottoIniziali: 'Prime due lettere',
    indiceSezioni: 'Sezioni dell’indice', indiceParole: 'Parole', indiceNomi: 'Nomi propri e derivati', pagineIndice: 'Pagine',
    fonteStrato: (n, l) => `Fonte: ${n} (${l})`,
    glosseAltrove: (l) => `Le glosse senza traduzione restano ${l ? 'in ' + l : 'nella lingua d’origine'}, come le ha fornite la fonte.`,
    secondo: (f) => `secondo ${f}`,
    almenoDal: (d) => `almeno dal ${d}`,
    stimaNota: 'Stima automatica: la parola è attestata almeno da questa data. La prima attestazione può essere più antica, ed è da verificare sulle fonti.',
    homeIntro: 'Ogni parola viene da altre parole. Qui ogni voce mostra da dove viene, per quali lingue è passata e con quale certezza lo sappiamo, fino alla radice.',
    prova: 'Prova con',
    storie: 'Storie di parole',
    comeSiLegge: 'Come si legge',
    lettura: [
      { titolo: 'Per radici', testo: 'Le parole che risalgono alla stessa radice formano una famiglia. Lo stemma la mostra tutta, dalla radice alle lingue di oggi, e la mappa ne segue il viaggio.' },
      { titolo: 'Ogni passaggio ha un tipo', testo: 'Eredità, prestito, derivazione: nello stemma ciascun passaggio ha il suo tratto, e la legenda qui sotto li riassume.' },
      { titolo: 'Ogni ipotesi ha le sue fonti', testo: 'Ogni ipotesi cita le fonti e dichiara quanto è sicura, e una catena vale quanto il suo anello più debole. Parole sorelle e allotropi non si scrivono a mano: si calcolano.' },
    ],
    esplora: 'Esplora',
    radiciAmpie: 'Le radici con più discendenti',
    lingueAmpie: 'Le lingue con più parole',
    tutteLeLingue: (n) => `Tutte le lingue (${n})`,
    datiTitolo: 'Da dove vengono i dati',
    sottotitolo: 'Dizionario etimologico per radici',
    nav: { radici: 'Radici', lingue: 'Lingue', storie: 'Storie', metodo: 'Metodo', norme: 'Norme redazionali', chiSiamo: 'Chi siamo', analisi: 'Analizza un testo', analisiBreve: 'Analizza' },
    analisi: {
      titolo: 'Analizza un testo',
      intro: 'Incolla un testo italiano: Stirps riconosce le parole, le riconduce al loro lemma e mostra da quali lingue vengono, risalendo le catene del dizionario.',
      segnaposto: 'Incolla qui un testo italiano…',
      pulsante: 'Analizza',
      inCorso: 'Analizzo…',
      limite: (n) => `Al massimo ${n.toLocaleString('it')} caratteri.`,
      errore: 'L’analisi non è riuscita. Riprova tra poco.',
      vuoto: 'Nessuna parola riconosciuta.',
      riepilogo: (r, o, l) => `${r.toLocaleString('it')} parole riconosciute su ${o.toLocaleString('it')}, ${l.toLocaleString('it')} lemmi distinti.`,
      occorrenze: (n) => `${n.toLocaleString('it')} ${n === 1 ? 'occorrenza' : 'occorrenze'}`,
      lemmi: (n) => `${n.toLocaleString('it')} ${n === 1 ? 'lemma' : 'lemmi'}`,
      vie: { popolare: 'per tradizione popolare', dotta: 'per via dotta', prestito: 'prestito', altro: 'altra via' },
      senzaOrigine: 'Senza un’origine nel dizionario',
      sconosciute: 'Parole non riconosciute',
      metodo: 'Per ogni parola si risale la catena del dizionario finché esce dall’italiano: la prima lingua diversa è l’origine, e il tipo di quel passaggio dice la via d’ingresso. Una forma con più lemmi possibili (era: il sostantivo o il verbo essere) conta per ciascuno in parti uguali. Le catene non ancora verificate dalla redazione possono contenere errori.',
    },
    navAria: 'Navigazione principale',
    cercaGrande: 'Cerca una parola in qualunque lingua',
    heroLead: 'Stirps ricostruisce le famiglie di parole che discendono da una stessa radice, in tutte le lingue: passaggio per passaggio, con le fonti e il grado di certezza di ogni ipotesi.',
    heroNome: { glossa: '«la parte del tronco con le radici; la discendenza»', daQui: 'da cui' },
    esploraRadici: 'Esplora le radici',
    comeFunziona: 'Come funziona',
    ramiAria: 'Le lingue del dizionario, per ramo',
    ramiNota: (l) => `Le lingue del dizionario, per ramo: ${l} in tutto.`,
    altreLingue: 'altre lingue',
    progettoTitolo: 'Il progetto',
    progetto: [
      { titolo: 'Per radici', testo: 'Le parole non sono in ordine alfabetico ma in famiglie: tutte quelle che risalgono alla stessa radice, in qualunque lingua, si leggono insieme in uno stemma e su una mappa.' },
      { titolo: 'Con le fonti', testo: 'Ogni passaggio ha un tipo, ogni ipotesi cita le sue fonti e dichiara quanto è sicura. Quando gli studiosi non sono d’accordo, le ipotesi convivono.' },
      { titolo: 'In tutte le lingue', testo: 'Il dizionario è nato dall’italiano, ma ogni parola di ogni lingua può entrarvi: le famiglie si allargano a mano a mano che le lingue crescono.' },
    ],
    statoTitolo: 'A che punto siamo',
    statoTesto: (r, i) => `La redazione ha scritto ${r.toLocaleString('it-IT')} voci, ancora in bozza. Le altre ${i.toLocaleString('it-IT')} vengono da Wiktionary, dal Wikizionario e dai dizionari del Perseus e attendono la revisione: lo stato di ogni voce è dichiarato nella voce stessa.`,
    statoLegenda: { redazione: 'scritte dalla redazione', importate: 'importate, da rivedere' },
    paroleTitolo: 'Le parole',
    tutteLeStorie: 'Tutte le storie',
    storieNota: 'Percorsi scelti nel dizionario: ogni catena è fatta di voci vere, da aprire una per una.',
    chiSiamoTeaser: 'Stirps è ideato e diretto da Giovanni Maria Trosino, storico dell’arte a Roma. La redazione è aperta a linguisti, filologi e studiosi che vogliano rivedere e firmare le voci.',
    leggiChiSiamo: 'Chi siamo',
    piede: {
      progetto: 'Progetto', esplora: 'Esplora', dati: 'Dati',
      datiTesto: 'Etimologie da Wiktionary e glosse dal Wikizionario, con licenza CC BY-SA 4.0; lemmi latini e greci dal Lewis & Short e dal Liddell–Scott–Jones del Perseus Digital Library (CC BY-SA 4.0); definizioni da Wikidata (CC0); glosse tradotte automaticamente segnate con ≈. Licenza dei contenuti di redazione in via di definizione.',
      prototipo: 'Prototipo: i contenuti sono in bozza e vanno verificati sulle fonti.',
    },
    daConsultare: 'Da consultare',
    daConsultareNota: 'La stessa parola nelle opere di riferimento consultabili in rete.',
    bibliografia: 'Bibliografia',
    bibliografiaIntro: 'Le opere su cui la redazione verifica le voci, divise per ambito. Quelle consultabili in rete sono collegate da ogni voce, nella sezione «Da consultare».',
    ambiti: { italiano: 'Italiano', romanzo: 'Lingue romanze', latino: 'Latino', greco: 'Greco', indoeuropeo: 'Indoeuropeo', germanico: 'Lingue germaniche', slavo: 'Lingue slave', indoiranico: 'Lingue indoiraniche', semitico: 'Lingue semitiche e arabismi', rete: 'Risorse in rete' },
    inRete: 'in rete',
    pubblicoDominio: 'pubblico dominio',
    dalleVoci: 'collegata dalle voci',
    datiTesto: (p, l, r) => `${p.toLocaleString('it-IT')} parole in ${l} lingue, ${r.toLocaleString('it-IT')} radici. Le etimologie vengono da Wiktionary e le glosse italiane dal Wikizionario, con licenza CC BY-SA 4.0; i lemmi latini e greci che Wiktionary non ha, dal Lewis & Short e dal Liddell–Scott–Jones del Perseus Digital Library (CC BY-SA 4.0). La redazione li rivede e li verifica sulle fonti. La licenza dei contenuti di redazione è in via di definizione.`,
  },
  en: {
    nomeInterfaccia: 'English',
    titolo: 'Stirps',
    tornaIndice: 'Back to the index of roots',
    cercaEtichetta: 'Search for a word in any language, or for a meaning',
    cercaSegnaposto: 'Search: foot, piede, πούς, мать, liver',
    nessunRisultato: 'No word found. Try without accents or with the transliteration.',
    perSignificato: 'by meaning',
    cambiaLingua: 'Interface language',
    eroeAria: 'A featured root',
    eroeDidascalia: (n) => `The same word, passed down by inheritance, in ${n} languages.`,
    apriStemma: 'Open the family',
    altraRadice: 'Another root',
    radici: 'Roots',
    radiciNota: 'Each root heads a family of words, in every language it reached. Under each one, a few English words that descend from it.',
    aree: {
      titolo: 'Areas of meaning',
      tutte: (n) => `all ${n.toLocaleString('en-GB')} roots in this area ›`,
      senzaArea: 'No area',
      conto: (n, a) => `${n.toLocaleString('en-GB')} ${n === 1 ? 'root' : 'roots'} · ${a}, in alphabetical order`,
      nota: 'The areas of meaning were proposed by Claude from the glosses and descendants of each root; the editors can correct them.',
      tutteLeAree: '‹ all areas',
      iniziali: 'Initials',
    },
    radiciPerLingua: 'Language of the root',
    tutteLeLingueChip: 'all',
    altreLingueN: (n) => `${n} more languages`,
    radiciConto: (n, p) => `${n.toLocaleString('en-GB')} ${p ? (n === 1 ? 'family head' : 'family heads') : n === 1 ? 'root' : 'roots'}, largest family first`,
    radiceEsempi: (ps) => `in English: ${ps.join(', ')}`,
    paroleLingue: (p, l) => `${p.toLocaleString('en-GB')} ${p === 1 ? 'word' : 'words'}, ${l} ${l === 1 ? 'language' : 'languages'}`,
    paroleInLingue: (p, l) => `${p} ${p === 1 ? 'word' : 'words'} in ${l} ${l === 1 ? 'language' : 'languages'}`,
    capostipitiProvvisori: 'Provisional ancestors',
    capostipitiNota: 'Words from which a family descends, but whose own etymology has not yet been traced.',
    discendentiN: (n) => `${n} ${n === 1 ? 'descendant' : 'descendants'}`,
    lingue: 'Languages',
    lingueNota: 'The languages of the dictionary in their family tree: family, branch and descent, from the proto-language to the languages of today. You can start from any language.',
    alberoL: {
      conta: (l, p) => `${l.toLocaleString('en-GB')} ${l === 1 ? 'language' : 'languages'} · ${p.toLocaleString('en-GB')} words`,
      varieta: 'varieties',
      altre: (n) => `and ${n} more`,
      altreLingue: 'Other languages of the family',
      altreFamiglie: 'Other families',
      altreFamiglieN: (f, l) => `${f} more families · ${l.toLocaleString('en-GB')} languages`,
      indoeuropee: 'Indo-European languages',
    },
    famiglia: (f) => `${f} family`,
    indietro: 'Back',
    stemmaTitolo: (l) => `${l}, word family`,
    schede: { sintesi: 'Overview', stemma: 'Stemma', lingue: 'Languages', mappa: 'Map' },
    sintesi: {
      nellaLingua: (n) => `In English · ${n.toLocaleString('en-GB')} ${n === 1 ? 'word' : 'words'}`,
      perUso: 'Most frequent words first.',
      tutte: (n) => `all ${n.toLocaleString('en-GB')} English words`,
      rami: 'Main branches',
      ramiNota: (l) => `The words derived directly from ${l}, with how many more each one carries.`,
      altriRami: (n) => `+ ${n.toLocaleString('en-GB')} more direct ${n === 1 ? 'derivative' : 'derivatives'}, in the stemma`,
      altreLingue: (n) => `In other languages · ${n}`,
      altreLingueNota: 'For each language, the words closest to the origin come first.',
      apriFamiglia: (l) => `Open the family of ${l}`,
    },
    stemmaRidotto: 'A large family: the first two levels are shown here. Each branch opens on its own page.',
    vistaFamiglia: 'Family view',
    nessunDiscendente: 'In the current data no word descends from this form.',
    apriVoceDi: (l) => `Open the entry for ${l}`,
    discendeDa: 'Descends from ',
    ipotesiAccolta: 'accepted hypothesis',
    inAlternativa: 'Alternatively: ',
    radiceRicostruita: 'Reconstructed root.',
    formaRicostruitaCapo: 'Reconstructed form, ancestor of the family.',
    radiceFormale: 'Root.',
    capoProvvisorio: 'Provisional ancestor: its etymology has not yet been traced.',
    origini: { ignota: 'Unknown origin', sostrato: 'Substrate word', onomatopea: 'Onomatopoeia', espressiva: 'Expressive formation' },
    legenda: { eredita: 'inheritance', prestito: 'borrowing', dotto: 'learned borrowing', formazione: 'derivation or compound', indeterminata: 'indeterminate link', ricostruita: 'reconstructed form', dubbio: 'doubtful link' },
    legameDubbio: 'doubtful link: the etymology is uncertain',
    perLegameDubbio: 'belongs to this family through a doubtful etymology',
    paroleDubbie: (n) => `Of these, ${n.toLocaleString('en-GB')} ${n === 1 ? 'is' : 'are'} here through a doubtful etymology.`,
    stemmaSuggerimento: 'Hover over a word to follow its path from the root. Click to open the entry.',
    stemmaDi: (l) => `Stemma of the family of ${l}`,
    nomiPropriMostra: (n) => `Show proper names (${n.toLocaleString('en-GB')})`,
    nomiPropriNascondi: 'Hide proper names',
    altreParole: (n) => `+ ${n.toLocaleString('en-GB')} ${n === 1 ? 'word' : 'words'}`,
    eNomiPropri: (n) => `and ${n.toLocaleString('en-GB')} ${n === 1 ? 'proper name' : 'proper names'}`,
    altreDa: (n, l) => `${n === 1 ? 'One more word' : `${n.toLocaleString('en-GB')} more words`} from ${l}`,
    filtraParole: 'Filter the words',
    chiudi: 'Close',
    nessunaParola: 'No word matches.',
    apriStemmaDi: (l) => `Open the stemma of ${l}`,
    mappaPochi: 'A map needs at least two languages with a location. Proto-languages have no location.',
    mappaNota: 'Approximate locations, one point per language; arrows run from the older form to the newer one.',
    mappaProto: ' Proto-languages have no location and are not shown.',
    mappaAria: 'Map of the transfers between languages',
    formaRicostruita: 'reconstructed form',
    formaAntiquata: 'archaic form',
    pronuncia: { titolo: 'Pronunciation', sillabazione: 'hyphenation', ascolta: 'Listen to the pronunciation',
                 audio: 'audio: Wikimedia Commons', varieta: varieta(null) },
    inBreve: { titolo: 'At a glance', origine: 'Origin', radice: 'Earliest ancestor', radici: 'Earliest ancestors', attestazione: 'First attested', parenti: 'Related words',
               parentiN: (n, l) => `${n} ${n === 1 ? 'word' : 'words'} in ${l} ${l === 1 ? 'language' : 'languages'}` },
    scheda: { etichette: etichette(null), grammatica: (x) => x, sensiWiktionary: 'Senses from Wiktionary.' },
    dati: (n, l) => `${n} data, ${l}`,
    sezioni: {
      origine: 'Where it comes from', ipotesi: 'Hypotheses', ipotesiFonti: 'Hypothesis and sources', significati: 'Meanings',
      mito: 'False etymology', sorelle: 'Sister words', allotropi: 'Doublets', viaggio: 'The journey', attestazioni: 'Attestations',
      discendenti: 'Descendants', connessioni: 'Connections', fonti: 'Data sources', tempo: 'Timeline',
    },
    etimologiaAperta: 'Open etymology: no hypothesis is accepted. The alternatives are below, with their sources.',
    eRadice: 'This is a root: the family starts here.',
    etimologiaAssente: 'The etymology of this word has not yet been entered.',
    certezzaCatena: 'Certainty of the chain:',
    anelloDebole: 'A chain is only as strong as its weakest link.',
    capostipite: 'Ancestor:',
    capostipiti: 'Ancestors:',
    toccaCapo: (n) => (n > 1 ? 'Tap an ancestor to see its stemma, with the whole family.' : 'Tap it to see its stemma, with the whole family.'),
    ipotesiPrincipale: 'Main hypothesis',
    stati: { accolta: 'accepted', alternativa: 'alternative', minoritaria: 'minority view', respinta: 'rejected' },
    fiducia: { 4: 'certain', 3: 'probable', 2: 'possible', 1: 'doubtful' },
    nessunEtimo: 'no etymon.',
    da: 'from',
    dallaForma: ', from the form ',
    con: ', with ',
    nelSenso: (g) => `, in the sense ${g}`,
    per: (p) => `, by ${p}`,
    fonti: 'Sources: ',
    nessunaFonte: 'No source cited yet.',
    posizioni: { propone: 'proposes', accoglie: 'accepts', discute: 'discusses', respinge: 'rejects', attesta: 'attests' },
    riguarda: 'It concerns',
    nellaCatena: ', in this word’s chain.',
    sorelleNota: 'Computed from the graph: the same word as it reached other languages.',
    perEredita: 'By direct inheritance',
    attraversoPrestito: 'Through a borrowing',
    allotropiNota: 'Words of the same language that came from the same etymon by different routes.',
    stessoEtimo: 'same etymon:',
    nessunaAttestazione: 'No attestation entered yet.',
    primaAttestazione: 'first attestation',
    dataPassaggio: 'date of the step, according to the sources',
    forma: 'form',
    apriStemmaDa: 'Open the family of this word',
    famigliaDi: (r) => `Family of ${r}`,
    strumentiStemma: {
      titolo: 'Tree tools', cerca: 'Search the tree', nessuno: 'no words found', prossima: 'Enter: next one',
      trovati: (n, h) => `${n.toLocaleString('en-GB')} found${h ? `, ${h} in the lists` : ''}`,
      lingue: 'Language', tutte: 'All', altre: 'Other languages…', generazioni: 'Generations', tutteGen: 'all',
      risali: (x) => `Go up to the family of ${x}`, paroleIn: (l) => `All the words in ${l}`,
    },
    legame: (t) => `${t} link with`,
    tipiConnessione: { culturale: 'cultural', semantica: 'semantic', omonimia: 'homonymy', paronimia: 'paronymy', falso_amico: 'false-friend', altro: '' },
    inLingua: (n) => `in ${n}`,
    automaticaGlossa: 'Machine translation of the English gloss, to be checked',
    automaticaDefinizione: (m) => `Definition written by ${m} (Anthropic), not yet reviewed by the editors`,
    nomiLingue: { it: 'Italian', en: 'English' },
    aC: 'BC',
    tempo: {
      dC: 'AD', oggi: 'today', aria: (p) => `Timeline: ${p}`,
      legenda: 'Band: the period of the language, dashed if the language is reconstructed; periods are conventional. Filled dot: the first dated attestation; hollow circle: for undated words, the earliest possible point, i.e. the start of the language period but not before the etymon. Arrows: solid for inheritance and formation, dashed for borrowings, dotted for uncertain links. The scale narrows going back in time.',
      senzaData: 'Not placed in time:',
      scorri: '‹ Scroll left to go back in time',
    },
    dC: 'AD',
    circa: 'c.',
    ante: 'before',
    post: 'after',
    secolo: (n) => {
      const s = n % 100 >= 11 && n % 100 <= 13 ? 'th' : (['th', 'st', 'nd', 'rd'][n % 10] ?? 'th');
      return `${n}${s} c.`;
    },
    famigliaRamo: (f, r) => (f ? `${f} family` : 'Unclassified') + (r ? `, ${r} branch` : ''),
    varietaDi: (l) => `a variety of ${l}`,
    discendeDaLingua: (l) => `descends from ${l}`,
    paroleN: (n) => `${n.toLocaleString('en-GB')} ${n === 1 ? 'word' : 'words'}`,
    pos: { 's.m.': 'n. m.', 's.f.': 'n. f.', 's.n.': 'n. n.', 's.': 'n.', 'agg.': 'adj.', 'v.': 'v.', 'avv.': 'adv.', 'prep.': 'prep.', np: 'proper n.', 'rad.': 'root',
      'pron.': 'pron.', 'cong.': 'conj.', 'inter.': 'interj.', 'num.': 'num.', 'det.': 'det.', 'loc.': 'phrase', 'suff.': 'suffix', 'pref.': 'prefix' },
    anteprima: 'Preview: draft entries are visible too.',
    nonTrovato: 'Entry not found.',
    tornaHome: 'Back to the roots',
    descrizioneSito: 'Stirps, an etymological dictionary by roots: every word descends from a root and can be followed into every language, with the sources and certainty of each step.',
    etimologiaDi: (lemma, lingua) => `${lemma} (${lingua}): etymology`,
    totaliHome: (p, l, r) => `${p.toLocaleString('en-GB')} words in ${l} languages, ${r.toLocaleString('en-GB')} roots.`,
    tutteLeRadici: (n) => `All roots (${n.toLocaleString('en-GB')})`,
    tuttiICapostipiti: (n) => `All provisional ancestors (${n.toLocaleString('en-GB')})`,
    paginaDi: (p, tot) => `Page ${p} of ${tot}`,
    precedenti: '‹ Previous',
    successive: 'Next ›',
    iniziali: 'Initials',
    sottoIniziali: 'First two letters',
    indiceSezioni: 'Index sections', indiceParole: 'Words', indiceNomi: 'Proper names and derivatives', pagineIndice: 'Pages',
    fonteStrato: (n, l) => `Source: ${n} (${l})`,
    glosseAltrove: (l) => `Glosses without a translation stay ${l ? 'in ' + l : 'in the original language'}, as the source provided them.`,
    secondo: (f) => `according to ${f}`,
    almenoDal: (d) => `by ${d}`,
    stimaNota: 'Automatic estimate: the word is attested at least from this date. The first attestation may be earlier and is to be checked against the sources.',
    homeIntro: 'Every word comes from other words. Each entry here shows where a word comes from, which languages it passed through and how sure we are of it, all the way back to the root.',
    prova: 'Try',
    storie: 'Word stories',
    comeSiLegge: 'How to read it',
    lettura: [
      { titolo: 'By roots', testo: 'Words that go back to the same root form a family. The tree shows all of it, from the root to today’s languages, and the map follows its journey.' },
      { titolo: 'Every step has a type', testo: 'Inheritance, borrowing, derivation: in the tree each kind of step has its own line, and the legend below sums them up.' },
      { titolo: 'Every hypothesis has its sources', testo: 'Each hypothesis cites its sources and states how certain it is, and a chain is only as strong as its weakest link. Sister words and doublets are not written by hand: they are computed.' },
    ],
    esplora: 'Explore',
    radiciAmpie: 'The roots with the most descendants',
    lingueAmpie: 'The languages with the most words',
    tutteLeLingue: (n) => `All languages (${n})`,
    datiTitolo: 'Where the data comes from',
    sottotitolo: 'An etymological dictionary by roots',
    nav: { radici: 'Roots', lingue: 'Languages', storie: 'Stories', metodo: 'Method', norme: 'Editorial guidelines', chiSiamo: 'About', analisi: 'Analyse a text', analisiBreve: 'Analyse' },
    analisi: {
      titolo: 'Analyse a text',
      intro: 'Paste an Italian text: Stirps recognises the words, brings them back to their lemma and shows which languages they come from, following the chains in the dictionary.',
      segnaposto: 'Paste an Italian text here…',
      pulsante: 'Analyse',
      inCorso: 'Analysing…',
      limite: (n) => `At most ${n.toLocaleString('en')} characters.`,
      errore: 'The analysis failed. Please try again shortly.',
      vuoto: 'No words recognised.',
      riepilogo: (r, o, l) => `${r.toLocaleString('en')} words recognised out of ${o.toLocaleString('en')}, ${l.toLocaleString('en')} distinct lemmas.`,
      occorrenze: (n) => `${n.toLocaleString('en')} ${n === 1 ? 'occurrence' : 'occurrences'}`,
      lemmi: (n) => `${n.toLocaleString('en')} ${n === 1 ? 'lemma' : 'lemmas'}`,
      vie: { popolare: 'by popular descent', dotta: 'by learned borrowing', prestito: 'loanword', altro: 'other route' },
      senzaOrigine: 'No origin in the dictionary',
      sconosciute: 'Words not recognised',
      metodo: 'For each word the dictionary chain is followed until it leaves Italian: the first different language is the origin, and the type of that step gives the route. A form with several possible lemmas (era: the noun or the verb essere) counts for each in equal parts. Chains not yet verified by the editors may contain errors.',
    },
    navAria: 'Main navigation',
    cercaGrande: 'Search a word in any language',
    heroLead: 'Stirps reconstructs the families of words that descend from a common root, in every language: step by step, with the sources and the degree of certainty of every hypothesis.',
    heroNome: { glossa: '‘the part of the trunk with the roots; descent, lineage’', daQui: 'whence' },
    esploraRadici: 'Explore the roots',
    comeFunziona: 'How it works',
    ramiAria: 'The languages of the dictionary, by branch',
    ramiNota: (l) => `The languages of the dictionary, by branch: ${l} in all.`,
    altreLingue: 'other languages',
    progettoTitolo: 'The project',
    progetto: [
      { titolo: 'By roots', testo: 'Words are not in alphabetical order but in families: all those that go back to the same root, in any language, are read together in a tree and on a map.' },
      { titolo: 'With sources', testo: 'Every step has a type, every hypothesis cites its sources and states how certain it is. When scholars disagree, hypotheses stand side by side.' },
      { titolo: 'In every language', testo: 'The dictionary started from Italian, but any word of any language can join it: families widen as the languages grow.' },
    ],
    statoTitolo: 'Where we are',
    statoTesto: (r, i) => `The editors have written ${r.toLocaleString('en-GB')} entries, still in draft. The other ${i.toLocaleString('en-GB')} come from Wiktionary, the Italian Wiktionary and the Perseus dictionaries and await review: each entry states its own status.`,
    statoLegenda: { redazione: 'written by the editors', importate: 'imported, awaiting review' },
    paroleTitolo: 'The words',
    tutteLeStorie: 'All stories',
    storieNota: 'Selected paths through the dictionary: every chain is made of real entries, each one ready to open.',
    chiSiamoTeaser: 'Stirps is conceived and directed by Giovanni Maria Trosino, an art historian in Rome. The editorial team is open to linguists, philologists and scholars who want to review and sign entries.',
    leggiChiSiamo: 'About',
    piede: {
      progetto: 'Project', esplora: 'Explore', dati: 'Data',
      datiTesto: 'Etymologies from Wiktionary and glosses from the Italian Wiktionary, under CC BY-SA 4.0; Latin and Greek headwords from Lewis & Short and Liddell–Scott–Jones in the Perseus Digital Library (CC BY-SA 4.0); definitions from Wikidata (CC0); machine-translated glosses marked with ≈. The licence for editorial content is being defined.',
      prototipo: 'Prototype: the content is draft and must be checked against the sources.',
    },
    daConsultare: 'Look it up',
    daConsultareNota: 'The same word in reference works available online.',
    bibliografia: 'Bibliography',
    bibliografiaIntro: 'The works the editors check entries against, by field. Those available online are linked from every entry, under «Look it up».',
    ambiti: { italiano: 'Italian', romanzo: 'Romance languages', latino: 'Latin', greco: 'Greek', indoeuropeo: 'Indo-European', germanico: 'Germanic languages', slavo: 'Slavic languages', indoiranico: 'Indo-Iranian languages', semitico: 'Semitic languages and Arabisms', rete: 'Online resources' },
    inRete: 'online',
    pubblicoDominio: 'public domain',
    dalleVoci: 'linked from entries',
    datiTesto: (p, l, r) => `${p.toLocaleString('en-GB')} words in ${l} languages, ${r.toLocaleString('en-GB')} roots. Etymologies come from Wiktionary and Italian glosses from the Italian Wiktionary, under CC BY-SA 4.0; the Latin and Greek headwords that Wiktionary lacks, from Lewis & Short and Liddell–Scott–Jones in the Perseus Digital Library (CC BY-SA 4.0). The editors review them and check them against the sources. The licence for editorial content is being defined.`,
  },
}/*@@FINE*/;
