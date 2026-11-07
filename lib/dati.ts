import { cache } from 'react';
// Accesso ai dati: ogni pagina chiama una funzione SQL e riceve JSON pronto.
import { query } from './db';
import type { Lang } from './i18n';
import type { AnalisiTesto, ElencoRadici, Indice, LinguaGeo, LinguaInfo, Nodo, Opera, ParoleLingua, Pronuncia, RisultatoRicerca, Scheda, Sensi } from './tipi';

// ANTEPRIMA=1 mostra anche le bozze (il seme pilota è tutto in bozza)
export const ANTEPRIMA = process.env.ANTEPRIMA === '1';

export async function scheda(slug: string, lang: Lang): Promise<Scheda | null> {
  const r = await query<{ s: Scheda | null }>('select scheda($1, $2, $3) as s', [slug, ANTEPRIMA, lang]);
  return r[0]?.s ?? null;
}

// La pronuncia della voce (tabella pronuncia), letta accanto alla scheda: null se Wiktionary non ne dà
export async function pronuncia(slug: string): Promise<Pronuncia | null> {
  const r = await query<Pronuncia>(
    'select p.ipa, p.sillabazione, p.audio from pronuncia p join lessema l on l.id = p.lessema_id where l.slug = $1', [slug]);
  return r[0] ?? null;
}

// La riga delle forme e le accezioni di Wiktionary (tabella sensi): null se non ci sono
export async function sensi(slug: string): Promise<Sensi | null> {
  const r = await query<Sensi>('select x.testa, x.sensi from sensi x join lessema l on l.id = x.lessema_id where l.slug = $1', [slug]);
  return r[0] ?? null;
}

// Il rango d'uso di alcune forme di una lingua (tabella frequenza: oggi solo l'italiano); le forme assenti non compaiono
export async function ranghi(lingua: string, forme: string[]): Promise<Map<string, number>> {
  if (!forme.length) return new Map();
  const r = await query<{ forma: string; rango: number }>(
    'select forma, rango from frequenza where lingua = $1 and forma = any($2::text[])', [lingua, forme]);
  return new Map(r.map((x) => [x.forma, x.rango]));
}

export async function indice(lang: Lang, limite = 40): Promise<Indice> {
  const r = await query<{ i: Indice }>('select indice($1, $2, $3) as i', [lang, ANTEPRIMA, limite]);
  return r[0].i;
}

export const PER_PAGINA = 100;

// La bibliografia: le opere di riferimento, per ambito
export async function opere(): Promise<Opera[]> {
  return query<Opera>(`select sigla, autore, titolo, edizione, anno, editore, url, pubblico_dominio, ambito, nota, modello_url, tipo
                         from opera order by ambito, anno nulls last, sigla`);
}

// A che punto è il lavoro: voci scritte dalla redazione e voci importate da rivedere
export async function statoLavori(): Promise<{ redazione: number; importate: number }> {
  const r = await query<{ redazione: number; importate: number }>(
    `select count(*) filter (where provenienza = 'redazione')::int as redazione,
            count(*) filter (where provenienza <> 'redazione')::int as importate
       from lessema where visibile(stato_editoriale, $1)`, [ANTEPRIMA]);
  return r[0];
}

// Nodi per indirizzo, in una sola query (storie ed esempi della pagina iniziale)
export async function nodiPerSlug(slugs: string[], lang: Lang): Promise<Map<string, Nodo>> {
  const r = await query<{ n: Nodo }>('select nodo_json(id, $2, $3) as n from lessema where slug = any($1)', [slugs, lang, ANTEPRIMA]);
  return new Map(r.map((x) => [x.n.slug, x.n]));
}

// capoLingua: solo i capostipiti di quella lingua (null: tutti)
export async function elencoRadici(lang: Lang, dichiarate: boolean, pagina: number, capoLingua: string | null = null): Promise<ElencoRadici> {
  const r = await query<{ e: ElencoRadici }>('select elenco_radici($1, $2, $3, $4, $5, $6) as e',
    [lang, ANTEPRIMA, dichiarate, pagina, PER_PAGINA, capoLingua]);
  return r[0].e;
}

export async function paroleLingua(codice: string, lang: Lang, iniziale: string | null, nomi = false, pagina = 1): Promise<ParoleLingua> {
  const r = await query<{ p: ParoleLingua }>('select parole_lingua($1, $2, $3, $4, $5, $6) as p', [codice, lang, ANTEPRIMA, iniziale, nomi, pagina]);
  return r[0].p;
}

export async function cerca(q: string, lang: Lang): Promise<RisultatoRicerca[]> {
  return query<RisultatoRicerca>(
    'select slug, punteggio, per_significato, voce from cerca_universale($1, $2, 12, $3)', [q, lang, ANTEPRIMA]);
}

// la testata della pagina di una lingua: una query sola, condivisa da metadati e pagina
export const linguaInfo = cache(async (codice: string, lang: Lang): Promise<LinguaInfo | null> => {
  const r = await query<{ l: LinguaInfo | null }>('select lingua_json($1, $2, $3) as l', [codice, lang, ANTEPRIMA]);
  return r[0]?.l ?? null;
});

export async function lingueGeo(lang: Lang): Promise<LinguaGeo[]> {
  return query<LinguaGeo>(
    `select codice, coalesce(etichetta_in('lingua', codice, $1), nome) as nome,
            lat::float8 as lat, lon::float8 as lon, varieta_di, antenato
       from lingua`, [lang]);
}

// periodi convenzionali delle lingue, per la linea del tempo
export async function periodiLingue(codici: string[]): Promise<Map<string, { anno_da: number | null; anno_a: number | null; ricostruita: boolean }>> {
  const r = await query<{ codice: string; anno_da: number | null; anno_a: number | null; ricostruita: boolean }>(
    `select codice, anno_da, anno_a, ricostruita from lingua where codice = any($1)`, [codici]);
  return new Map(r.map((x) => [x.codice, x]));
}

// La mappa del sito: voci, famiglie e lingue visibili, a blocchi
export async function contaVociMappa(): Promise<number> {
  const r = await query<{ n: number }>('select count(*)::int as n from lessema where visibile(stato_editoriale, $1)', [ANTEPRIMA]);
  return r[0].n;
}
export async function vociMappa(blocco: number, quante: number): Promise<{ slug: string; agg: string }[]> {
  return query<{ slug: string; agg: string }>(
    `select slug, aggiornato_il::date::text as agg from lessema where visibile(stato_editoriale, $1)
      order by id limit $2 offset $3`, [ANTEPRIMA, quante, blocco * quante]);
}
export async function radiciELingueMappa(): Promise<{ radici: string[]; lingue: string[] }> {
  const [r, l] = await Promise.all([
    query<{ slug: string }>(`select l.slug from (select capo from mv_famiglia group by capo having count(*) > 1) f
                               join lessema l on l.id = f.capo where visibile(l.stato_editoriale, $1) order by l.slug`, [ANTEPRIMA]),
    query<{ codice: string }>(`select distinct lingua as codice from lessema where visibile(stato_editoriale, $1) order by 1`, [ANTEPRIMA]),
  ]);
  return { radici: r.map((x) => x.slug), lingue: l.map((x) => x.codice) };
}

// L'analisi di un testo italiano: forme distinte e quante volte compaiono (la pagina «Analizza un testo»)
export async function analizzaTesto(forme: string[], conteggi: number[], lang: Lang): Promise<AnalisiTesto> {
  const r = await query<{ r: AnalisiTesto }>('select analizza_testo($1, $2, $3, $4, $5) as r', ['it', forme, conteggi, lang, ANTEPRIMA]);
  return r[0].r;
}
