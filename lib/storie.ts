// Storie di parole composte dai dati: le sceglie la funzione storie() da mv_storie, a partire da un seme
import { query } from './db';
import type { Lang } from './i18n';
import type { Nodo } from './tipi';

export interface NodoStoria extends Nodo {
  tipo?: string | null;          // il passaggio verso la parola successiva del percorso
  tipo_nome?: string | null;
  attestata?: { anno_da: number; anno_a: number | null; precisione: string } | null;
  glossa_lingua?: string | null;
}
export type Percorso = NodoStoria[];   // dal più antico alla parola di oggi

export type Storia =
  | { tipo: 'due_strade'; chiave: string; antenato: NodoStoria; a: Percorso; b: Percorso }
  | { tipo: 'parenti'; chiave: string; radice: NodoStoria; a: Percorso; b: Percorso }
  | { tipo: 'viaggio'; chiave: string; percorso: Percorso }
  | { tipo: 'famiglia'; chiave: string; radice: NodoStoria; n: number; parole: NodoStoria[] };

export const TIPI_STORIA = ['due_strade', 'parenti', 'viaggio', 'famiglia'] as const;
export type TipoStoria = (typeof TIPI_STORIA)[number];
export const isTipo = (t: unknown): t is TipoStoria => TIPI_STORIA.includes(t as TipoStoria);

export interface Indovinello {
  parola: NodoStoria; giusta: NodoStoria; sbagliate: NodoStoria[]; radice: NodoStoria;
  percorso_parola: Percorso; percorso_giusta: Percorso;
}

const anteprima = () => process.env.ANTEPRIMA === '1';

export async function storie(lang: Lang, seme: number, n: number, tipo?: TipoStoria): Promise<Storia[]> {
  try {
    const r = await query<{ s: Storia[] }>('select storie($1, $2, $3, $4, $5) as s', [lang, seme, n, tipo ?? null, anteprima()]);
    return r[0]?.s ?? [];
  } catch {
    return [];      // database senza mv_storie (prima dell'aggiornamento): la pagina mostra le storie della redazione
  }
}

// la storia del giorno: cambia a mezzanotte, e ogni giorno tocca a un tipo diverso
export async function storiaDelGiorno(lang: Lang): Promise<Storia | null> {
  const giorno = Math.floor(Date.now() / 86400000);
  const [s] = await storie(lang, giorno, 1, TIPI_STORIA[giorno % TIPI_STORIA.length]);
  return s ?? null;
}

export async function indovinello(lang: Lang, seme: number): Promise<Indovinello | null> {
  try {
    const r = await query<{ g: Indovinello | null }>('select indovinello($1, $2, $3) as g', [lang, seme, anteprima()]);
    const g = r[0]?.g;
    return g && g.sbagliate?.length === 2 ? g : null;
  } catch {
    return null;
  }
}

// un numero stabile da una chiave: sceglie la variante del titolo e mescola le opzioni senza differenze tra server e browser
export function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
