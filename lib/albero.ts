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
      ramo: d.ramo, ricostruito: d.ricostruito, glossa: d.glossa ?? null, nome_proprio: d.nome_proprio ?? false,
      tipo: d.tipo, tipo_etichetta: d.tipo_etichetta ?? null, padre: d.etimo,
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

// Uno stemma leggibile: oltre SOGLIA_FIGLI figli, se ne mostrano FIGLI_MOSTRATI (quelli con i rami più grandi) e gli
// altri vanno in una lista a tendina (-logia ha quasi duecento figli).
// oltre queste parole lo stemma non si disegna: l'elenco annidato mostra i primi due livelli, e ogni ramo ha la sua pagina
export const LIMITE_DISEGNO = 150;
export const SOGLIA_FIGLI = 12;
export const FIGLI_MOSTRATI = 6;

/** Quanti discendenti ha ogni nodo, sé escluso. */
export function dimensioni(radice: NodoAlbero): Map<number, number> {
  const dim = new Map<number, number>();
  const giro = (n: NodoAlbero): number => {
    let k = 0;
    for (const c of n.figli) k += 1 + giro(c);
    dim.set(n.id, k);
    return k;
  };
  giro(radice);
  return dim;
}

/** I nomi propri da cui non deriva nessuna parola comune (Φίλιππος sotto ἵππος): lo stemma li nasconde, se il lettore
 *  non chiede di vederli. Un nome proprio con discendenti comuni resta (Caesar porta a Kaiser e zar). Sono i nodi più
 *  alti di ogni sottoalbero fatto solo di nomi propri; la radice non si nasconde mai. */
export function nomiNascondibili(radice: NodoAlbero): Set<number> {
  const soloNomi = new Map<number, boolean>();
  const giro = (n: NodoAlbero): boolean => {
    let r = !!n.nome_proprio;
    for (const c of n.figli) r = giro(c) && r;
    soloNomi.set(n.id, r);
    return r;
  };
  giro(radice);
  const via = new Set<number>();
  const scendi = (n: NodoAlbero) => { for (const c of n.figli) { if (soloNomi.get(c.id)) via.add(c.id); else scendi(c); } };
  scendi(radice);
  return via;
}

/** Quanti nodi spariscono nascondendo i nomi propri (i nascosti con i loro discendenti). */
export function contaNascosti(via: Set<number>, dim: Map<number, number>): number {
  let k = 0;
  for (const id of via) k += 1 + (dim.get(id) ?? 0);
  return k;
}

/** I figli da disegnare e quelli da raccogliere nella lista a tendina: oltre la soglia restano i FIGLI_MOSTRATI con i
 *  rami più grandi, nel loro ordine, scelti tra quelli che non sono da nascondere; gli altri vanno in ordine alfabetico. */
export function dividiFigli(figli: NodoAlbero[], dim: Map<number, number>, nascosto: (n: NodoAlbero) => boolean = () => false):
  { mostrati: NodoAlbero[]; raccolti: NodoAlbero[] } {
  if (figli.length <= SOGLIA_FIGLI) return { mostrati: figli, raccolti: [] };
  const primi = new Set(figli.filter((c) => !nascosto(c))
    .sort((a, b) => (dim.get(b.id) ?? 0) - (dim.get(a.id) ?? 0)).slice(0, FIGLI_MOSTRATI).map((c) => c.id));
  return {
    mostrati: figli.filter((c) => primi.has(c.id)),
    raccolti: figli.filter((c) => !primi.has(c.id)).sort((a, b) => a.lemma.localeCompare(b.lemma)),
  };
}
