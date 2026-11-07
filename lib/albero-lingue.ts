import type { LinguaIndice } from './tipi';

// L'albero genealogico delle lingue del dizionario: famiglia › ramo › discendenza (protoitalico › latino › italiano), con
// le varietà accanto alla loro lingua (latino volgare, latino medievale). Si costruisce dai dati di indice(): famiglia e
// ramo, antenato e varietà, che importa_lingue_wiktionary() completa dai dati di Wiktionary.
export type NodoLingua = { l: LinguaIndice; figli: NodoLingua[]; varieta: LinguaIndice[]; parole: number };
export type RamoAlbero = { ramo: string; nome: string; radici: NodoLingua[]; lingue: number; parole: number };
export type FamigliaAlbero = {
  famiglia: string; nome: string; capo: NodoLingua[]; rami: RamoAlbero[]; lingue: number; parole: number;
};

const SENZA_RAMO = 'proto';          // indice() dà «proto» alle lingue senza ramo (le protolingue, le famiglie senza rami)

const somma = (ns: NodoLingua[]): number => ns.reduce((s, n) => s + n.parole + somma(n.figli), 0);
const conta = (ns: NodoLingua[]): number => ns.reduce((s, n) => s + 1 + n.varieta.length + conta(n.figli), 0);
const ordina = (ns: NodoLingua[]) => {
  ns.sort((a, b) => somma([b]) - somma([a]) || a.l.nome.localeCompare(b.l.nome));
  ns.forEach((n) => ordina(n.figli));
  return ns;
};

export function alberoLingue(tutteLeLingue: LinguaIndice[]): FamigliaAlbero[] {
  const lingue = tutteLeLingue.filter((l) => !l.codice.startsWith('+'));   // «+univ»: un modello letto come lingua
  const per = new Map(lingue.map((l) => [l.codice, l]));
  // le varietà vanno accanto alla loro lingua, se c'è: non sono un ramo dell'albero
  const varieta = new Map<string, LinguaIndice[]>();
  const piene = lingue.filter((l) => {
    if (l.varieta_di && l.varieta_di !== l.codice && per.has(l.varieta_di)) {
      varieta.set(l.varieta_di, [...(varieta.get(l.varieta_di) ?? []), l]);
      return false;
    }
    return true;
  });
  const nodi = new Map<string, NodoLingua>(piene.map((l) => {
    const vs = (varieta.get(l.codice) ?? []).sort((a, b) => b.n - a.n);
    return [l.codice, { l, figli: [], varieta: vs, parole: l.n + vs.reduce((s, v) => s + v.n, 0) }];
  }));
  // il genitore è il primo antenato che è una lingua del dizionario, nella stessa famiglia e nello stesso ramo: il
  // protoitalico non sta sotto il protoindoeuropeo ma in testa al ramo italico
  const genitore = (l: LinguaIndice): NodoLingua | null => {
    const visti = new Set([l.codice]);
    let a = l.antenato;
    while (a && !visti.has(a)) {
      visti.add(a);
      const x = nodi.get(a);
      if (x) return x.l.famiglia === l.famiglia && x.l.ramo === l.ramo ? x : null;
      a = per.get(a)?.antenato ?? null;
    }
    return null;
  };
  const radici: NodoLingua[] = [];
  for (const n of nodi.values()) {
    const g = genitore(n.l);
    if (g) g.figli.push(n); else radici.push(n);
  }
  const famiglie = new Map<string, FamigliaAlbero>();
  for (const n of radici) {
    const f = n.l.famiglia ?? '';
    if (!famiglie.has(f)) famiglie.set(f, { famiglia: f, nome: n.l.famiglia_nome ?? f, capo: [], rami: [], lingue: 0, parole: 0 });
    const fam = famiglie.get(f)!;
    if (n.l.ramo === SENZA_RAMO) { fam.capo.push(n); continue; }
    let r = fam.rami.find((x) => x.ramo === n.l.ramo);
    if (!r) fam.rami.push(r = { ramo: n.l.ramo, nome: n.l.ramo_nome ?? n.l.ramo, radici: [], lingue: 0, parole: 0 });
    r.radici.push(n);
  }
  for (const fam of famiglie.values()) {
    ordina(fam.capo);
    for (const r of fam.rami) { ordina(r.radici); r.lingue = conta(r.radici); r.parole = somma(r.radici); }
    fam.rami.sort((a, b) => b.parole - a.parole);
    fam.lingue = conta(fam.capo) + fam.rami.reduce((s, r) => s + r.lingue, 0);
    fam.parole = somma(fam.capo) + fam.rami.reduce((s, r) => s + r.parole, 0);
  }
  // l'indoeuropea per prima, poi per numero di parole; senza famiglia e translingue in fondo
  const peso = (f: FamigliaAlbero) => (f.famiglia === 'indoeuropea' ? -1e12 : 0) + (!f.famiglia || f.famiglia === 'translingue' ? 1e12 : 0) - f.parole;
  return [...famiglie.values()].sort((a, b) => peso(a) - peso(b));
}

// i nodi di un elenco, appiattiti, per i riepiloghi (le lingue più ricche di un ramo)
export function tutte(ns: NodoLingua[]): LinguaIndice[] {
  return ns.flatMap((n) => [n.l, ...n.varieta, ...tutte(n.figli)]);
}
