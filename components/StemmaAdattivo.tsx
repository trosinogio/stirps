'use client';
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeArco, classeRamo, fmt, G } from '@/lib/forme';
import { costruisciAlbero, type NodoAlbero } from '@/lib/albero';
import type { NodoPiatto } from '@/lib/tipi';

// Su schermo stretto mostra lo stemma verticale (generato sul server, passato come children);
// su schermo largo lo sostituisce con lo stemma orizzontale disegnato qui.
export default function StemmaAdattivo({ lang, nodi, children }: { lang: Lang; nodi: NodoPiatto[]; children: ReactNode }) {
  const [largo, setLargo] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 760px)');
    const f = () => setLargo(mq.matches);
    f();
    mq.addEventListener('change', f);
    return () => mq.removeEventListener('change', f);
  }, []);
  return largo ? <StemmaOrizzontale lang={lang} nodi={nodi} /> : <>{children}</>;
}

interface Posato extends NodoAlbero { x: number; y: number; w: number }

function StemmaOrizzontale({ lang, nodi }: { lang: Lang; nodi: NodoPiatto[] }) {
  const t = TESTI[lang];
  const router = useRouter();
  const wrap = useRef<HTMLDivElement>(null);
  const [larg, setLarg] = useState(0);
  const [font, setFont] = useState<{ serif: string; sans: string } | null>(null);
  const [sel, setSel] = useState<number | null>(null);

  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setLarg(el.clientWidth));
    ro.observe(el);
    setLarg(el.clientWidth);
    return () => ro.disconnect();
  }, []);
  useEffect(() => {
    const leggi = () => {
      const cs = getComputedStyle(document.documentElement);
      setFont({ serif: cs.getPropertyValue('--font-serif').trim() || 'serif', sans: cs.getPropertyValue('--font-sans').trim() || 'sans-serif' });
    };
    if (document.fonts) document.fonts.ready.then(leggi); else leggi();
  }, []);

  const disegno = useMemo(() => {
    if (!larg || !font) return null;
    const tela = document.createElement('canvas').getContext('2d')!;
    const misura = (testo: string, f: string) => { tela.font = f; return tela.measureText(testo).width; };
    const fL = `400 15px ${font.serif}`, fS = `400 12px ${font.sans}`;
    const { radice, tutti } = costruisciAlbero(nodi);
    const posati = new Map<number, Posato>();
    let maxFoglia = 0, prof = 0, foglie = 0;
    const maxPerLivello: number[] = [];
    const giro = (n: NodoAlbero, d: number): Posato => {
      const p = n as Posato;
      p.x = d; prof = Math.max(prof, d);
      p.w = misura(fmt(n), fL) + 5 + misura(n.lingua_sigla, fS);
      if (n.figli.length) {
        maxPerLivello[d] = Math.max(maxPerLivello[d] ?? 0, p.w);
        const f = n.figli.map((c) => giro(c, d + 1));
        p.y = f[0].y;   // radice in testa: ogni nodo sta all'altezza del suo primo figlio
      } else { maxFoglia = Math.max(maxFoglia, p.w); p.y = foglie++; }
      posati.set(n.id, p);
      return p;
    };
    giro(radice, 0);
    const rigaH = 34, mx = 14, my = 32;
    // ogni colonna è larga quanto l'etichetta più lunga della sua generazione (più lo spazio per il gomito)
    const minimi = Array.from({ length: prof }, (_, d) => Math.max(70, (maxPerLivello[d] ?? 0) + 26));
    const totaleMin = minimi.reduce((a, b) => a + b, 0);
    const extra = prof ? Math.max(0, Math.min(26 * prof, larg - 2 - 2 * mx - maxFoglia - 10 - totaleMin)) / prof : 0;
    const colonne = minimi.map((m) => Math.min(250, m + extra));
    const inizio = [0];
    for (const c of colonne) inizio.push(inizio[inizio.length - 1] + c);
    const W = Math.ceil(mx * 2 + inizio[prof] + maxFoglia + 10), H = Math.ceil(my + Math.max(0, foglie - 1) * rigaH + 24);
    const X = (n: Posato) => mx + inizio[n.x], Y = (n: Posato) => my + n.y * rigaH;
    return { radice, tutti, posati, W, H, X, Y };
  }, [larg, font, nodi]);

  const cammino = useMemo(() => {
    const s = new Set<number>();
    if (sel == null || !disegno) return s;
    for (let n: NodoAlbero | null | undefined = disegno.tutti.get(sel); n; n = n.padreNodo) s.add(n.id);
    return s;
  }, [sel, disegno]);

  const scelto = sel != null && disegno ? disegno.tutti.get(sel) : null;
  const percorso: NodoAlbero[] = [];
  for (let n = scelto ?? null; n; n = n.padreNodo) percorso.unshift(n);

  return (
    <>
      <div className="stemma-wrap" ref={wrap}>
        {disegno && (
          <svg className={`stemma cresce${sel != null ? ' selezione' : ''}`} width={disegno.W} height={disegno.H}
            viewBox={`0 0 ${disegno.W} ${disegno.H}`} role="group" aria-label={t.stemmaDi(fmt(disegno.radice))}>
            <g>
              {[...disegno.posati.values()].filter((n) => n.padreNodo).map((n) => {
                const p = disegno.posati.get(n.padreNodo!.id)!, xm = disegno.X(n) - 14;
                return <path key={'a' + n.id} className={`st-arco ${classeArco(n.tipo)}${cammino.has(n.id) ? ' evid' : ''}`}
                  d={`M${disegno.X(p) + 4},${disegno.Y(p)}H${xm}V${disegno.Y(n)}H${disegno.X(n) - 4}`} />;
              })}
            </g>
            <g>
              {[...disegno.posati.values()].map((n) => (
                <g key={'n' + n.id} className={`st-nodo ${classeRamo(n.ramo)}${n.ricostruito ? ' ric' : ''}${cammino.has(n.id) ? ' evid' : ''}`}
                  tabIndex={0} role="link" aria-label={`${fmt(n)}, ${n.lingua_nome}${n.glossa ? ': ' + n.glossa : ''}`}
                  onMouseEnter={() => setSel(n.id)} onMouseLeave={() => setSel(null)}
                  onFocus={() => setSel(n.id)} onBlur={() => setSel(null)}
                  onClick={() => router.push(`/${lang}/w/${n.slug}`)}
                  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); router.push(`/${lang}/w/${n.slug}`); } }}>
                  <rect className="st-hit" x={disegno.X(n) - 7} y={disegno.Y(n) - 23} width={n.w + 18} height={30} rx={4} />
                  <circle cx={disegno.X(n)} cy={disegno.Y(n)} r={n.padreNodo ? 3.6 : 5.4} />
                  <text x={disegno.X(n) + 8} y={disegno.Y(n) - 7}>
                    <tspan className="st-lemma">{fmt(n)}</tspan>
                    <tspan className="st-sigla" dx={5}>{n.lingua_sigla}</tspan>
                  </text>
                </g>
              ))}
            </g>
          </svg>
        )}
      </div>
      <div className="anteprima" aria-live="polite">
        {scelto ? (
          <>
            <span className="lemma">{fmt(scelto)}</span>{' '}
            <span className={`sigla ${classeRamo(scelto.ramo)}`}>{scelto.lingua_nome}</span>
            {scelto.glossa && <span className="gl"> {G(scelto.glossa, lang)}</span>}
            <br />
            <span className="percorso">
              {percorso.map((c, i) => (
                <span key={c.id}>
                  {i > 0 && <span className="gt"> &gt; </span>}
                  {fmt(c)}
                  {i > 0 && c.tipo_etichetta && <span className="tp"> {c.tipo_etichetta}</span>}
                </span>
              ))}
            </span>
          </>
        ) : t.stemmaSuggerimento}
      </div>
    </>
  );
}
