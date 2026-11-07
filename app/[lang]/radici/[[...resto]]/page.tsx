import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI, type Lang } from '@/lib/i18n';
import { elencoRadici, indiceRadici, PER_PAGINA, PER_PAGINA_AREA } from '@/lib/dati';
import { classeRamo, fmt, G } from '@/lib/forme';
import type { ElencoRadici, IndiceRadici, RadiceArea } from '@/lib/tipi';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

const PREDEFINITA = 'ine-pro';   // l'indice si apre sulle radici indoeuropee
const IN_VISTA = 8;              // lingue nella fila dei filtri; le altre in una tendina

const SENZA_AREA = 'senza-area';

// /radici (indoeuropee, per area), /radici/<protolingua> (per area), /radici/<protolingua>/<area>[/n] (un'area in ordine
// alfabetico); restano /radici/tutte[/n] e /radici/provvisorie[/n] (dalla famiglia più grande) e /radici/<lingua>/<n>
function leggiAree(resto: string[] | undefined) {
  const parti = (resto ?? []).map(decodeURIComponent);
  if (parti.length === 0) return { capo: PREDEFINITA, area: null, pagina: 1 };
  if (['tutte', 'provvisorie'].includes(parti[0]) || /^\d+$/.test(parti[0]) || !/^[a-z]{2,3}(-[a-z]+)*$/i.test(parti[0])) return null;
  if (parti.length === 1 || (parti.length === 2 && /^\d+$/.test(parti[1]))) return { capo: parti[0], area: null, pagina: 1 };
  if (!/^[a-z-]+$/.test(parti[1]) || parti.length > 3 || (parti[2] != null && !/^\d+$/.test(parti[2]))) return null;
  return { capo: parti[0], area: parti[1] === SENZA_AREA ? '' : parti[1], pagina: parti[2] ? Number(parti[2]) : 1 };
}

// /radici/tutte[/n], /radici/provvisorie[/n]: l'elenco dalla famiglia più grande
function leggi(resto: string[] | undefined) {
  const parti = (resto ?? []).map(decodeURIComponent);
  const primo = parti[0] && !/^\d+$/.test(parti[0]) ? parti[0] : null;
  const provvisorie = primo === 'provvisorie';
  const capo = provvisorie || primo === 'tutte' ? null : primo ?? PREDEFINITA;
  const numero = primo ? parti[1] : parti[0];
  const n = numero == null ? 1 : Number(numero);
  return {
    provvisorie, capo, filtro: primo, pagina: Number.isInteger(n) && n > 0 ? n : 1,
    valido: parti.length <= (primo ? 2 : 1) && (numero == null || /^\d+$/.test(numero)) && (!primo || primo === 'tutte' || provvisorie || /^[a-z]{2,3}(-[a-z]+)*$/i.test(primo)),
  };
}

export async function generateMetadata({ params }: { params: Promise<{ lang: string; resto?: string[] }> }): Promise<Metadata> {
  const { lang, resto } = await params;
  if (!isLang(lang)) return {};
  const t = TESTI[lang];
  return { title: leggi(resto).provvisorie ? t.capostipitiProvvisori : t.radici };
}

function Filtri({ el, lang, scelta }: { el: ElencoRadici; lang: Lang; scelta: string | null }) {
  const t = TESTI[lang];
  const gruppi = [...el.gruppi].sort((a, b) => (b.lingua === PREDEFINITA ? 1 : 0) - (a.lingua === PREDEFINITA ? 1 : 0) || b.n - a.n);
  const tutte = gruppi.reduce((k, g) => k + g.n, 0);
  const href = (c: string) => `/${lang}/radici${c === PREDEFINITA ? '' : '/' + c}`;
  const chip = (c: string, nome: string, n: number) => (
    <Link key={c} className="btn-chip" href={href(c)} aria-current={(scelta ?? 'tutte') === c ? 'page' : undefined} prefetch={false}>
      {nome} <span className="n">{n.toLocaleString(lang === 'it' ? 'it-IT' : 'en-GB')}</span>
    </Link>
  );
  const altre = gruppi.slice(IN_VISTA);
  return (
    <nav className="filtri-radici" aria-label={t.radiciPerLingua}>
      <span className="filtri-tit">{t.radiciPerLingua}</span>
      {gruppi.slice(0, IN_VISTA).map((g) => chip(g.lingua, g.nome, g.n))}
      {chip('tutte', t.tutteLeLingueChip, tutte)}
      {altre.length > 0 && (
        <details className="filtri-altre" open={altre.some((g) => g.lingua === scelta) || undefined}>
          <summary>{t.altreLingueN(altre.length)}</summary>
          <div className="filtri-lista">{altre.map((g) => chip(g.lingua, g.nome, g.n))}</div>
        </details>
      )}
    </nav>
  );
}

function Riga({ r, lang, iniziale }: { r: RadiceArea | ElencoRadici['radici'][number]; lang: Lang; iniziale?: string }) {
  const t = TESTI[lang];
  return (
    <li id={iniziale ? `i-${iniziale}` : undefined}>
      <Link className="rad-riga" href={`/${lang}/r/${r.slug}`} prefetch={false}>
        <span className={`rad-nome ${classeRamo(r.ramo)}`}>
          <span className="lemma">{fmt(r)}</span>
          <span className="sigla">{r.lingua_sigla}</span>
          {r.glossa && <span className="gl">{G(r.glossa, lang)}</span>}
        </span>
        <span className="rad-conti">{t.paroleLingue(r.discendenti, r.lingue)}</span>
        {r.esempi.length > 0 && <span className="rad-esempi">{t.radiceEsempi(r.esempi)}</span>}
      </Link>
    </li>
  );
}

function FiltriLingue({ ind, lang }: { ind: IndiceRadici; lang: Lang }) {
  const t = TESTI[lang];
  const gruppi = [...ind.gruppi].sort((a, b) => (b.lingua === PREDEFINITA ? 1 : 0) - (a.lingua === PREDEFINITA ? 1 : 0) || b.n - a.n);
  const href = (c: string) => `/${lang}/radici${c === PREDEFINITA ? '' : '/' + c}`;
  const chip = (c: string, nome: string, n: number) => (
    <Link key={c} className="btn-chip" href={href(c)} aria-current={ind.capo_lingua === c ? 'page' : undefined} prefetch={false}>
      {nome} <span className="n">{n.toLocaleString(lang === 'it' ? 'it-IT' : 'en-GB')}</span>
    </Link>
  );
  const altre = gruppi.slice(IN_VISTA);
  return (
    <nav className="filtri-radici" aria-label={t.radiciPerLingua}>
      <span className="filtri-tit">{t.radiciPerLingua}</span>
      {gruppi.slice(0, IN_VISTA).map((g) => chip(g.lingua, g.nome, g.n))}
      {altre.length > 0 && (
        <details className="filtri-altre" open={altre.some((g) => g.lingua === ind.capo_lingua) || undefined}>
          <summary>{t.altreLingueN(altre.length)}</summary>
          <div className="filtri-lista">{altre.map((g) => chip(g.lingua, g.nome, g.n))}</div>
        </details>
      )}
    </nav>
  );
}

async function PerAree({ lang, capo, area: chiesta, pagina }: { lang: Lang; capo: string; area: string | null; pagina: number }) {
  const t = TESTI[lang];
  const loc = lang === 'it' ? 'it-IT' : 'en-GB';
  let area = chiesta;
  let ind = await indiceRadici(lang, capo, area, pagina);
  if (!ind.gruppi.some((g) => g.lingua === capo)) notFound();
  // una protolingua le cui radici non hanno ancora un'area: subito tutte, in ordine alfabetico
  if (area === null && ind.aree.length === 1 && ind.aree[0].area === '') {
    area = '';
    ind = await indiceRadici(lang, capo, area, pagina);
  }
  const unicaArea = ind.aree.length === 1;
  const base = `/${lang}/radici${capo === PREDEFINITA ? '' : '/' + capo}`;
  const baseLingua = `/${lang}/radici/${capo}`;
  const nomeArea = (a: string, nome: string | null) => (a ? nome ?? a : t.aree.senzaArea);
  const codiceArea = (a: string) => a || SENZA_AREA;
  const chipAree = unicaArea ? null : (
    <nav className="filtri-radici aree-radici" aria-label={t.aree.titolo}>
      <span className="filtri-tit">{t.aree.titolo}</span>
      {ind.aree.map((a) => (
        <Link key={a.area} className="btn-chip" prefetch={false} aria-current={area === a.area ? 'page' : undefined}
              href={`${baseLingua}/${codiceArea(a.area)}`}>
          {nomeArea(a.area, a.nome)} <span className="n">{a.n.toLocaleString(loc)}</span>
        </Link>
      ))}
    </nav>
  );
  if (area === null) {
    return (
      <>
        <FiltriLingue ind={ind} lang={lang} />
        {chipAree}
        {ind.sezioni.map((s) => (
          <section key={s.area} className="area-sezione">
            <h2>{nomeArea(s.area, s.nome)} <span className="conta-l">{s.n.toLocaleString(loc)}</span></h2>
            <ul className="radici">{s.radici.map((r) => <Riga key={r.id} r={r} lang={lang} />)}</ul>
            {s.n > s.radici.length && <Link className="area-tutte" href={`${baseLingua}/${codiceArea(s.area)}`} prefetch={false}>{t.aree.tutte(s.n)}</Link>}
          </section>
        ))}
        <p className="nota-sez">{t.aree.nota}</p>
      </>
    );
  }
  const nArea = ind.aree.find((a) => a.area === area);
  if (!nArea) notFound();
  const pagine = Math.max(1, Math.ceil(nArea.n / PER_PAGINA_AREA));
  if (pagina > pagine) notFound();
  const href = (p: number) => `${baseLingua}/${codiceArea(area)}${p === 1 ? '' : '/' + p}`;
  let precedente: string | null = null;
  return (
    <>
      <FiltriLingue ind={ind} lang={lang} />
      {chipAree}
      <p className="conto-radici">
        {unicaArea ? t.radiciConto(nArea.n, false).replace(/,.*$/, '') + ' · A–Z'
                   : <><Link href={base} prefetch={false}>{t.aree.tutteLeAree}</Link> · {t.aree.conto(nArea.n, nomeArea(area, nArea.nome))}</>}
      </p>
      {ind.iniziali.length > 1 && (
        <nav className="iniziali-radici" aria-label={t.aree.iniziali}>
          {ind.iniziali.map((i) => (
            <Link key={i.iniziale} href={`${href(i.pagina)}#i-${i.iniziale}`} prefetch={false}>{i.iniziale.toUpperCase()}</Link>
          ))}
        </nav>
      )}
      <ul className="radici">
        {ind.radici.map((r) => {
          const nuova = r.iniziale !== precedente;
          precedente = r.iniziale;
          return <Riga key={r.id} r={r} lang={lang} iniziale={nuova && r.iniziale ? r.iniziale : undefined} />;
        })}
      </ul>
      {pagine > 1 && (
        <nav className="paginazione" aria-label={t.paginaDi(pagina, pagine)}>
          {pagina > 1 && <Link className="btn" href={href(pagina - 1)} prefetch={false}>{t.precedenti}</Link>}
          <span>{t.paginaDi(pagina, pagine)}</span>
          {pagina < pagine && <Link className="btn" href={href(pagina + 1)} prefetch={false}>{t.successive}</Link>}
        </nav>
      )}
      {!unicaArea && <p className="nota-sez">{t.aree.nota}</p>}
    </>
  );
}

export default async function Radici({ params }: { params: Promise<{ lang: string; resto?: string[] }> }) {
  const { lang, resto } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const aree = leggiAree(resto);
  if (aree) {
    return (
      <>
        <header className="testa-voce">
          <h1 className="voce-titolo">{t.radici}</h1>
          <p className="nota-sez">{t.radiciNota}</p>
        </header>
        <PerAree lang={lang} capo={aree.capo} area={aree.area} pagina={aree.pagina} />
        <p className="nota-sez rad-provvisorie">{t.capostipitiNota} <Link href={`/${lang}/radici/provvisorie`}>{t.capostipitiProvvisori} ›</Link></p>
      </>
    );
  }
  const { provvisorie, capo, filtro, pagina, valido } = leggi(resto);
  if (!valido) notFound();
  const el = await elencoRadici(lang, !provvisorie, pagina, capo);
  if (capo && !el.gruppi.some((g) => g.lingua === capo)) notFound();
  const pagine = Math.max(1, Math.ceil(el.totale / PER_PAGINA));
  if (pagina > pagine) notFound();
  const base = `/${lang}/radici${filtro && filtro !== PREDEFINITA ? '/' + filtro : ''}`;
  const href = (p: number) => (p === 1 ? base : `${base}/${p}`);
  return (
    <>
      {provvisorie && <Link className="indietro" href={`/${lang}/radici`}>‹ {t.radici}</Link>}
      <header className="testa-voce">
        <h1 className="voce-titolo">{provvisorie ? t.capostipitiProvvisori : t.radici}</h1>
        <p className="nota-sez">{provvisorie ? t.capostipitiNota : t.radiciNota}</p>
      </header>
      {!provvisorie && <Filtri el={el} lang={lang} scelta={capo} />}
      <p className="conto-radici">{t.radiciConto(el.totale, provvisorie)}</p>
      <ul className="radici">
        {el.radici.map((r) => (
          <li key={r.id}>
            <Link className="rad-riga" href={`/${lang}/r/${r.slug}`} prefetch={false}>
              <span className={`rad-nome ${classeRamo(r.ramo)}`}>
                <span className="lemma">{fmt(r)}</span>
                <span className="sigla">{r.lingua_sigla}</span>
                {r.glossa && <span className="gl">{G(r.glossa, lang)}</span>}
              </span>
              <span className="rad-conti">{t.paroleLingue(r.discendenti, r.lingue)}</span>
              {r.esempi.length > 0 && <span className="rad-esempi">{t.radiceEsempi(r.esempi)}</span>}
            </Link>
          </li>
        ))}
      </ul>
      {pagine > 1 && (
        <nav className="paginazione" aria-label={t.paginaDi(pagina, pagine)}>
          {pagina > 1 && <Link className="btn" href={href(pagina - 1)} prefetch={false}>{t.precedenti}</Link>}
          <span>{t.paginaDi(pagina, pagine)}</span>
          {pagina < pagine && <Link className="btn" href={href(pagina + 1)} prefetch={false}>{t.successive}</Link>}
        </nav>
      )}
      {!provvisorie && (
        <p className="nota-sez rad-provvisorie">{t.capostipitiNota} <Link href={`/${lang}/radici/provvisorie`}>{t.capostipitiProvvisori} ›</Link></p>
      )}
    </>
  );
}
