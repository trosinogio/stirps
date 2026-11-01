// Accesso ai dati: ogni pagina chiama una funzione SQL e riceve JSON pronto.
import { query } from './db';
import type { Lang } from './i18n';
import type { ElencoRadici, Indice, LinguaGeo, Nodo, Opera, ParoleLingua, RisultatoRicerca, Scheda } from './tipi';

// ANTEPRIMA=1 mostra anche le bozze (il seme pilota è tutto in bozza)
export const ANTEPRIMA = process.env.ANTEPRIMA === '1';

export async function scheda(slug: string, lang: Lang): Promise<Scheda | null> {
  const r = await query<{ s: Scheda | null }>('select scheda($1, $2, $3) as s', [slug, ANTEPRIMA, lang]);
  return r[0]?.s ?? null;
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

export async function elencoRadici(lang: Lang, dichiarate: boolean, pagina: number): Promise<ElencoRadici> {
  const r = await query<{ e: ElencoRadici }>('select elenco_radici($1, $2, $3, $4, $5) as e',
    [lang, ANTEPRIMA, dichiarate, pagina, PER_PAGINA]);
  return r[0].e;
}

export async function paroleLingua(codice: string, lang: Lang, iniziale: string | null): Promise<ParoleLingua> {
  const r = await query<{ p: ParoleLingua }>('select parole_lingua($1, $2, $3, $4) as p', [codice, lang, ANTEPRIMA, iniziale]);
  return r[0].p;
}

export async function cerca(q: string, lang: Lang): Promise<RisultatoRicerca[]> {
  return query<RisultatoRicerca>(
    'select slug, punteggio, per_significato, voce from cerca_universale($1, $2, 12, $3)', [q, lang, ANTEPRIMA]);
}

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
