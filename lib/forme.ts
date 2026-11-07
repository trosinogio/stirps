// Regole di forma condivise tra server e browser.
import type { Lang, Testi } from './i18n';
import type { Attestazione, Nodo, Scheda } from './tipi';

export const ORDINE_RAMI = ['proto', 'italica', 'ellenica', 'germanica', 'slava', 'indoiranica', 'semitica'];
// le lingue principali di ogni ramo, prima gli antenati: ordinano elenchi, stemmi e mappe (le altre vengono dopo)
export const ORDINE_LINGUE = ['ine-pro',
  'itc-pro', 'itc-ola', 'la', 'la-vul', 'la-lat', 'la-med', 'la-new', 'roa-oit', 'it', 'fro', 'xno', 'frm', 'fr', 'pro', 'oc', 'ca',
  'osp', 'es', 'roa-opt', 'pt', 'ro',
  'grk-pro', 'gmy', 'grc', 'gkm', 'el',
  'gem-pro', 'got', 'non', 'gmw-pro', 'ang', 'enm', 'en', 'sco', 'goh', 'gmh', 'de', 'osx', 'gml', 'odt', 'dum', 'nl', 'frk', 'lng',
  'cel-pro', 'cel-gau', 'ga', 'cy',
  'ine-bsl-pro', 'sla-pro', 'cu', 'orv', 'ru', 'uk', 'pl', 'cs', 'sh',
  'iir-pro', 'sa', 'hi', 'ira-pro', 'peo', 'pal', 'fa',
  'sem-pro', 'akk', 'hbo', 'he', 'arc', 'ar'];

// Stesse categorie della tabella tipo_relazione
export const CATEGORIA: Record<string, 'trasmissione' | 'formazione' | 'indeterminata' | 'influsso'> = {
  eredita: 'trasmissione', variante: 'trasmissione', prestito: 'trasmissione', prestito_dotto: 'trasmissione',
  semidotto: 'trasmissione', trasmissione: 'trasmissione', generico: 'indeterminata', derivazione: 'formazione', composizione: 'formazione',
  retroformazione: 'formazione', accorciamento: 'formazione', deonimico: 'formazione', calco: 'formazione',
  calco_semantico: 'influsso', influsso: 'influsso', paretimologia: 'influsso',
};
export const EREDITARIO = new Set(['eredita', 'variante']);

export const ramoDi = (r?: string | null) => (r && ORDINE_RAMI.includes(r) ? r : 'proto');
export const classeRamo = (r?: string | null) => 'r-' + ramoDi(r);

const APICI = '⁰¹²³⁴⁵⁶⁷⁸⁹';
export const omografo = (slug?: string | null) => {
  const m = /-(\d+)$/.exec(slug ?? '');
  return m ? [...m[1]].map((c) => APICI[+c]).join('') : '';
};
export const fmt = (n: { lemma: string; ricostruito?: boolean | null; slug?: string | null }) =>
  (n.ricostruito ? '*' : '') + n.lemma + omografo(n.slug);

// Apostrofi e virgolette tipografiche nei testi che vengono dai dati
export const tx = (v?: string | null) => (v == null ? '' : String(v).replace(/'/g, '’'));
export const G = (v: string | null | undefined, lang: Lang) =>
  lang === 'it'
    ? '«' + tx(v).replace(/«/g, '“').replace(/»/g, '”') + '»'
    : '“' + tx(v).replace(/«/g, '‘').replace(/»/g, '’').replace(/“/g, '‘').replace(/”/g, '’') + '”';

const idxR = (r?: string | null) => ORDINE_RAMI.indexOf(ramoDi(r));
const idxL = (c: string) => { const i = ORDINE_LINGUE.indexOf(c); return i < 0 ? 999 : i; };
export const perLingua = (a: Pick<Nodo, 'ramo' | 'lingua' | 'lemma'>, b: Pick<Nodo, 'ramo' | 'lingua' | 'lemma'>) =>
  idxR(a.ramo) - idxR(b.ramo) || idxL(a.lingua) - idxL(b.lingua) || a.lingua.localeCompare(b.lingua) || a.lemma.localeCompare(b.lemma);

export function classeArco(t?: string | null) {
  if (!t) return '';
  if (t === 'eredita') return 'e-eredita';
  if (t === 'variante') return 'e-variante';
  if (t === 'prestito_dotto' || t === 'semidotto') return 'e-dotto';
  if (t === 'generico') return 'e-indeterminata';
  if (t === 'trasmissione') return 'e-trasmissione';
  if (CATEGORIA[t] === 'formazione') return 'e-formazione';
  return 'e-prestito';
}

export function nodiUnici<T extends { id: number }>(lista: T[] | null | undefined): T[] {
  const m = new Map<number, T>();
  for (const d of lista ?? []) if (!m.has(d.id)) m.set(d.id, d);
  return [...m.values()];
}

// La stessa parola trasmessa per eredità (il primo passo dalla radice può essere una formazione)
export function riflessi(sc: Scheda): Nodo[] {
  const nodi = new Map(nodiUnici(sc.discendenti).map((d) => [d.id, d]));
  const rid = sc.lessema.id;
  const ok = new Map<number, boolean>();
  const valido = (id: number): boolean => {
    if (id === rid) return true;
    if (ok.has(id)) return ok.get(id)!;
    const d = nodi.get(id);
    if (!d) return false;
    // dalla radice il primo passo può essere una formazione (*ped- > *pṓds), non un legame indeterminato
    const v = valido(d.etimo) && (d.etimo === rid ? CATEGORIA[d.tipo] !== 'indeterminata' : EREDITARIO.has(d.tipo));
    ok.set(id, v);
    return v;
  };
  // una forma per lingua, la più vicina alla radice: «la stessa parola in N lingue»
  const perLinguaMin = new Map<string, (typeof sc.discendenti)[number]>();
  for (const d of nodi.values()) {
    if (d.ricostruito || !valido(d.id)) continue;
    const prima = perLinguaMin.get(d.lingua);
    if (!prima || d.profondita < prima.profondita || (d.profondita === prima.profondita && d.lemma.localeCompare(prima.lemma) < 0)) perLinguaMin.set(d.lingua, d);
  }
  return [...perLinguaMin.values()].sort(perLingua).slice(0, 14);
}

export function contaRami(nodi: Pick<Nodo, 'ramo'>[]): Record<string, number> {
  const c: Record<string, number> = {};
  for (const n of nodi) { const r = ramoDi(n.ramo); c[r] = (c[r] ?? 0) + 1; }
  return c;
}

export function datazione(a: Pick<Attestazione, 'anno_da' | 'anno_a' | 'precisione'>, t: Testi) {
  const anno = (y: number) => (y < 0 ? `${-y} ${t.aC}` : String(y));
  const d = a.anno_da, f = a.anno_a, p = a.precisione;
  if (p === 'secolo') return t.secolo(Math.ceil(Math.abs(d) / 100)) + (d < 0 ? ' ' + t.aC : '');
  if (p === 'circa') return `${t.circa} ${anno(d)}`;
  if (p === 'ante') return `${t.ante} ${anno(d)}`;
  if (p === 'post') return `${t.post} ${anno(d)}`;
  if (f != null && f !== d) return d < 0 && f > 0 ? `${anno(d)}–${f} ${t.dC}` : `${anno(d)}–${anno(f)}`;
  return anno(d);
}
