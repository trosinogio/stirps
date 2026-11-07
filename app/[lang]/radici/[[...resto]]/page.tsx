import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI, type Lang } from '@/lib/i18n';
import { elencoRadici, PER_PAGINA } from '@/lib/dati';
import { classeRamo, fmt, G } from '@/lib/forme';
import type { ElencoRadici } from '@/lib/tipi';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

const PREDEFINITA = 'ine-pro';   // l'indice si apre sulle radici indoeuropee
const IN_VISTA = 8;              // lingue nella fila dei filtri; le altre in una tendina

// /radici[/n] (indoeuropee), /radici/<lingua>[/n], /radici/tutte[/n], /radici/provvisorie[/n]
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

export default async function Radici({ params }: { params: Promise<{ lang: string; resto?: string[] }> }) {
  const { lang, resto } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
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
          {pagina > 1 && <Link className="btn" href={href(pagina - 1)}>{t.precedenti}</Link>}
          <span>{t.paginaDi(pagina, pagine)}</span>
          {pagina < pagine && <Link className="btn" href={href(pagina + 1)}>{t.successive}</Link>}
        </nav>
      )}
      {!provvisorie && (
        <p className="nota-sez rad-provvisorie">{t.capostipitiNota} <Link href={`/${lang}/radici/provvisorie`}>{t.capostipitiProvvisori} ›</Link></p>
      )}
    </>
  );
}
