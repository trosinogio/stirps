import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { linguaInfo, paroleLingua } from '@/lib/dati';
import { classeRamo, G } from '@/lib/forme';
import { VoceLink } from '@/components/comuni';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

export async function generateMetadata({ params }: { params: Promise<{ lang: string; codice: string }> }): Promise<Metadata> {
  const { lang, codice } = await params;
  if (!isLang(lang)) return {};
  const l = await linguaInfo(codice, lang);
  return l ? { title: l.nome } : {};
}

export default async function Lingua({ params }: { params: Promise<{ lang: string; codice: string; iniziale?: string[] }> }) {
  const { lang, codice, iniziale } = await params;
  if (!isLang(lang)) notFound();
  // /l/grc, /l/grc/Π, /l/grc/ΚΑ/2: le parole; /l/grc/nomi, /l/grc/nomi/Π: i nomi propri, in un indice a parte
  const nomi = iniziale?.[0] === 'nomi';
  const segmenti = nomi ? iniziale!.slice(1) : iniziale ?? [];
  if (segmenti.length > 2 || (segmenti.length === 2 && !/^[1-9]\d{0,3}$/.test(segmenti[1]))) notFound();
  const pagina = segmenti[1] ? Number(segmenti[1]) : 1;
  const t = TESTI[lang];
  // le iniziali sono maiuscole (C, o CA per le prime due lettere); /it/l/it/c deve funzionare lo stesso
  const scelta = segmenti[0] ? decodeURIComponent(segmenti[0]).toLocaleUpperCase('it') : null;
  if (scelta && Array.from(scelta).length > 2) notFound();
  const [l, pl] = await Promise.all([linguaInfo(codice, lang), paroleLingua(codice, lang, scelta, nomi, pagina)]);
  if (!l || (scelta && !pl.iniziali.some((x) => x.iniziale === Array.from(scelta)[0]))) notFound();
  const base = `/${lang}/l/${codice}${nomi ? '/nomi' : ''}`;
  const dueLettere = (x: string) => Array.from(x).map((c, i) => (i ? c.toLocaleLowerCase('it') : c)).join('');
  const genitore = l.varieta_di ? t.varietaDi(l.varieta_di_nome ?? l.varieta_di)
    : l.antenato ? t.discendeDaLingua(l.antenato_nome ?? l.antenato) : null;
  return (
    <>
      <Link className="indietro" href={`/${lang}`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className={`voce-titolo ${classeRamo(l.ramo)}`}>{l.nome}<span className="sigla">{l.sigla}</span></h1>
        <p className={`meta ${classeRamo(l.ramo)}`}>
          <span className="lingua-n">{t.famigliaRamo(l.famiglia_nome, l.ramo === 'proto' ? null : l.ramo_nome)}</span>
          {genitore && <span>{genitore}</span>}
          <span>{t.paroleN(pl.totale_parole + pl.totale_nomi)}</span>
        </p>
      </header>
      {pl.totale_nomi > 0 && pl.totale_parole > 0 && (
        <nav className="sezioni-indice" aria-label={t.indiceSezioni}>
          <Link href={`/${lang}/l/${codice}`} prefetch={false} aria-current={nomi ? undefined : 'page'}>{t.indiceParole} <span>{pl.totale_parole.toLocaleString(lang)}</span></Link>
          <Link href={`/${lang}/l/${codice}/nomi`} prefetch={false} aria-current={nomi ? 'page' : undefined}>{t.indiceNomi} <span>{pl.totale_nomi.toLocaleString(lang)}</span></Link>
        </nav>
      )}
      {pl.iniziale !== null && pl.iniziali.length > 1 && (
        <nav className="iniziali" aria-label={t.iniziali}>
          {pl.iniziali.map((x) => (
            <Link key={x.iniziale} href={`${base}/${encodeURIComponent(x.iniziale)}`} prefetch={false}
              aria-current={x.iniziale === pl.iniziale ? 'page' : undefined} title={t.paroleN(x.n)}>{x.iniziale}</Link>
          ))}
        </nav>
      )}
      {pl.sottoiniziali.length > 1 && (
        <nav className="iniziali sotto" aria-label={t.sottoIniziali}>
          {pl.sottoiniziali.map((x) => (
            <Link key={x.iniziale} href={`${base}/${encodeURIComponent(x.iniziale)}`} prefetch={false}
              aria-current={x.iniziale === pl.sottoiniziale ? 'page' : undefined} title={t.paroleN(x.n)}>{dueLettere(x.iniziale)}</Link>
          ))}
        </nav>
      )}
      {pl.pagine.length > 1 && (
        <nav className="pagine-indice" aria-label={t.pagineIndice}>
          {pl.pagine.map((x, i) => (
            <Link key={i} href={`${base}/${encodeURIComponent(pl.sottoiniziale ?? pl.iniziale ?? '')}${i ? `/${i + 1}` : ''}`} prefetch={false}
              aria-current={i + 1 === pl.pagina ? 'page' : undefined}>{x.da} – {x.a}</Link>
          ))}
        </nav>
      )}
      {pl.parole.some((p) => p.glossa && p.glossa_lingua && p.glossa_lingua !== lang) && (
        <p className="nota-sez">{t.glosseAltrove(t.nomiLingue[pl.parole.find((p) => p.glossa_lingua && p.glossa_lingua !== lang)!.glossa_lingua!] ?? '')}</p>
      )}
      <ul className="elenco-voci" style={{ marginTop: 14 }}>
        {pl.parole.map((p) => (
          <li key={p.id}>
            <VoceLink n={p} lang={lang} sigla={false} />
            {p.translit && <i className="gl">{p.translit}</i>}
            {p.glossa && <span className="gl">{G(p.glossa, lang)}</span>}
          </li>
        ))}
      </ul>
    </>
  );
}
