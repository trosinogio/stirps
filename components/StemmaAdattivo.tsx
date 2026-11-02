'use client';
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeArco, classeRamo, fmt, G } from '@/lib/forme';
import { contaNascosti, costruisciAlbero, dimensioni, dividiFigli, nomiNascondibili, type NodoAlbero } from '@/lib/albero';
import type { NodoPiatto } from '@/lib/tipi';

const CHIAVE_NOMI = 'stirps.stemma.nomi';   // la scelta del lettore sui nomi propri, solo nel suo browser

// Su schermo stretto mostra lo stemma verticale (generato sul server, passato come children);
// su schermo largo lo sostituisce con lo stemma orizzontale disegnato qui. Sopra, gli strumenti dello stemma:
// i nomi propri sono nascosti finché il lettore non chiede di vederli.
export default function StemmaAdattivo({ lang, nodi, children }: { lang: Lang; nodi: NodoPiatto[]; children: ReactNode }) {
  const t = TESTI[lang];
  const [largo, setLargo] = useState(false);
  const [nomi, setNomi] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 760px)');
    const f = () => setLargo(mq.matches);
    f();
    mq.addEventListener('change', f);
    try { setNomi(localStorage.getItem(CHIAVE_NOMI) === '1'); } catch { /* memoria del browser non disponibile */ }
    return () => mq.removeEventListener('change', f);
  }, []);
  const nascosti = useMemo(() => {
    const { radice } = costruisciAlbero(nodi);
    return contaNascosti(nomiNascondibili(radice), dimensioni(radice));
  }, [nodi]);
  const cambia = () => {
    const v = !nomi;
    setNomi(v);
    try { localStorage.setItem(CHIAVE_NOMI, v ? '1' : '0'); } catch { /* idem */ }
  };
  return (
    <>
      {nascosti > 0 && (
        <div className="stemma-strumenti">
          <button type="button" className="btn-chip" aria-pressed={nomi} onClick={cambia}>
            {nomi ? t.nomiPropriNascondi : t.nomiPropriMostra(nascosti)}
          </button>
        </div>
      )}
      <div className="stemma-ctrl" data-nomi={nomi ? 'si' : 'no'}>
        {largo ? <StemmaOrizzontale lang={lang} nodi={nodi} nomi={nomi} /> : children}
      </div>
    </>
  );
}

// Un nodo disegnato: una parola, o il gruppo dei figli raccolti nella lista a tendina («+ 190 parole»)
interface Disegnato { id: number; n: NodoAlbero | null; padre: Disegnato | null; membri: NodoAlbero[]; figli: Disegnato[]; x: number; y: number; w: number }

function StemmaOrizzontale({ lang, nodi, nomi }: { lang: Lang; nodi: NodoPiatto[]; nomi: boolean }) {
  const t = TESTI[lang];
  const router = useRouter();
  const wrap = useRef<HTMLDivElement>(null);
  const gruppiRef = useRef(new Map<number, SVGGElement>());
  const [larg, setLarg] = useState(0);
  const [font, setFont] = useState<{ serif: string; sans: string } | null>(null);
  const [sel, setSel] = useState<number | null>(null);
  const [aperto, setAperto] = useState<number | null>(null);

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
  useEffect(() => { setAperto(null); }, [nomi]);

  const disegno = useMemo(() => {
    if (!larg || !font) return null;
    const tela = document.createElement('canvas').getContext('2d')!;
    const misura = (testo: string, f: string) => { tela.font = f; return tela.measureText(testo).width; };
    const fL = `400 15px ${font.serif}`, fS = `400 12px ${font.sans}`, fG = `600 13px ${font.sans}`;
    const { radice, tutti } = costruisciAlbero(nodi);
    const nascosti = nomi ? new Set<number>() : nomiNascondibili(radice);
    const dim = dimensioni(radice);
    // l'albero da disegnare: senza i nomi propri nascosti, con i figli minori raccolti in un gruppo
    const costruisci = (n: NodoAlbero, padre: Disegnato | null): Disegnato => {
      const d: Disegnato = { id: n.id, n, padre, membri: [], figli: [], x: 0, y: 0, w: 0 };
      const { mostrati, raccolti } = dividiFigli(n.figli.filter((c) => !nascosti.has(c.id)), dim);
      d.figli = mostrati.map((c) => costruisci(c, d));
      if (raccolti.length) d.figli.push({ id: -n.id, n: null, padre: d, membri: raccolti, figli: [], x: 0, y: 0, w: 0 });
      return d;
    };
    const cima = costruisci(radice, null);
    const posati: Disegnato[] = [];
    let maxFoglia = 0, prof = 0, foglie = 0;
    const maxPerLivello: number[] = [];
    const giro = (d: Disegnato, livello: number) => {
      d.x = livello; prof = Math.max(prof, livello);
      d.w = d.n ? misura(fmt(d.n), fL) + 5 + misura(d.n.lingua_sigla, fS) : misura(`${t.altreParole(d.membri.length)} ▾`, fG);
      if (d.figli.length) {
        maxPerLivello[livello] = Math.max(maxPerLivello[livello] ?? 0, d.w);
        d.figli.forEach((c) => giro(c, livello + 1));
        d.y = d.figli[0].y;   // radice in testa: ogni nodo sta all'altezza del suo primo figlio
      } else { maxFoglia = Math.max(maxFoglia, d.w); d.y = foglie++; }
      posati.push(d);
    };
    giro(cima, 0);
    const rigaH = 34, mx = 14, my = 32;
    // ogni colonna è larga quanto l'etichetta più lunga della sua generazione (più lo spazio per il gomito)
    const minimi = Array.from({ length: prof }, (_, l) => Math.max(70, (maxPerLivello[l] ?? 0) + 26));
    const totaleMin = minimi.reduce((a, b) => a + b, 0);
    const extra = prof ? Math.max(0, Math.min(26 * prof, larg - 2 - 2 * mx - maxFoglia - 10 - totaleMin)) / prof : 0;
    const colonne = minimi.map((m) => Math.min(250, m + extra));
    const inizio = [0];
    for (const c of colonne) inizio.push(inizio[inizio.length - 1] + c);
    const W = Math.ceil(mx * 2 + inizio[prof] + maxFoglia + 10), H = Math.ceil(my + Math.max(0, foglie - 1) * rigaH + 24);
    const X = (d: Disegnato) => mx + inizio[d.x], Y = (d: Disegnato) => my + d.y * rigaH;
    return { cima, tutti, posati, dim, W, H, X, Y };
  }, [larg, font, nodi, nomi, t]);

  const cammino = useMemo(() => {
    const s = new Set<number>();
    if (sel == null || !disegno) return s;
    for (let n: NodoAlbero | null | undefined = disegno.tutti.get(sel); n; n = n.padreNodo) s.add(n.id);
    return s;
  }, [sel, disegno]);

  const scelto = sel != null && disegno ? disegno.tutti.get(sel) : null;
  const percorso: NodoAlbero[] = [];
  for (let n = scelto ?? null; n; n = n.padreNodo) percorso.unshift(n);
  const gruppo = aperto != null && disegno ? disegno.posati.find((d) => d.id === aperto) ?? null : null;

  const chiudi = (rendiFuoco: boolean) => {
    const id = aperto;
    setAperto(null);
    if (rendiFuoco && id != null) gruppiRef.current.get(id)?.focus();
  };
  const apri = (d: Disegnato) => setAperto(aperto === d.id ? null : d.id);
  const vai = (n: NodoAlbero) => router.push(`/${lang}/w/${n.slug}`);

  return (
    <>
      <div className="stemma-wrap" ref={wrap}>
        {disegno && (
          <div className="stemma-tela" style={{ width: disegno.W, minHeight: disegno.H }}>
            <svg className={`stemma cresce${sel != null ? ' selezione' : ''}`} width={disegno.W} height={disegno.H}
              viewBox={`0 0 ${disegno.W} ${disegno.H}`} role="group" aria-label={t.stemmaDi(fmt(disegno.cima.n!))}>
              <g>
                {disegno.posati.filter((d) => d.padre).map((d) => {
                  const p = d.padre!, xm = disegno.X(d) - 14;
                  const evid = d.n ? cammino.has(d.id) : false;
                  return <path key={'a' + d.id} className={`st-arco ${d.n ? classeArco(d.n.tipo) : 'e-gruppo'}${evid ? ' evid' : ''}`}
                    d={`M${disegno.X(p) + 4},${disegno.Y(p)}H${xm}V${disegno.Y(d)}H${disegno.X(d) - 4}`} />;
                })}
              </g>
              <g>
                {disegno.posati.map((d) => d.n ? (
                  <g key={'n' + d.id} className={`st-nodo ${classeRamo(d.n.ramo)}${d.n.ricostruito ? ' ric' : ''}${cammino.has(d.id) ? ' evid' : ''}`}
                    tabIndex={0} role="link" aria-label={`${fmt(d.n)}, ${d.n.lingua_nome}${d.n.glossa ? ': ' + d.n.glossa : ''}`}
                    onMouseEnter={() => setSel(d.id)} onMouseLeave={() => setSel(null)}
                    onFocus={() => setSel(d.id)} onBlur={() => setSel(null)}
                    onClick={() => vai(d.n!)}
                    onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); vai(d.n!); } }}>
                    <rect className="st-hit" x={disegno.X(d) - 7} y={disegno.Y(d) - 23} width={d.w + 18} height={30} rx={4} />
                    <circle cx={disegno.X(d)} cy={disegno.Y(d)} r={d.padre ? 3.6 : 5.4} />
                    <text x={disegno.X(d) + 8} y={disegno.Y(d) - 7}>
                      <tspan className="st-lemma">{fmt(d.n)}</tspan>
                      <tspan className="st-sigla" dx={5}>{d.n.lingua_sigla}</tspan>
                    </text>
                  </g>
                ) : (
                  <g key={'g' + d.id} className="st-gruppo" tabIndex={0} role="button"
                    ref={(el) => { if (el) gruppiRef.current.set(d.id, el); else gruppiRef.current.delete(d.id); }}
                    aria-haspopup="dialog" aria-expanded={aperto === d.id} aria-controls={aperto === d.id ? `tendina${d.id}` : undefined}
                    aria-label={t.altreDa(d.membri.length, fmt(d.padre!.n!))}
                    onMouseEnter={() => setSel(d.padre!.id)} onMouseLeave={() => setSel(null)}
                    onFocus={() => setSel(d.padre!.id)} onBlur={() => setSel(null)}
                    onClick={() => apri(d)}
                    onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); apri(d); } }}>
                    <rect className="st-hit" x={disegno.X(d) - 7} y={disegno.Y(d) - 23} width={d.w + 18} height={30} rx={4} />
                    <text x={disegno.X(d) + 2} y={disegno.Y(d) - 7}><tspan className="st-piu">{t.altreParole(d.membri.length)} ▾</tspan></text>
                  </g>
                ))}
              </g>
            </svg>
            {gruppo && (
              <Tendina key={gruppo.id} id={`tendina${gruppo.id}`} lang={lang} membri={gruppo.membri} dim={disegno.dim}
                titolo={t.altreDa(gruppo.membri.length, fmt(gruppo.padre!.n!))} onChiudi={chiudi}
                ancora={gruppiRef.current.get(gruppo.id) ?? null}
                stile={{
                  left: Math.max(4, Math.min(disegno.X(gruppo) - 8, disegno.W - 348)),
                  ...(disegno.Y(gruppo) > disegno.H - 330 && disegno.H > 360
                    ? { bottom: disegno.H - disegno.Y(gruppo) + 28 } : { top: disegno.Y(gruppo) + 10 }),
                }} />
            )}
          </div>
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

// La lista a tendina dei figli raccolti: un campo per filtrare (anche nelle glosse), ogni parola con la sua voce e,
// se ha discendenti, il link al suo stemma. Si chiude con Esc, con il pulsante o con un clic fuori.
function Tendina({ id, lang, titolo, membri, dim, onChiudi, ancora, stile }: {
  id: string; lang: Lang; titolo: string; membri: NodoAlbero[]; dim: Map<number, number>;
  onChiudi: (rendiFuoco: boolean) => void; ancora: Element | null; stile: CSSProperties;
}) {
  const t = TESTI[lang];
  const [q, setQ] = useState('');
  const box = useRef<HTMLDivElement>(null);
  const campo = useRef<HTMLInputElement>(null);
  useEffect(() => { campo.current?.focus(); }, []);
  useEffect(() => {
    const fuori = (e: MouseEvent) => {
      const el = e.target as Node;
      if (box.current?.contains(el) || ancora?.contains(el)) return;
      onChiudi(false);
    };
    document.addEventListener('mousedown', fuori);
    return () => document.removeEventListener('mousedown', fuori);
  }, [ancora, onChiudi]);
  const piano = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
  const cerca = piano(q.trim());
  const visibili = cerca ? membri.filter((m) => piano(m.lemma).includes(cerca) || (m.glossa && piano(m.glossa).includes(cerca))) : membri;
  return (
    <div className="tendina" id={id} ref={box} role="dialog" aria-label={titolo} style={stile}
      onKeyDown={(e) => { if (e.key === 'Escape') { e.stopPropagation(); onChiudi(true); } }}>
      <div className="tendina-testa">
        <span>{titolo}</span>
        <button type="button" className="tendina-chiudi" onClick={() => onChiudi(true)} aria-label={t.chiudi}>×</button>
      </div>
      <input ref={campo} type="search" className="tendina-campo" placeholder={t.filtraParole} aria-label={t.filtraParole}
        value={q} onChange={(e) => setQ(e.target.value)} />
      <ul className="tendina-lista">
        {visibili.map((m) => (
          <li key={m.id} className={classeRamo(m.ramo)}>
            <Link href={`/${lang}/w/${m.slug}`} prefetch={false}>
              <span className="lemma">{fmt(m)}</span> <span className="sigla">{m.lingua_sigla}</span>
              {m.glossa && <span className="gl"> {G(m.glossa, lang)}</span>}
            </Link>
            {(dim.get(m.id) ?? 0) > 0 && (
              <Link className="quanti" href={`/${lang}/r/${m.slug}`} prefetch={false} title={t.apriStemmaDi(fmt(m))}>
                {t.discendentiN(dim.get(m.id)!)}
              </Link>
            )}
          </li>
        ))}
        {!visibili.length && <li className="vuoto">{t.nessunaParola}</li>}
      </ul>
    </div>
  );
}
