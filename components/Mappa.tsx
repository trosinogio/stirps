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

export default function Mappa({ lang, nodi, archi, lingue }: { lang: Lang; nodi: NodoMappa[]; archi: ArcoMappa[]; lingue: LinguaGeo[] }) {
  const t = TESTI[lang];
  const wrap = useRef<HTMLDivElement>(null);
  const [px, setPx] = useState(0);
  const [sansFam, setSansFam] = useState('sans-serif');
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
  const punti = new Map<string, { c: string; xy: [number, number]; parole: NodoMappa[]; ramo: string | null; sigla: string }>();
  let senza = 0;
  for (const n of nodi) {
    const xy = coord(n.lingua);
    if (!xy) { senza++; continue; }
    if (!punti.has(n.lingua)) punti.set(n.lingua, { c: n.lingua, xy, parole: [], ramo: n.ramo, sigla: n.lingua_sigla });
    const p = punti.get(n.lingua)!;
    if (!p.parole.some((x) => x.id === n.id)) p.parole.push(n);
  }
  if (punti.size < 2) return <p className="vuoto">{t.mappaPochi}</p>;

  const coppie = new Map<string, { da: string; a: string; tipo: string }>();
  for (const e of archi) {
    const a = perId.get(e.da), b = perId.get(e.a);
    if (!a || !b || a.lingua === b.lingua || !punti.has(a.lingua) || !punti.has(b.lingua)) continue;
    const k = a.lingua + '>' + b.lingua, prima = coppie.get(k);
    if (!prima || peso(e.tipo) > peso(prima.tipo)) coppie.set(k, { da: a.lingua, a: b.lingua, tipo: e.tipo });
  }
  const pt = [...punti.values()];
  const xs = pt.map((p) => p.xy[0]), ys = pt.map((p) => p.xy[1]);
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2, cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  let w = Math.max(Math.max(...xs) - Math.min(...xs), 36) * 1.45 + 34, hh = Math.max(Math.max(...ys) - Math.min(...ys), 22) * 1.5 + 24;
  if (hh < w * 0.52) hh = w * 0.52;
  if (w < hh * 1.2) w = hh * 1.2;
  const x0 = cx - w / 2, y0 = cy - hh / 2;
  const k = w / (px || 640), fs = 13 * k;

  // etichette: solo la sigla, accanto al punto, provando più posizioni
  const tela = typeof document !== 'undefined' ? document.createElement('canvas').getContext('2d') : null;
  const misura = (s: string) => { if (!tela) return s.length * 7; tela.font = `700 13px ${sansFam}`; return tela.measureText(s).width; };
  const urta = (a: number[], b: number[]) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
  const dentro = (b: number[]) => b[0] >= x0 + 2 * k && b[0] + b[2] <= x0 + w - 2 * k && b[1] >= y0 + 2 * k && b[1] + b[3] <= y0 + hh - 2 * k;
  const ostacoli = pt.map((p) => [p.xy[0] - 5 * k, p.xy[1] - 5 * k, 10 * k, 10 * k]);
  const etichette = pt.map((p) => {
    const [x, y] = p.xy, wl = (misura(p.sigla) + 2) * k, alto = fs * 1.2;
    const cand: [number, number, 'start' | 'end'][] = [[x + 8 * k, y + fs * 0.35, 'start'], [x - 8 * k, y + fs * 0.35, 'end'], [x + 5 * k, y - 7 * k, 'start'],
      [x + 5 * k, y + 7 * k + fs, 'start'], [x - 5 * k, y - 7 * k, 'end'], [x - 5 * k, y + 7 * k + fs, 'end']];
    const scatola = ([ax, ay, an]: [number, number, 'start' | 'end']) => [an === 'end' ? ax - wl : ax, ay - fs * 0.9, wl, alto];
    let scelta = cand.find((c) => dentro(scatola(c)) && !ostacoli.some((o) => urta(o, scatola(c))));
    let guida = false;
    if (!scelta) {
      scelta = [x + 8 * k, y + fs * 0.35, 'start'];
      let n = 0;
      while (ostacoli.some((o) => urta(o, scatola(scelta!))) && n < 16) { scelta = [scelta[0], scelta[1] + alto, 'start']; n++; }
      guida = n > 0;
    }
    ostacoli.push(scatola(scelta));
    return { p, scelta, guida };
  });

  const elenco = pt.slice().sort((a, b) => ORDINE_RAMI.indexOf(ramoDi(a.ramo)) - ORDINE_RAMI.indexOf(ramoDi(b.ramo))
    || (ORDINE_LINGUE.indexOf(a.c) + 1000) % 1000 - (ORDINE_LINGUE.indexOf(b.c) + 1000) % 1000);

  return (
    <>
      <div className="mappa-wrap" ref={wrap}>
        {px > 0 && (
          <svg className="mappa" viewBox={`${x0.toFixed(2)} ${y0.toFixed(2)} ${w.toFixed(2)} ${hh.toFixed(2)}`} role="img"
            aria-label={`${t.mappaAria}: ${pt.map((p) => perCodice.get(p.c)?.nome ?? p.c).join(', ')}`}>
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
              return <path key={e.da + e.a} className="m-arco" d={`M${ax},${ay}Q${qx},${qy} ${ex},${ey}`}
                strokeWidth={1.3 * k} strokeDasharray={tratteggio(e.tipo, k)} markerEnd="url(#freccia)" />;
            })}
            {etichette.map(({ p, scelta, guida }) => (
              <g key={p.c} className={classeRamo(p.ramo)}>
                <circle className="m-punto" cx={p.xy[0]} cy={p.xy[1]} r={4.2 * k} strokeWidth={1.6 * k} />
                {guida && <line className="m-guida" x1={p.xy[0]} y1={p.xy[1]} x2={scelta[0] - 2 * k} y2={scelta[1] - fs * 0.35} strokeWidth={0.8 * k} />}
                <text className="m-lab m-sig" x={scelta[0]} y={scelta[1]} fontSize={fs} strokeWidth={3 * k} textAnchor={scelta[2]}>{p.sigla}</text>
              </g>
            ))}
          </svg>
        )}
      </div>
      <ul className="mappa-elenco">
        {elenco.map((p) => (
          <li key={p.c} className={classeRamo(p.ramo)}>
            <span className="m-dot" aria-hidden="true" />
            <span className="sigla">{p.sigla}</span>
            <span>
              {p.parole.slice().sort((a, b) => a.lemma.localeCompare(b.lemma)).map((n, i) => (
                <span key={n.id}>{i > 0 && ', '}<Link className={`voce ${classeRamo(n.ramo)}`} href={`/${lang}/w/${n.slug}`}><span className="lemma">{fmt(n)}</span></Link></span>
              ))}
            </span>
          </li>
        ))}
      </ul>
      <p className="nota-mappa">{t.mappaNota}{senza ? t.mappaProto : ''}</p>
    </>
  );
}
