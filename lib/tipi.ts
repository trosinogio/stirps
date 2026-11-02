// Il contratto JSON delle funzioni SQL scheda(), indice() e cerca_universale().

export interface Nodo {
  id: number;
  slug: string;
  lingua: string;
  lingua_nome: string;
  lingua_sigla: string;
  ramo: string | null;
  lemma: string;
  ricostruito: boolean;
  translit?: string | null;
  glossa?: string | null;
  glossa_lingua?: string | null;
  glossa_automatica?: boolean;
}
export interface NodoCatena extends Nodo { profondita: number; esito: number; tipo: string; tipo_etichetta?: string | null; confidenza_catena: number; attestata?: { anno_da: number; anno_a: number | null; precisione: string } | null; passaggio_data?: { anno_da: number; anno_a: number | null; precisione: string | null } | null }
export interface NodoDiscendente extends Nodo { profondita: number; etimo: number; tipo: string; tipo_etichetta?: string | null }
export interface Cognato extends Nodo { tipo: 'stretto' | 'per_prestito'; antenato_comune: Nodo; distanza: number }
export interface Allotropo extends Nodo { antenato_comune: Nodo }
export interface Connessione extends Nodo { tipo: string; descrizione: string }
export interface Rimando { opera: string; autore?: string | null; titolo?: string | null; anno?: number | null; sv?: string | null; locus?: string | null; posizione: string; nota?: string | null }
export interface Relazione {
  tipo: string; tipo_etichetta: string; categoria: string; etimo: Nodo;
  forma_citata?: string | null; affisso?: string | null; ordine: number; confidenza: number;
  processo?: string | null; processo_etichetta?: string | null; etimo_accezione?: string | null;
  anno_da?: number | null; anno_a?: number | null; luogo?: string | null; nota?: string | null;
  provenienza: string; rimandi: Rimando[];
}
export interface Ipotesi {
  id: number; etichetta: string; stato: 'accolta' | 'alternativa' | 'minoritaria' | 'respinta';
  confidenza: number; origine: string; diffusa: boolean; nota?: string | null; nota_lingua?: string | null;
  provenienza?: string; stato_editoriale: string;
  relazioni: Relazione[]; rimandi: Rimando[];
}
export interface Accezione { id: number; n: number; glossa: string; glossa_lingua: string; ambito?: string | null; deriva_da?: number | null; processo?: string | null; processo_etichetta?: string | null }
export interface Attestazione {
  forma_attestata?: string | null; testo: string; rif?: string | null; tipo: string; banca_dati?: string | null; url?: string | null;
  anno_da: number; anno_a?: number | null; precisione: string; citazione?: string | null; nota?: string | null; rimandi: Rimando[];
  provenienza?: string;
  // stima: terminus ante quem trovato in automatico, da verificare («attestato almeno dal …»)
  stima?: boolean; confidenza?: number | null;
}
export interface Strato { codice: string; nome: string; licenza: string; share_alike: boolean; attribuzione?: string | null }
export interface Lessema extends Nodo {
  wiktionary_lingua?: string; pos?: string | null; obsoleto: boolean; nota?: string | null; stato_editoriale: string; provenienza: string }
export interface Consultabile { sigla: string; titolo: string; autore?: string | null; anno?: number | null; modello: string; tipo: string }
export interface Opera {
  sigla: string; autore: string | null; titolo: string; edizione: string | null; anno: number | null; editore: string | null;
  url: string | null; pubblico_dominio: boolean; ambito: string | null; nota: string | null; modello_url: string | null; tipo: string;
}
export interface Scheda {
  consultabili?: Consultabile[];
  lingua_richiesta: string;
  lingua_redazione: string | null;
  lessema: Lessema;
  accezioni: Accezione[];
  ipotesi: Ipotesi[];
  catena: NodoCatena[];
  discendenti: NodoDiscendente[];
  cognati: Cognato[];
  allotropi: Allotropo[];
  attestazioni: Attestazione[];
  connessioni: Connessione[];
  falsi_miti: { riguarda: string; etichetta: string; nota?: string | null }[];
  strati: Strato[];
}
export interface RadiceIndice extends Nodo { dichiarata: boolean; discendenti: number; lingue: number; rami: Record<string, number> }
export interface LinguaIndice {
  codice: string; nome: string; sigla: string; famiglia: string | null; famiglia_nome: string | null;
  ramo: string; ramo_nome: string | null; antenato: string | null; varieta_di: string | null; n: number;
}
export interface LinguaInfo {
  codice: string; nome: string; sigla: string; famiglia: string | null; famiglia_nome: string | null; ramo: string;
  ramo_nome: string | null; antenato: string | null; varieta_di: string | null; antenato_nome: string | null; varieta_di_nome: string | null;
}
export interface Indice { radici: RadiceIndice[]; lingue: LinguaIndice[]; totali: { lessemi: number; lingue: number; radici: number; capostipiti: number } }
export interface ElencoRadici { totale: number; pagina: number; per_pagina: number; radici: (Nodo & { discendenti: number; lingue: number })[] }
export interface ParoleLingua {
  totale: number; totale_parole: number; totale_nomi: number; iniziale: string | null; iniziali: { iniziale: string; n: number }[];
  // un'iniziale con molte parole si sfoglia per le prime due lettere
  sottoiniziale: string | null; sottoiniziali: { iniziale: string; n: number }[];
  // un gruppo con più di 500 voci si divide in pagine: per ciascuna la prima e l'ultima parola
  pagina: number; pagine: { da: string; a: string }[];
  parole: Nodo[];
}
export interface RisultatoRicerca { slug: string; punteggio: number; per_significato: boolean; voce: Nodo }
export interface LinguaGeo { codice: string; nome: string; lat: number | null; lon: number | null; varieta_di: string | null; antenato: string | null }

// Nodo dello stemma: piatto e serializzabile, passa dal server al browser.
export interface NodoPiatto {
  id: number; slug: string; lemma: string; lingua: string; lingua_sigla: string; lingua_nome: string;
  ramo: string | null; ricostruito: boolean; glossa?: string | null;
  tipo: string | null; tipo_etichetta?: string | null; padre: number | null;
}
