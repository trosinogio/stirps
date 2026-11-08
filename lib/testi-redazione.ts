// Testi dell'interfaccia di redazione, separati da quelli del sito pubblico
import type { Lang } from './i18n';

export interface TestiRedazione {
  redazione: string;
  accesso: string;
  accessoIntro: string;
  email: string;
  inviaCodice: string;
  codiceInviato: (email: string) => string;
  codice: string;
  entra: string;
  conPassword: string;
  password: string;
  esci: string;
  ciao: (nome: string) => string;
  esiti: Record<string, string>;
  cruscottoIntro: string;
  daVerificare: string;
  verificate: string;
  modificheSettimana: string;
  coda: string;
  codaNota: string;
  colonne: { parola: string; rango: string; stato: string; ipotesi: string; fonti: string };
  ultimeModifiche: string;
  nessunaModifica: string;
  apriVoce: string;
  cercaVoce: string;
  vediPubblica: string;
  voce: string;
  statoVoce: string;
  glossaIt: string;
  salva: string;
  ipotesi: string;
  statoIpotesi: string;
  confidenza: string;
  nota: string;
  fonti: string;
  nessunaFonte: string;
  aggiungiFonte: string;
  opera: string;
  sv: string;
  locus: string;
  posizione: string;
  togli: string;
  verifica: string;
  verificaNota: string;
  stati: Record<string, string>;
  statiIpotesi: Record<string, string>;
  posizioni: Record<string, string>;
  certezze: Record<string, string>;
  operazioni: Record<string, string>;
  tabelle: Record<string, string>;
  da: string;
  passaggi: string;
  modifica: string;
  aggiungiEtimo: string;
  cercaEtimo: string;
  nuovaVoceEtimo: string;
  cercaTraLeVoci: string;
  cambia: string;
  lingua: string;
  lemma: string;
  ricostruita: string;
  glossa: string;
  tipo: string;
  forma: string;
  affisso: string;
  annoPassaggio: string;
  precisione: string;
  precisioni: Record<string, string>;
  nuovaIpotesi: string;
  etichetta: string;
  origine: string;
  origini: Record<string, string>;
  categorie: Record<string, string>;
  attestazioni: string;
  nessunaAttestazione: string;
  aggiungiAttestazione: string;
  annoDa: string;
  annoA: string;
  testoAtt: string;
  tipoAtt: string;
  tipiAtt: Record<string, string>;
  formaAttestata: string;
  citazione: string;
  rif: string;
  fonteFacoltativa: string;
  nessuna: string;
  prime: string;
  primeNota: string;
  verificateSu: (n: number, tot: number) => string;
  colGruppo: string;
  colDate: string;
  controllare: string;
  prossima: string;
  numero: (n: number, tot: number) => string;
  codaFrequenza: string;
  catene: string;
  cateneNota: string;
  senzaEtimologia: string;
  senzaEtimologiaNota: string;
  inLista: (titolo: string, n: number, tot: number) => string;
  altre: (n: number) => string;
}

export const TESTI_REDAZIONE: Record<Lang, TestiRedazione> = {
  it: {
    redazione: 'Redazione',
    accesso: 'Accesso alla redazione',
    accessoIntro: 'Scrivi il tuo indirizzo: ti mandiamo un codice di sei cifre per entrare. Gli account dei redattori li crea l’amministratore.',
    email: 'Indirizzo email',
    inviaCodice: 'Mandami il codice',
    codiceInviato: (e) => `Se ${e} è un account della redazione, il codice è in arrivo. Controlla anche lo spam.`,
    codice: 'Codice',
    entra: 'Entra',
    conPassword: 'Accedi con password',
    password: 'Password',
    esci: 'Esci',
    ciao: (n) => `Ciao, ${n}`,
    esiti: {
      'senza-ruolo': 'Questo account non ha il ruolo di redattore. Chiedilo all’amministratore.',
      'codice-errato': 'Il codice non è valido o è scaduto. Chiedine uno nuovo.',
      'accesso-errato': 'Email o password non corrette.',
      salvato: 'Modifiche salvate.',
      'fonte-aggiunta': 'Fonte aggiunta.',
      'fonte-tolta': 'Fonte tolta.',
      verificata: 'Ipotesi verificata. La firma è nello storico.',
      'servono-fonti': 'Un’ipotesi verificata deve avere almeno un’opera della bibliografia che la propone o la accoglie; Wiktionary e le altre opere in rete non contano.',
      'servono-due-fonti': 'La certezza 4 chiede due opere che propongono o accolgono l’ipotesi: aggiungi la seconda, o lascia la certezza a 3.',
      errore: 'Qualcosa non è andato: le modifiche non sono state salvate.',
      ciclo: 'Questo passaggio creerebbe un ciclo: l’etimo discende già dalla parola.',
      'gia-presente': 'Questo etimo con questo tipo c’è già nell’ipotesi.',
      'etimo-mancante': 'Scegli un etimo tra le voci, oppure indica lingua e lemma della voce nuova.',
      'etichetta-usata': 'C’è già un’ipotesi con questa etichetta: scegline un’altra.',
      'dati-non-validi': 'Alcuni dati non sono validi: controlla anni e campi obbligatori.',
      'ipotesi-creata': 'Ipotesi creata.',
      'arco-aggiunto': 'Passaggio aggiunto.',
      'arco-tolto': 'Passaggio tolto.',
      'attestazione-aggiunta': 'Attestazione aggiunta.',
      'attestazione-tolta': 'Attestazione tolta.',
    },
    cruscottoIntro: 'La coda parte dalle parole più usate. Per ognuna: controlla l’etimologia sulle opere di riferimento, registra la fonte con la sua posizione, poi segna l’ipotesi come verificata.',
    daVerificare: 'da verificare',
    verificate: 'ipotesi verificate',
    modificheSettimana: 'modifiche negli ultimi sette giorni',
    coda: 'Coda di verifica',
    codaNota: 'Parole italiane ordinate per frequenza d’uso, con l’etimologia ancora da verificare.',
    colonne: { parola: 'Parola', rango: 'Rango', stato: 'Stato', ipotesi: 'Ipotesi accolta', fonti: 'Fonti' },
    ultimeModifiche: 'Ultime modifiche',
    nessunaModifica: 'Nessuna modifica ancora.',
    apriVoce: 'Apri una voce',
    cercaVoce: 'Cerca una parola da modificare',
    vediPubblica: 'Vedi la voce pubblica',
    voce: 'Voce',
    statoVoce: 'Stato della voce',
    glossaIt: 'Glossa italiana',
    salva: 'Salva',
    ipotesi: 'Ipotesi',
    statoIpotesi: 'Stato',
    confidenza: 'Certezza',
    nota: 'Nota',
    fonti: 'Fonti',
    nessunaFonte: 'Nessuna fonte ancora.',
    aggiungiFonte: 'Aggiungi una fonte',
    opera: 'Opera',
    sv: 's.v.',
    locus: 'Luogo (volume, pagina)',
    posizione: 'Posizione',
    togli: 'Togli',
    verifica: 'Segna come verificata',
    verificaNota: 'Richiede almeno una fonte.',
    stati: { bozza: 'bozza', importato: 'importata', rivisto: 'rivista', verificato: 'verificata', superato: 'superata' },
    statiIpotesi: { accolta: 'accolta', alternativa: 'alternativa', minoritaria: 'minoritaria', respinta: 'respinta' },
    posizioni: { propone: 'propone', accoglie: 'accoglie', discute: 'discute', respinge: 'respinge', attesta: 'attesta' },
    certezze: { '1': '1, dubbia', '2': '2, possibile', '3': '3, probabile', '4': '4, certa' },
    operazioni: { I: 'ha aggiunto', U: 'ha modificato', D: 'ha tolto' },
    tabelle: { lessema: 'la voce', ipotesi: 'un’ipotesi', rimando: 'una fonte', glossa: 'la glossa', relazione: 'un passaggio', attestazione: 'un’attestazione', accezione: 'un’accezione', connessione: 'una connessione' },
    da: 'di',
    passaggi: 'Passaggi',
    modifica: 'Modifica',
    aggiungiEtimo: 'Aggiungi un etimo',
    cercaEtimo: 'Cerca l’etimo tra le voci',
    nuovaVoceEtimo: 'Non c’è: crea una voce nuova',
    cercaTraLeVoci: 'Cerca tra le voci',
    cambia: 'cambia',
    lingua: 'Lingua',
    lemma: 'Lemma',
    ricostruita: 'forma ricostruita',
    glossa: 'Glossa',
    tipo: 'Tipo',
    forma: 'Forma citata',
    affisso: 'Affisso',
    annoPassaggio: 'Anno del passaggio',
    precisione: 'Precisione',
    precisioni: { esatta: 'esatta', circa: 'circa', ante: 'prima del', post: 'dopo il', intervallo: 'intervallo', secolo: 'secolo' },
    nuovaIpotesi: 'Nuova ipotesi',
    etichetta: 'Etichetta',
    origine: 'Origine',
    origini: { etimo: 'da un etimo', onomatopea: 'onomatopea', espressiva: 'formazione espressiva', ignota: 'origine ignota', sostrato: 'sostrato' },
    categorie: { trasmissione: 'Trasmissione', formazione: 'Formazione', indeterminata: 'Legame indeterminato', influsso: 'Influsso' },
    attestazioni: 'Prime attestazioni',
    nessunaAttestazione: 'Nessuna attestazione ancora.',
    aggiungiAttestazione: 'Aggiungi un’attestazione',
    annoDa: 'Anno',
    annoA: 'Fino al (intervallo)',
    testoAtt: 'Testo o autore (es. Brunetto Latini, Tesoretto)',
    tipoAtt: 'Tipo di testimonianza',
    tipiAtt: { letteraria: 'letteraria', documentaria: 'documentaria', epigrafica: 'epigrafica', grammaticale: 'grammaticale', lessicografica: 'lessicografica', altro: 'altro' },
    formaAttestata: 'Forma attestata',
    citazione: 'Citazione',
    rif: 'Riferimento (es. DELI, s.v.)',
    fonteFacoltativa: 'Fonte (facoltativa)',
    nessuna: 'nessuna',
    prime: 'Prime 100',
    primeNota: 'Le prime cento voci da verificare: parole d’uso comune scelte per provenienza, con un suggerimento su che cosa controllare. Una voce è verificata quando lo è la sua ipotesi accolta.',
    verificateSu: (n, tot) => `${n} su ${tot} verificate`,
    colGruppo: 'Gruppo',
    colDate: 'Date',
    controllare: 'Che cosa controllare',
    prossima: 'Prossima da verificare',
    numero: (n, tot) => `Prime 100 · n. ${n} di ${tot}`,
    codaFrequenza: 'Coda per frequenza',
    catene: 'Catene da sistemare',
    cateneNota: 'Parole la cui catena va subito a una radice ricostruita, senza tappe: l’etimologia di Wiktionary è stata letta solo in parte. Si ricostruiscono le tappe dalle fonti; una catena sistemata esce dalla lista al deploy successivo.',
    senzaEtimologia: 'Parole comuni senza etimologia',
    senzaEtimologiaNota: 'Parole d’uso comune (le prime 30.000 per frequenza) di cui né Wiktionary né il Wikizionario danno un’etimologia leggibile: l’analisi di un testo le riconosce ma le mette «senza origine». Si scrive l’etimologia con la sua fonte; la parola esce dalla lista al deploy successivo.',
    inLista: (titolo, n, tot) => `${titolo} · n. ${n} di ${tot}`,
    altre: (n) => `e altre ${n}`,
  },
  en: {
    redazione: 'Editorial',
    accesso: 'Editors’ sign-in',
    accessoIntro: 'Enter your address: we will send you a six-digit code to sign in. Editor accounts are created by the administrator.',
    email: 'Email address',
    inviaCodice: 'Send me the code',
    codiceInviato: (e) => `If ${e} is an editor account, the code is on its way. Check your spam folder too.`,
    codice: 'Code',
    entra: 'Sign in',
    conPassword: 'Sign in with a password',
    password: 'Password',
    esci: 'Sign out',
    ciao: (n) => `Hello, ${n}`,
    esiti: {
      'senza-ruolo': 'This account does not have the editor role. Ask the administrator.',
      'codice-errato': 'The code is invalid or has expired. Ask for a new one.',
      'accesso-errato': 'Wrong email or password.',
      salvato: 'Changes saved.',
      'fonte-aggiunta': 'Source added.',
      'fonte-tolta': 'Source removed.',
      verificata: 'Hypothesis verified. Your signature is in the history.',
      'servono-fonti': 'A verified hypothesis needs at least one work from the bibliography that proposes or accepts it; Wiktionary and the other online works do not count.',
      'servono-due-fonti': 'Certainty 4 requires two works that propose or accept the hypothesis: add the second one, or keep certainty at 3.',
      errore: 'Something went wrong: the changes were not saved.',
      ciclo: 'This step would create a cycle: the etymon already descends from the word.',
      'gia-presente': 'This etymon with this type is already in the hypothesis.',
      'etimo-mancante': 'Choose an etymon among the entries, or give language and lemma of the new entry.',
      'etichetta-usata': 'A hypothesis with this label already exists: choose another.',
      'dati-non-validi': 'Some data is not valid: check years and required fields.',
      'ipotesi-creata': 'Hypothesis created.',
      'arco-aggiunto': 'Step added.',
      'arco-tolto': 'Step removed.',
      'attestazione-aggiunta': 'Attestation added.',
      'attestazione-tolta': 'Attestation removed.',
    },
    cruscottoIntro: 'The queue starts from the most frequently used words. For each one: check the etymology against the reference works, record the source with its position, then mark the hypothesis as verified.',
    daVerificare: 'to verify',
    verificate: 'verified hypotheses',
    modificheSettimana: 'changes in the last seven days',
    coda: 'Verification queue',
    codaNota: 'Italian words ordered by frequency of use, whose etymology is still to be verified.',
    colonne: { parola: 'Word', rango: 'Rank', stato: 'Status', ipotesi: 'Accepted hypothesis', fonti: 'Sources' },
    ultimeModifiche: 'Latest changes',
    nessunaModifica: 'No changes yet.',
    apriVoce: 'Open an entry',
    cercaVoce: 'Search a word to edit',
    vediPubblica: 'See the public entry',
    voce: 'Entry',
    statoVoce: 'Entry status',
    glossaIt: 'Italian gloss',
    salva: 'Save',
    ipotesi: 'Hypotheses',
    statoIpotesi: 'Status',
    confidenza: 'Certainty',
    nota: 'Note',
    fonti: 'Sources',
    nessunaFonte: 'No sources yet.',
    aggiungiFonte: 'Add a source',
    opera: 'Work',
    sv: 's.v.',
    locus: 'Locus (volume, page)',
    posizione: 'Position',
    togli: 'Remove',
    verifica: 'Mark as verified',
    verificaNota: 'Requires at least one source.',
    stati: { bozza: 'draft', importato: 'imported', rivisto: 'reviewed', verificato: 'verified', superato: 'superseded' },
    statiIpotesi: { accolta: 'accepted', alternativa: 'alternative', minoritaria: 'minority', respinta: 'rejected' },
    posizioni: { propone: 'proposes', accoglie: 'accepts', discute: 'discusses', respinge: 'rejects', attesta: 'attests' },
    certezze: { '1': '1, doubtful', '2': '2, possible', '3': '3, probable', '4': '4, certain' },
    operazioni: { I: 'added', U: 'changed', D: 'removed' },
    tabelle: { lessema: 'the entry', ipotesi: 'a hypothesis', rimando: 'a source', glossa: 'the gloss', relazione: 'a step', attestazione: 'an attestation', accezione: 'a sense', connessione: 'a connection' },
    da: 'of',
    passaggi: 'Steps',
    modifica: 'Edit',
    aggiungiEtimo: 'Add an etymon',
    cercaEtimo: 'Search the etymon among the entries',
    nuovaVoceEtimo: 'Not there: create a new entry',
    cercaTraLeVoci: 'Search the entries',
    cambia: 'change',
    lingua: 'Language',
    lemma: 'Lemma',
    ricostruita: 'reconstructed form',
    glossa: 'Gloss',
    tipo: 'Type',
    forma: 'Cited form',
    affisso: 'Affix',
    annoPassaggio: 'Year of the step',
    precisione: 'Precision',
    precisioni: { esatta: 'exact', circa: 'circa', ante: 'before', post: 'after', intervallo: 'range', secolo: 'century' },
    nuovaIpotesi: 'New hypothesis',
    etichetta: 'Label',
    origine: 'Origin',
    origini: { etimo: 'from an etymon', onomatopea: 'onomatopoeia', espressiva: 'expressive formation', ignota: 'unknown origin', sostrato: 'substrate' },
    categorie: { trasmissione: 'Transmission', formazione: 'Formation', indeterminata: 'Indeterminate link', influsso: 'Influence' },
    attestazioni: 'First attestations',
    nessunaAttestazione: 'No attestations yet.',
    aggiungiAttestazione: 'Add an attestation',
    annoDa: 'Year',
    annoA: 'Until (range)',
    testoAtt: 'Text or author (e.g. Brunetto Latini, Tesoretto)',
    tipoAtt: 'Kind of evidence',
    tipiAtt: { letteraria: 'literary', documentaria: 'documentary', epigrafica: 'epigraphic', grammaticale: 'grammatical', lessicografica: 'lexicographic', altro: 'other' },
    formaAttestata: 'Attested form',
    citazione: 'Quotation',
    rif: 'Reference (e.g. DELI, s.v.)',
    fonteFacoltativa: 'Source (optional)',
    nessuna: 'none',
    prime: 'First 100',
    primeNota: 'The first hundred entries to verify: everyday words chosen by origin, each with a hint on what to check. An entry is verified when its accepted hypothesis is.',
    verificateSu: (n, tot) => `${n} of ${tot} verified`,
    colGruppo: 'Group',
    colDate: 'Dates',
    controllare: 'What to check',
    prossima: 'Next to verify',
    numero: (n, tot) => `First 100 · no. ${n} of ${tot}`,
    codaFrequenza: 'Queue by frequency',
    catene: 'Chains to fix',
    cateneNota: 'Words whose chain jumps straight to a reconstructed root, with no steps: Wiktionary’s etymology was read only in part. The steps are rebuilt from the sources; a fixed chain leaves the list at the next deploy.',
    senzaEtimologia: 'Common words without an etymology',
    senzaEtimologiaNota: 'Everyday words (the first 30,000 by frequency) for which neither Wiktionary nor the Italian Wiktionary gives a readable etymology: text analysis recognizes them but files them as “no known origin”. Write the etymology with its source; the word leaves the list at the next deploy.',
    inLista: (titolo, n, tot) => `${titolo} · no. ${n} of ${tot}`,
    altre: (n) => `and ${n} more`,
  },
};

export type EtichetteEtimo = Pick<TestiRedazione, 'lingua' | 'lemma' | 'ricostruita' | 'glossa' | 'cercaEtimo' | 'nuovaVoceEtimo' | 'cercaTraLeVoci' | 'cambia'>;

// solo stringhe: i testi con funzioni non possono passare a un componente del browser
export function etichetteEtimo(t: TestiRedazione): EtichetteEtimo {
  const { lingua, lemma, ricostruita, glossa, cercaEtimo, nuovaVoceEtimo, cercaTraLeVoci, cambia } = t;
  return { lingua, lemma, ricostruita, glossa, cercaEtimo, nuovaVoceEtimo, cercaTraLeVoci, cambia };
}
