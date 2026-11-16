'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeArco, classeRamo, fmt, ORDINE_LINGUE, ORDINE_RAMI, ramoDi } from '@/lib/forme';
import { TERRE } from '@/lib/terre';
import type { LinguaGeo } from '@/lib/tipi';

export interface NodoMappa { id: number; slug: string; lemma: string; lingua: string; lingua_sigla: string; ramo: string | null; ricostruito: boolean }
export interface ArcoMappa { da: number; a: number; tipo: string }

const peso = (t: string) => (t === 'eredita' || t === 'variante' ? 4 : classeArco(t) === 'e-dotto' ? 3 : classeArco(t) === 'e-indeterminata' ? 0 : classeArco(t) === 'e-formazione' ? 1 : 2);
function tratteggio(t: string, k: number) {
  const c = classeArco(t);
  if (c === 'e-prestito') return `${5 * k} ${4 * k}`;
  if (c === 'e-dotto') return `${1.4 * k} ${3.6 * k}`;
  if (c === 'e-formazione') return `${9 * k} ${3 * k} ${2 * k} ${3 * k}`;
  if (c === 'e-indeterminata') return `${1 * k} ${3 * k}`;
  return undefined;
}
const ordine = (c: string) => (ORDINE_LINGUE.indexOf(c) + 1000) % 1000;

interface LinguaPunto { c: string; sigla: string; ramo: string | null; parole: NodoMappa[] }
interface Punto { k: string; xy: [number, number]; lingue: LinguaPunto[]; n: number }

// Un punto per luogo: le fasi storiche e le varietà di una lingua che hanno lo stesso luogo (inglese antico, medio e
// moderno; latino tardo e medievale) stanno in un punto solo, con il nome della lingua che ha più parole e «+n». Le
// etichette vanno prima ai punti con più parole; quella che non trova posto non si sposta lontano con una linea guida: il
// punto resta senza nome, e il nome compare passandoci sopra. Le frecce sono tenui; passando su un punto (o su una
// riga dell'elenco) si accendono le sue e quelle dei suoi vicini.
export default function Mappa({ lang, nodi, archi, lingue }: { lang: Lang; nodi: NodoMappa[]; archi: ArcoMappa[]; lingue: LinguaGeo[] }) {
  const t = TESTI[lang];
  const wrap = useRef<HTMLDivElement>(null);
  const [px, setPx] = useState(0);
  const [sansFam, setSansFam] = useState('sans-serif');
  const [attivo, setAttivo] = useState<string | null>(null);
  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setPx(el.clientWidth));
    ro.observe(el);
    setPx(el.clientWidth);
    setSansFam(getComputedStyle(document.documentElement).getPropertyValue('--font-sans').trim() || 'sans-serif');
    return () => ro.disconnect();
  }, []);

  const perCodice = new Map(lingue.map((l) => [l.codice, l]));
  const coord = (c: string): [number, number] | null => {
    let l = perCodice.get(c);
    if (l && l.lat == null && l.varieta_di) l = perCodice.get(l.varieta_di);
    return l && l.lat != null && l.lon != null ? [360 + 2 * l.lon, 180 - 2 * l.lat] : null;
  };
  const perId = new Map(nodi.map((n) => [n.id, n]));
  const punti = new Map<string, Punto>();
  const puntoDi = new Map<string, string>();          // lingua → punto
  let senza = 0;
  for (const n of nodi) {
    const xy = coord(n.lingua);
    if (!xy) { senza++; continue; }
    const k = `${xy[0].toFixed(1)},${xy[1].toFixed(1)}`;
    if (!punti.has(k)) punti.set(k, { k, xy, lingue: [], n: 0 });
    const p = punti.get(k)!;
    let l = p.lingue.find((x) => x.c === n.lingua);
    if (!l) { l = { c: n.lingua, sigla: n.lingua_sigla, ramo: n.ramo, parole: [] }; p.lingue.push(l); puntoDi.set(n.lingua, k); }
    if (!l.parole.some((x) => x.id === n.id)) { l.parole.push(n); p.n++; }
  }
  if (punti.size < 2) return <p className="vuoto">{t.mappaPochi}</p>;
  for (const p of punti.values()) p.lingue.sort((a, b) => b.parole.length - a.parole.length || ordine(a.c) - ordine(b.c));

  // una freccia per coppia di luoghi, con il passaggio più forte; niente frecce dentro un luogo
  const coppie = new Map<string, { da: string; a: string; tipo: string }>();
  for (const e of archi) {
    const a = perId.get(e.da), b = perId.get(e.a);
    const pa = a && puntoDi.get(a.lingua), pb = b && puntoDi.get(b.lingua);
    if (!pa || !pb || pa === pb) continue;
    const k = pa + '>' + pb, prima = coppie.get(k);
    if (!prima || peso(e.tipo) > peso(prima.tipo)) coppie.set(k, { da: pa, a: pb, tipo: e.tipo });
  }
  const vicini = new Map<string, Set<string>>();
  for (const e of coppie.values()) {
    if (!vicini.has(e.da)) vicini.set(e.da, new Set());
    if (!vicini.has(e.a)) vicini.set(e.a, new Set());
    vicini.get(e.da)!.add(e.a);
    vicini.get(e.a)!.add(e.da);
  }

  const pt = [...punti.values()];
  const xs = pt.map((p) => p.xy[0]), ys = pt.map((p) => p.xy[1]);
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2, cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  let w = Math.max(Math.max(...xs) - Math.min(...xs), 36) * 1.45 + 34, hh = Math.max(Math.max(...ys) - Math.min(...ys), 22) * 1.5 + 24;
  if (hh < w * 0.52) hh = w * 0.52;
  if (w < hh * 1.2) w = hh * 1.2;
  const x0 = cx - w / 2, y0 = cy - hh / 2;
  const k = w / (px || 640), fs = 13 * k;

  // etichette: il nome della lingua principale del punto (e «+n»), prima ai punti con più parole
  const tela = typeof document !== 'undefined' ? document.createElement('canvas').getContext('2d') : null;
  const misura = (s: string) => { if (!tela) return s.length * 7; tela.font = `700 13px ${sansFam}`; return tela.measureText(s).width; };
  const urta = (a: number[], b: number[]) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
  const dentro = (b: number[]) => b[0] >= x0 + 2 * k && b[0] + b[2] <= x0 + w - 2 * k && b[1] >= y0 + 2 * k && b[1] + b[3] <= y0 + hh - 2 * k;
  const testo = (p: Punto) => p.lingue[0].sigla + (p.lingue.length > 1 ? ` +${p.lingue.length - 1}` : '');
  const ostacoli = pt.map((p) => [p.xy[0] - 5 * k, p.xy[1] - 5 * k, 10 * k, 10 * k]);
  const etichette = new Map<string, { x: number; y: number; ancora: 'start' | 'end'; visibile: boolean }>();
  for (const p of pt.slice().sort((a, b) => b.n - a.n || ordine(a.lingue[0].c) - ordine(b.lingue[0].c))) {
    const [x, y] = p.xy, wl = (misura(testo(p)) + 2) * k, alto = fs * 1.2;
    const cand: [number, number, 'start' | 'end'][] = [[x + 8 * k, y + fs * 0.35, 'start'], [x - 8 * k, y + fs * 0.35, 'end'], [x + 5 * k, y - 7 * k, 'start'],
      [x + 5 * k, y + 7 * k + fs, 'start'], [x - 5 * k, y - 7 * k, 'end'], [x - 5 * k, y + 7 * k + fs, 'end']];
    const scatola = ([ax, ay, an]: [number, number, 'start' | 'end']) => [an === 'end' ? ax - wl : ax, ay - fs * 0.9, wl, alto];
    const scelta = cand.find((c) => dentro(scatola(c)) && !ostacoli.some((o) => urta(o, scatola(c))));
    if (scelta) ostacoli.push(scatola(scelta));
    const [ex, ey, an] = scelta ?? cand[0];
    etichette.set(p.k, { x: ex, y: ey, ancora: an, visibile: !!scelta });
  }

  const acceso = (k2: string) => !attivo || k2 === attivo || !!vicini.get(attivo)?.has(k2);
  const nomeLingua = (c: string) => perCodice.get(c)?.nome ?? c;
  const elenco = pt.flatMap((p) => p.lingue.map((l) => ({ ...l, k: p.k })))
    .sort((a, b) => ORDINE_RAMI.indexOf(ramoDi(a.ramo)) - ORDINE_RAMI.indexOf(ramoDi(b.ramo)) || ordine(a.c) - ordine(b.c));

  return (
    <>
      <div className="mappa-wrap" ref={wrap} onMouseLeave={() => setAttivo(null)}>
        {px > 0 && (
          <svg className={`mappa${attivo ? ' con-attivo' : ''}`} viewBox={`${x0.toFixed(2)} ${y0.toFixed(2)} ${w.toFixed(2)} ${hh.toFixed(2)}`} role="img"
            aria-label={`${t.mappaAria}: ${pt.map((p) => p.lingue.map((l) => nomeLingua(l.c)).join(', ')).join('; ')}`}>
            <defs>
              <marker id="freccia" viewBox="0 0 10 10" refX={8.5} refY={5} markerWidth={7} markerHeight={7} orient="auto-start-reverse" style={{ color: 'var(--ink-2)' }}>
                <path d="M1.5 1.5L8.5 5L1.5 8.5" fill="none" stroke="currentColor" strokeWidth={1.4} strokeLinecap="round" strokeLinejoin="round" />
              </marker>
            </defs>
            <path className="terra" d={TERRE} />
            {[...coppie.values()].map((e) => {
              const [ax, ay] = punti.get(e.da)!.xy, [bx, by] = punti.get(e.a)!.xy;
              const dx = bx - ax, dy = by - ay, len = Math.hypot(dx, dy) || 1, acc = (6 * k) / len;
              const ex = bx - dx * acc, ey = by - dy * acc, qx = (ax + bx) / 2 - dy * 0.2, qy = (ay + by) / 2 + dx * 0.2;
              const stato = !attivo ? '' : e.da === attivo || e.a === attivo ? ' acceso' : ' spento';
              return <path key={e.da + '>' + e.a} className={`m-arco ${classeArco(e.tipo)}${stato}`} d={`M${ax},${ay}Q${qx},${qy} ${ex},${ey}`}
                strokeWidth={(stato === ' acceso' ? 1.8 : 1.2) * k} strokeDasharray={tratteggio(e.tipo, k)} markerEnd="url(#freccia)" />;
            })}
            {pt.map((p) => {
              const et = etichette.get(p.k)!, on = acceso(p.k);
              return (
                <g key={p.k} className={`m-luogo ${classeRamo(p.lingue[0].ramo)}${on ? '' : ' spento'}`} tabIndex={0}
                  onMouseEnter={() => setAttivo(p.k)} onFocus={() => setAttivo(p.k)} onBlur={() => setAttivo(null)}
                  onClick={() => setAttivo(attivo === p.k ? null : p.k)}>
                  <title>{p.lingue.map((l) => `${nomeLingua(l.c)}: ${l.parole.map((n) => fmt(n)).join(', ')}`).join('\n')}</title>
                  <circle className="m-punto" cx={p.xy[0]} cy={p.xy[1]} r={(p.lingue.length > 1 ? 5 : 4.2) * k} strokeWidth={1.6 * k} />
                  <circle cx={p.xy[0]} cy={p.xy[1]} r={9 * k} fill="transparent" />
                  {(et.visibile || (attivo && on)) && (
                    <text className="m-lab m-sig" x={et.x} y={et.y} fontSize={fs} strokeWidth={3 * k} textAnchor={et.ancora}>{testo(p)}</text>
                  )}
                </g>
              );
            })}
          </svg>
        )}
      </div>
      <ul className="mappa-elenco">
        {elenco.map((l) => (
          <li key={l.c} className={`${classeRamo(l.ramo)}${attivo === l.k ? ' attivo' : ''}`} onMouseEnter={() => setAttivo(l.k)} onMouseLeave={() => setAttivo(null)}>
            <span className="m-dot" aria-hidden="true" />
            <span className="sigla" title={nomeLingua(l.c)}>{l.sigla}</span>
            <span>
              {l.parole.slice().sort((a, b) => a.lemma.localeCompare(b.lemma)).map((n, i) => (
                <span key={n.id}>{i > 0 && ', '}<Link className={`voce ${classeRamo(n.ramo)}`} href={`/${lang}/w/${n.slug}`} prefetch={false}><span className="lemma">{fmt(n)}</span></Link></span>
              ))}
            </span>
          </li>
        ))}
      </ul>
      <p className="nota-mappa">{t.mappaNota}{senza ? t.mappaProto : ''}</p>
    </>
  );
}
