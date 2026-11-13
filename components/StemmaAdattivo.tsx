'use client';
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeArco, classeRamo, fmt, G } from '@/lib/forme';
import { costruisciAlbero, dimensioni, dividiFigli, nomiNascondibili, type NodoAlbero } from '@/lib/albero';
import type { NodoPiatto } from '@/lib/tipi';

const CHIAVE_NOMI = 'stirps.stemma.nomi';   // la scelta del lettore sui nomi propri, solo nel suo browser

// Su schermo stretto mostra lo stemma verticale (generato sul server, passato come children);
// su schermo largo, se la famiglia non supera LIMITE_DISEGNO parole (nodi non nullo), lo sostituisce con lo stemma orizzontale disegnato qui. Sopra, gli strumenti dello stemma:
// i nomi propri sono nascosti finché il lettore non chiede di vederli.
// nodi è null per una famiglia oltre LIMITE_DISEGNO: non si disegna, e le parole non viaggiano fino al browser.
// Gli strumenti: cercare una parola (lemma o glossa: le trovate si evidenziano con il loro percorso dalla radice, Invio
// passa alla prossima), tenere solo i rami che portano a una lingua, fermarsi a una generazione. Valgono per tutti e due
// gli stemmi: quello orizzontale li riceve, nel verticale (generato sul server) si applicano agli elementi della pagina.
const piano = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

export default function StemmaAdattivo({ lang, nodi, nascosti, lingue, base, children }: {
  lang: Lang; nodi: NodoPiatto[] | null; nascosti: number; lingue: [string, string, number][]; base: string; children: ReactNode;
}) {
  const t = TESTI[lang];
  const s = t.strumentiStemma;
  const [largo, setLargo] = useState(false);
  const [nomi, setNomi] = useState(false);
  const [q, setQ] = useState('');
  const [lingua, setLingua] = useState<string | null>(null);
  const [livelli, setLivelli] = useState<number | null>(null);
  const [conta, setConta] = useState<[number, number] | null>(null);
  const [indice, setIndice] = useState(0);
  const ctrl = useRef<HTMLDivElement>(null);
  const orizzontale = largo && !!nodi;
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 760px)');
    const f = () => setLargo(mq.matches);
    f();
    mq.addEventListener('change', f);
    try { setNomi(localStorage.getItem(CHIAVE_NOMI) === '1'); } catch { /* memoria del browser non disponibile */ }
    return () => mq.removeEventListener('change', f);
  }, []);
  const cambia = () => {
    const v = !nomi;
    setNomi(v);
    try { localStorage.setItem(CHIAVE_NOMI, v ? '1' : '0'); } catch { /* idem */ }
  };
  // lo stemma verticale: le classi e gli attributi sugli elementi della pagina
  useEffect(() => {
    const box = ctrl.current;
    if (!box || orizzontale) return;
    box.querySelectorAll('.trovato, .tieni, .attuale').forEach((e) => e.classList.remove('trovato', 'tieni', 'attuale'));
    const cerca = piano(q.trim());
    let trovati = 0;
    const apriSopra = (el: Element) => {
      for (let x: Element | null = el.parentElement; x && x !== box; x = x.parentElement) {
        if (x.tagName === 'DETAILS') (x as HTMLDetailsElement).open = true;
        if (lingua && x.tagName === 'LI') x.classList.add('tieni');
      }
    };
    box.querySelectorAll<HTMLLIElement>('li[data-lingua]').forEach((li) => {
      const riga = li.querySelector(':scope > .riga');
      if (lingua && li.dataset.lingua === lingua) { li.classList.add('tieni'); apriSopra(li); }
      if (cerca && riga && piano(riga.textContent ?? '').includes(cerca)) {
        riga.classList.add('trovato');
        trovati++;
        apriSopra(li);
      }
    });
    box.dataset.filtro = lingua ? 'si' : 'no';
    box.dataset.livelli = livelli == null ? '' : String(livelli);
    setConta(cerca ? [trovati, 0] : null);
    setIndice(0);
  }, [q, lingua, livelli, orizzontale]);
  // Invio: la prossima parola trovata, al centro dello schermo
  const prossima = () => {
    const box = ctrl.current;
    if (!box) return;
    const tutte = [...box.querySelectorAll('.trovato')];
    if (!tutte.length) return;
    tutte.forEach((e) => e.classList.remove('attuale'));
    const el = tutte[indice % tutte.length];
    el.classList.add('attuale');
    el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'smooth' });
    setIndice(indice + 1);
  };
  const principali = lingue.slice(0, 7);
  const altre = lingue.slice(7);
  const nomeLingua = lingue.find((l) => l[0] === lingua)?.[1];
  return (
    <>
      <div className="stemma-strumenti" role="group" aria-label={s.titolo}>
        <div className="st-riga">
          <input type="search" className="st-cerca" placeholder={s.cerca} aria-label={s.cerca} value={q}
            onChange={(e) => setQ(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); prossima(); } }} />
          {conta && <span className="st-conta" aria-live="polite">{conta[0] + conta[1] ? s.trovati(conta[0], conta[1]) : s.nessuno}{conta[0] > 1 && <span className="st-nota"> · {s.prossima}</span>}</span>}
        </div>
        {lingue.length > 1 && (
          <div className="st-riga">
            <span className="st-etichetta">{s.lingue}</span>
            <button type="button" className="btn-chip" aria-pressed={!lingua} onClick={() => setLingua(null)}>{s.tutte}</button>
            {principali.map(([c, nome, n]) => (
              <button key={c} type="button" className="btn-chip" aria-pressed={lingua === c} onClick={() => setLingua(lingua === c ? null : c)}>
                {nome} <span className="n">{n}</span>
              </button>
            ))}
            {altre.length > 0 && (
              <select className="st-altre" aria-label={s.altre} value={altre.some((l) => l[0] === lingua) ? lingua! : ''}
                onChange={(e) => setLingua(e.target.value || null)}>
                <option value="">{s.altre}</option>
                {altre.map(([c, nome, n]) => <option key={c} value={c}>{nome} ({n})</option>)}
              </select>
            )}
            {lingua && nomeLingua && <a className="st-link" href={`${base}/lingue#l-${lingua}`}>{s.paroleIn(nomeLingua)}</a>}
          </div>
        )}
        <div className="st-riga">
          <span className="st-etichetta">{s.generazioni}</span>
          {[1, 2, 3].map((l) => (
            <button key={l} type="button" className="btn-chip" aria-pressed={livelli === l} onClick={() => setLivelli(livelli === l ? null : l)}>{l}</button>
          ))}
          <button type="button" className="btn-chip" aria-pressed={livelli == null} onClick={() => setLivelli(null)}>{s.tutteGen}</button>
          {nascosti > 0 && (
            <button type="button" className="btn-chip st-nomi" aria-pressed={nomi} onClick={cambia}>
              {nomi ? t.nomiPropriNascondi : t.nomiPropriMostra(nascosti)}
            </button>
          )}
        </div>
      </div>
      <div className="stemma-ctrl" ref={ctrl} data-nomi={nomi ? 'si' : 'no'}>
        {orizzontale ? <StemmaOrizzontale lang={lang} nodi={nodi!} nomi={nomi} q={q} lingua={lingua} livelli={livelli}
          onConta={(a, b) => { setConta(q.trim() ? [a, b] : null); setIndice(0); }} /> : children}
      </div>
    </>
  );
}

// Un nodo disegnato: una parola, o il gruppo dei figli raccolti nella lista a tendina («+ 190 parole»)
interface Disegnato { id: number; n: NodoAlbero | null; padre: Disegnato | null; membri: NodoAlbero[]; figli: Disegnato[]; x: number; y: number; w: number }

function StemmaOrizzontale({ lang, nodi, nomi, q, lingua, livelli, onConta }: {
  lang: Lang; nodi: NodoPiatto[]; nomi: boolean; q: string; lingua: string | null; livelli: number | null;
  onConta: (visibili: number, nelleListe: number) => void;
}) {
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
    // con una lingua scelta restano le sue parole e i rami che ci portano
    let tieni: Set<number> | null = null;
    if (lingua) {
      tieni = new Set<number>();
      for (const n of tutti.values()) {
        if (n.lingua !== lingua) continue;
        for (let x: NodoAlbero | null | undefined = n; x && !tieni.has(x.id); x = x.padreNodo) tieni.add(x.id);
      }
    }
    // l'albero da disegnare: senza i nomi propri nascosti, con i figli minori raccolti in un gruppo; oltre l'ultima
    // generazione scelta, tutti i figli stanno nel gruppo
    const costruisci = (n: NodoAlbero, padre: Disegnato | null, liv: number): Disegnato => {
      const d: Disegnato = { id: n.id, n, padre, membri: [], figli: [], x: 0, y: 0, w: 0 };
      const figli = n.figli.filter((c) => !nascosti.has(c.id) && (!tieni || tieni.has(c.id)));
      const { mostrati, raccolti } = livelli != null && liv >= livelli ? { mostrati: [], raccolti: figli } : dividiFigli(figli, dim);
      d.figli = mostrati.map((c) => costruisci(c, d, liv + 1));
      if (raccolti.length) d.figli.push({ id: -n.id, n: null, padre: d, membri: raccolti, figli: [], x: 0, y: 0, w: 0 });
      return d;
    };
    const cima = costruisci(radice, null, 0);
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
  }, [larg, font, nodi, nomi, t, lingua, livelli]);

  // la ricerca: le parole trovate tra quelle disegnate, il loro percorso dalla radice, e quante stanno nelle liste
  const ricerca = useMemo(() => {
    const trovati = new Set<number>(), percorso = new Set<number>();
    let nelleListe = 0;
    const cerca = piano(q.trim());
    if (!cerca || !disegno) return { trovati, percorso, nelleListe };
    const va = (n: NodoAlbero) => piano(n.lemma).includes(cerca) || (!!n.glossa && piano(n.glossa).includes(cerca));
    for (const d of disegno.posati) {
      if (d.n && va(d.n)) {
        trovati.add(d.id);
        for (let x: NodoAlbero | null | undefined = d.n; x; x = x.padreNodo) percorso.add(x.id);
      } else if (!d.n) nelleListe += d.membri.filter(va).length;
    }
    return { trovati, percorso, nelleListe };
  }, [q, disegno]);
  useEffect(() => { onConta(ricerca.trovati.size, ricerca.nelleListe); }, [ricerca]); // eslint-disable-line react-hooks/exhaustive-deps

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
            <svg className={`stemma cresce${sel != null ? ' selezione' : ''}${ricerca.trovati.size ? ' ricerca' : ''}`} width={disegno.W} height={disegno.H}
              viewBox={`0 0 ${disegno.W} ${disegno.H}`} role="group" aria-label={t.stemmaDi(fmt(disegno.cima.n!))}>
              <g>
                {disegno.posati.filter((d) => d.padre).map((d) => {
                  const p = d.padre!, xm = disegno.X(d) - 14;
                  const evid = d.n ? cammino.has(d.id) : false;
                  const evidR = d.n ? ricerca.percorso.has(d.id) : false;
                  return <path key={'a' + d.id} className={`st-arco ${d.n ? classeArco(d.n.tipo) : 'e-gruppo'}${d.n?.dubbio ? ' dubbio' : ''}${evid ? ' evid' : ''}${evidR ? ' evid-r' : ''}`}
                    d={`M${disegno.X(p) + 4},${disegno.Y(p)}H${xm}V${disegno.Y(d)}H${disegno.X(d) - 4}`} />;
                })}
                {/* un legame dubbio (certezza 1) porta un «?» sopra l'ultimo tratto */}
                {disegno.posati.filter((d) => d.padre && d.n?.dubbio).map((d) => (
                  <text key={'d' + d.id} className="st-dub" x={disegno.X(d) - 9} y={disegno.Y(d) - 5} textAnchor="middle" aria-hidden="true">?</text>
                ))}
              </g>
              <g>
                {disegno.posati.map((d) => d.n ? (
                  <g key={'n' + d.id} className={`st-nodo ${classeRamo(d.n.ramo)}${d.n.ricostruito ? ' ric' : ''}${cammino.has(d.id) ? ' evid' : ''}${ricerca.percorso.has(d.id) ? ' evid-r' : ''}${ricerca.trovati.has(d.id) ? ' trovato' : ''}`}
                    tabIndex={0} role="link" aria-label={`${fmt(d.n)}, ${d.n.lingua_nome}${d.n.glossa ? ': ' + d.n.glossa : ''}${d.n.dubbio ? ' (' + t.legameDubbio + ')' : ''}`}
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
                  {i > 0 && c.dubbio && <abbr className="dub" title={t.legameDubbio}>?</abbr>}
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
              <Link className="quanti" href={`/${lang}/r/${m.slug}/stemma`} prefetch={false} title={t.apriStemmaDi(fmt(m))}>
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
