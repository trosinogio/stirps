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
  paroleLingue: (p: number, l: number) => string;
  paroleInLingue: (p: number, l: number) => string;
  capostipitiProvvisori: string;
  capostipitiNota: string;
  discendentiN: (n: number) => string;
  lingue: string;
  lingueNota: string;
  famiglia: (f: string) => string;
  indietro: string;
  stemmaTitolo: (lemma: string) => string;
  schede: { stemma: string; lingue: string; mappa: string };
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
  legenda: { eredita: string; prestito: string; dotto: string; formazione: string; indeterminata: string; ricostruita: string };
  stemmaSuggerimento: string;
  stemmaDi: (lemma: string) => string;
  mappaPochi: string;
  mappaNota: string;
  mappaProto: string;
  mappaAria: string;
  formaRicostruita: string;
  formaAntiquata: string;
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
  legame: (tipo: string) => string;
  tipiConnessione: Record<string, string>;
  inLingua: (nome: string) => string;
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
  nav: { radici: string; lingue: string; storie: string; metodo: string; chiSiamo: string };
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
    apriStemma: 'Apri lo stemma',
    altraRadice: 'Un’altra radice',
    radici: 'Radici',
    radiciNota: 'Forme ricostruite e radici dichiarate, di qualunque famiglia linguistica. Ogni famiglia raccoglie le parole ereditate, prese in prestito e derivate.',
    paroleLingue: (p, l) => `${p.toLocaleString('it-IT')} ${p === 1 ? 'parola' : 'parole'}, ${l} ${l === 1 ? 'lingua' : 'lingue'}`,
    paroleInLingue: (p, l) => `${p} ${p === 1 ? 'parola' : 'parole'} in ${l} ${l === 1 ? 'lingua' : 'lingue'}`,
    capostipitiProvvisori: 'Capostipiti provvisori',
    capostipitiNota: 'Parole da cui discende una famiglia, ma la cui etimologia non è ancora stata risalita.',
    discendentiN: (n) => `${n} ${n === 1 ? 'discendente' : 'discendenti'}`,
    lingue: 'Lingue',
    lingueNota: 'Si può entrare da qualunque lingua: nessuna è privilegiata.',
    famiglia: (f) => `Famiglia ${f.toLowerCase()}`,
    indietro: 'Indietro',
    stemmaTitolo: (l) => `${l}, stemma della famiglia`,
    schede: { stemma: 'Stemma', lingue: 'Lingue', mappa: 'Mappa' },
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
    legenda: { eredita: 'eredità', prestito: 'prestito', dotto: 'prestito dotto', formazione: 'derivazione o composizione', indeterminata: 'legame indeterminato', ricostruita: 'forma ricostruita' },
    stemmaSuggerimento: 'Passa sopra una parola per seguirne il percorso dalla radice. Fai clic per aprire la voce.',
    stemmaDi: (l) => `Stemma della famiglia di ${l}`,
    mappaPochi: 'Servono almeno due lingue con un luogo per disegnare una mappa. Le protolingue non hanno una collocazione.',
    mappaNota: 'Luoghi indicativi, un punto per lingua; le frecce vanno dalla forma più antica alla più recente.',
    mappaProto: ' Le protolingue non hanno una collocazione e non compaiono.',
    mappaAria: 'Mappa dei passaggi tra le lingue',
    formaRicostruita: 'forma ricostruita',
    formaAntiquata: 'forma antiquata',
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
    apriStemmaDa: 'Apri lo stemma da questa parola',
    legame: (t) => `legame ${t} con`,
    tipiConnessione: { culturale: 'culturale', semantica: 'semantico', omonimia: 'di omonimia', paronimia: 'di paronimia', falso_amico: 'di falso amico', altro: '' },
    inLingua: (n) => `in ${n}`,
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
    indiceSezioni: 'Sezioni dell’indice', indiceParole: 'Parole', indiceNomi: 'Nomi propri', pagineIndice: 'Pagine',
    fonteStrato: (n, l) => `Fonte: ${n} (${l})`,
    glosseAltrove: (l) => `Le glosse senza traduzione restano ${l ? 'in ' + l : 'nella lingua d’origine'}, come le ha fornite la fonte.`,
    secondo: (f) => `secondo ${f}`,
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
    nav: { radici: 'Radici', lingue: 'Lingue', storie: 'Storie', metodo: 'Metodo', chiSiamo: 'Chi siamo' },
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
    apriStemma: 'Open the stemma',
    altraRadice: 'Another root',
    radici: 'Roots',
    radiciNota: 'Reconstructed forms and declared roots, from any language family. Each family gathers the inherited, borrowed and derived words.',
    paroleLingue: (p, l) => `${p.toLocaleString('en-GB')} ${p === 1 ? 'word' : 'words'}, ${l} ${l === 1 ? 'language' : 'languages'}`,
    paroleInLingue: (p, l) => `${p} ${p === 1 ? 'word' : 'words'} in ${l} ${l === 1 ? 'language' : 'languages'}`,
    capostipitiProvvisori: 'Provisional ancestors',
    capostipitiNota: 'Words from which a family descends, but whose own etymology has not yet been traced.',
    discendentiN: (n) => `${n} ${n === 1 ? 'descendant' : 'descendants'}`,
    lingue: 'Languages',
    lingueNota: 'You can start from any language: none is privileged.',
    famiglia: (f) => `${f} family`,
    indietro: 'Back',
    stemmaTitolo: (l) => `${l}, family stemma`,
    schede: { stemma: 'Stemma', lingue: 'Languages', mappa: 'Map' },
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
    legenda: { eredita: 'inheritance', prestito: 'borrowing', dotto: 'learned borrowing', formazione: 'derivation or compound', indeterminata: 'indeterminate link', ricostruita: 'reconstructed form' },
    stemmaSuggerimento: 'Hover over a word to follow its path from the root. Click to open the entry.',
    stemmaDi: (l) => `Stemma of the family of ${l}`,
    mappaPochi: 'A map needs at least two languages with a location. Proto-languages have no location.',
    mappaNota: 'Approximate locations, one point per language; arrows run from the older form to the newer one.',
    mappaProto: ' Proto-languages have no location and are not shown.',
    mappaAria: 'Map of the transfers between languages',
    formaRicostruita: 'reconstructed form',
    formaAntiquata: 'archaic form',
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
    apriStemmaDa: 'Open the stemma from this word',
    legame: (t) => `${t} link with`,
    tipiConnessione: { culturale: 'cultural', semantica: 'semantic', omonimia: 'homonymy', paronimia: 'paronymy', falso_amico: 'false-friend', altro: '' },
    inLingua: (n) => `in ${n}`,
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
    indiceSezioni: 'Index sections', indiceParole: 'Words', indiceNomi: 'Proper names', pagineIndice: 'Pages',
    fonteStrato: (n, l) => `Source: ${n} (${l})`,
    glosseAltrove: (l) => `Glosses without a translation stay ${l ? 'in ' + l : 'in the original language'}, as the source provided them.`,
    secondo: (f) => `according to ${f}`,
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
    nav: { radici: 'Roots', lingue: 'Languages', storie: 'Stories', metodo: 'Method', chiSiamo: 'About' },
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
