// Lo stemma di una famiglia: albero di copertura dei discendenti, ordinato per ramo e lingua.
import { perLingua } from './forme';
import type { NodoPiatto, Scheda } from './tipi';

export interface NodoAlbero extends NodoPiatto { figli: NodoAlbero[]; padreNodo: NodoAlbero | null }

export function nodiFamiglia(sc: Scheda): NodoPiatto[] {
  const L = sc.lessema;
  const visti = new Set<number>([L.id]);
  const out: NodoPiatto[] = [{
    id: L.id, slug: L.slug, lemma: L.lemma, lingua: L.lingua, lingua_sigla: L.lingua_sigla, lingua_nome: L.lingua_nome,
    ramo: L.ramo, ricostruito: L.ricostruito, glossa: L.glossa ?? null, tipo: null, tipo_etichetta: null, padre: null,
  }];
  for (const d of sc.discendenti ?? []) {
    if (visti.has(d.id)) continue;
    visti.add(d.id);
    out.push({
      id: d.id, slug: d.slug, lemma: d.lemma, lingua: d.lingua, lingua_sigla: d.lingua_sigla, lingua_nome: d.lingua_nome,
      ramo: d.ramo, ricostruito: d.ricostruito, glossa: d.glossa ?? null, tipo: d.tipo, tipo_etichetta: d.tipo_etichetta ?? null, padre: d.etimo,
    });
  }
  return out;
}

export function costruisciAlbero(nodi: NodoPiatto[]): { radice: NodoAlbero; tutti: Map<number, NodoAlbero> } {
  const tutti = new Map<number, NodoAlbero>(nodi.map((n) => [n.id, { ...n, figli: [], padreNodo: null }]));
  const radice = tutti.get(nodi[0].id)!;
  for (const n of tutti.values()) {
    if (n.padre == null) continue;
    const p = tutti.get(n.padre);
    if (p) { n.padreNodo = p; p.figli.push(n); }
  }
  const ordina = (n: NodoAlbero) => { n.figli.sort(perLingua); n.figli.forEach(ordina); };
  ordina(radice);
  return { radice, tutti };
}
