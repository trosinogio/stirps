// La linea del tempo di una voce: ogni nodo della catena su un asse di anni.
// Fascia = periodo (convenzionale) della lingua, tratteggiata se ricostruita; punto = prima attestazione datata;
// curve = passaggi, dallo stato dell'etimo più vicino alla nascita della parola nuova.
// La scala è logaritmica sugli anni prima di oggi: le date si addensano negli ultimi secoli.
import type { Lang, Testi } from '@/lib/i18n';
import { classeRamo, datazione } from '@/lib/forme';
import type { Attestazione } from '@/lib/tipi';
import ScorriTempo from './ScorriTempo';

export interface NodoTempo {
  id: number; slug: string; etichetta: string; sigla: string; lingua_nome: string; ramo: string | null;
  ricostruita: boolean; periodo: { da: number; a: number | null } | null;
  attestata: { anno_da: number; anno_a: number | null; precisione: string } | null;
  principale?: boolean;
  generazione: number;   // distanza massima dalla parola della voce: l'etimo sta sempre sopra i discendenti
}
export interface ArcoTempo { da: number; a: number; tipo: string; etichetta?: string | null }

const W = 760, SX = 10, DX = 18, SU = 6, RIGA = 44, ASSE = 36;
// prima gli anni tondi, poi gli altri dove c'è spazio
const PRIMARI = [1900, 1800, 1500, 1000, 500, 1, -1000, -2000, -3000, -4000];
const SECONDARI = [2000, 1700, 1600, 1400, 1300, 1200, 1100, 750, 250, -500, -1500, -5000];

function stileArco(tipo: string) {
  if (['eredita', 'trasmissione', 'variante'].includes(tipo)) return 'lt-eredita';
  if (tipo === 'prestito_dotto') return 'lt-dotto';
  if (['prestito', 'semidotto', 'calco', 'calco_semantico'].includes(tipo)) return 'lt-prestito';
  if (['generico', 'influsso', 'paretimologia'].includes(tipo)) return 'lt-incerto';
  return 'lt-formazione';
}

export default function LineaTempo({ lang, nodi, archi, t }: { lang: Lang; nodi: NodoTempo[]; archi: ArcoTempo[]; t: Testi }) {
  const oggi = new Date().getFullYear();
  // collocazione: la prima attestazione; senza data, il punto più antico possibile,
  // cioè l'inizio del periodo della lingua ma non prima dei suoi etimi (si procede dalle generazioni più antiche)
  const etimiDi = new Map<number, number[]>();
  for (const a of archi) etimiDi.set(a.a, [...(etimiDi.get(a.a) ?? []), a.da]);
  const posto = new Map<number, number>();
  for (const n of [...nodi].sort((a, b) => b.generazione - a.generazione)) {
    if (n.attestata) { posto.set(n.id, n.attestata.anno_da); continue; }
    if (!n.periodo) continue;
    const dopo = Math.max(n.periodo.da, ...(etimiDi.get(n.id) ?? []).map((e) => posto.get(e) ?? -Infinity));
    posto.set(n.id, Math.min(dopo, n.periodo.a ?? oggi));
  }
  const ancora = (n: NodoTempo) => posto.get(n.id) ?? null;
  const collocati = nodi.filter((n) => ancora(n) !== null)
    .sort((a, b) => (a.principale ? 1 : 0) - (b.principale ? 1 : 0) || b.generazione - a.generazione || ancora(a)! - ancora(b)!);
  const fuori = nodi.filter((n) => ancora(n) === null);
  if (collocati.length < 2) return null;

  // finestra: dal punto più antico (con un margine) a oggi
  const piuAntico = Math.min(...collocati.flatMap((n) => [ancora(n)!, n.periodo?.da ?? Infinity]));
  const inizio = Math.floor(piuAntico - 0.05 * (oggi - piuAntico) - 10);
  const T0 = oggi + 300;
  const f = (y: number) => Math.log(T0 - y);
  const x = (y: number) => SX + (W - SX - DX) * (f(inizio) - f(Math.min(y, oggi))) / (f(inizio) - f(oggi));

  const riga = new Map(collocati.map((n, i) => [n.id, i]));
  const yFascia = (i: number) => SU + i * RIGA + 30;
  const H = SU + collocati.length * RIGA + ASSE;
  const yAsse = SU + collocati.length * RIGA + 6;

  // tacche: dalle più recenti, distanziate almeno 54 px
  const tacche: number[] = [];
  for (const y of [...PRIMARI, ...SECONDARI]) {
    if (y < inizio || y > oggi - 15 || x(oggi) - x(y) < 40) continue;
    if (tacche.every((z) => Math.abs(x(z) - x(y)) >= 54)) tacche.push(y);
  }
  const anno = (y: number) => (y < 0 ? `${-y} ${t.aC}` : y === 1 ? `1 ${t.tempo.dC}` : String(y));

  // passaggi senza doppioni (la catena può raggiungere un nodo per più vie)
  const visti = new Set<string>();
  const curve = archi.filter((a) => {
    const k = `${a.da}-${a.a}-${a.tipo}`;
    if (visti.has(k) || !riga.has(a.da) || !riga.has(a.a)) return false;
    visti.add(k); return true;
  });
  const perId = new Map(collocati.map((n) => [n.id, n]));

  return (
    <figure className="linea-tempo">
      <p className="lt-indizio" aria-hidden="true">{t.tempo.scorri}</p>
      <ScorriTempo frazione={x(ancora(collocati[collocati.length - 1])!) / W}>
        <svg viewBox={`0 0 ${W} ${H}`} width="100%" className="lt-svg" aria-labelledby="lt-titolo">
          <title id="lt-titolo">{t.tempo.aria(collocati.map((n) => n.etichetta).join(', '))}</title>
          <defs>
            <marker id="lt-freccia" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M0,0 L8,4 L0,8 z" className="lt-punta" />
            </marker>
          </defs>
          {tacche.map((y) => <line key={y} className="lt-griglia" x1={x(y)} x2={x(y)} y1={SU} y2={yAsse} />)}
          <line className="lt-griglia lt-oggi" x1={x(oggi)} x2={x(oggi)} y1={SU} y2={yAsse} />

          {curve.map((a) => {
            const s = perId.get(a.da)!, d = perId.get(a.a)!;
            const arrivo = ancora(d)!;
            const partenza = Math.max(ancora(s)!, s.periodo ? Math.min(Math.max(arrivo, s.periodo.da), s.periodo.a ?? oggi) : ancora(s)!);
            const sx = x(partenza), sy = yFascia(riga.get(s.id)!) + 6;
            const tx = x(arrivo), ty = yFascia(riga.get(d.id)!) - 7;
            const m = (sy + ty) / 2;
            return (
              <path key={`${a.da}-${a.a}-${a.tipo}`} className={`lt-arco ${stileArco(a.tipo)}`} markerEnd="url(#lt-freccia)"
                d={`M${sx.toFixed(1)},${sy} C${sx.toFixed(1)},${m} ${tx.toFixed(1)},${m} ${tx.toFixed(1)},${ty}`}>
                <title>{`${a.etichetta ?? a.tipo}: ${s.etichetta} → ${d.etichetta}`}</title>
              </path>
            );
          })}

          {collocati.map((n, i) => {
            const yb = yFascia(i);
            const p = n.periodo, att = n.attestata;
            const ax = x(ancora(n)!);
            const destra = ax > W - 230;
            const data = att ? datazione(att as Attestazione, t) : null;
            return (
              <g key={n.id} className={`lt-riga ${classeRamo(n.ramo)} ${n.principale ? 'lt-principale' : ''}`}>
                {p && (
                  <rect className={`lt-fascia ${n.ricostruita ? 'lt-ricostruita' : ''}`} x={x(p.da)} y={yb - 4}
                    width={Math.max(4, x(p.a ?? oggi) - x(p.da))} height={8} rx={4}>
                    <title>{`${n.lingua_nome}: ${anno(p.da)}–${p.a === null ? t.tempo.oggi : anno(p.a)}`}</title>
                  </rect>
                )}
                {att ? (att.anno_a !== null && att.anno_a > att.anno_da
                  ? <rect className="lt-punto" x={x(att.anno_da)} y={yb - 5} width={Math.max(10, x(att.anno_a) - x(att.anno_da))} height={10} rx={5} />
                  : <circle className="lt-punto" cx={x(att.anno_da)} cy={yb} r={5.5} />)
                  : <circle className="lt-presunto" cx={ax} cy={yb} r={4} />}
                <a href={`/${lang}/w/${n.slug}`}>
                  <text x={destra ? ax - 7 : ax + 7} y={yb - 12} textAnchor={destra ? 'end' : 'start'} className="lt-testo">
                    <tspan className="lt-lemma">{n.etichetta}</tspan>
                    <tspan className="lt-sigla" dx={5}>{n.sigla}</tspan>
                    {data && <tspan className="lt-data" dx={7}>{data}</tspan>}
                  </text>
                </a>
              </g>
            );
          })}

          <line className="lt-asse" x1={SX} x2={W - DX} y1={yAsse} y2={yAsse} />
          {tacche.map((y) => (
            <text key={y} className="lt-anno" x={x(y)} y={yAsse + 17} textAnchor="middle">{anno(y)}</text>
          ))}
          <text className="lt-anno" x={x(oggi)} y={yAsse + 17} textAnchor="end">{t.tempo.oggi}</text>
        </svg>
      </ScorriTempo>
      <figcaption className="nota-sez">
        {t.tempo.legenda}
        {fuori.length > 0 && <> {t.tempo.senzaData} {fuori.map((n) => `${n.etichetta} (${n.lingua_nome})`).join(', ')}.</>}
      </figcaption>
    </figure>
  );
}
