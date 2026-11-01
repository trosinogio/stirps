import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { indice, lingueGeo, paroleLingua } from '@/lib/dati';
import { classeRamo, G } from '@/lib/forme';
import { VoceLink } from '@/components/comuni';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

export async function generateMetadata({ params }: { params: Promise<{ lang: string; codice: string }> }): Promise<Metadata> {
  const { lang, codice } = await params;
  if (!isLang(lang)) return {};
  const l = (await indice(lang, 0)).lingue.find((x) => x.codice === codice);
  return l ? { title: l.nome } : {};
}

export default async function Lingua({ params }: { params: Promise<{ lang: string; codice: string; iniziale?: string[] }> }) {
  const { lang, codice, iniziale } = await params;
  if (!isLang(lang)) notFound();
  if (iniziale && iniziale.length > 1) notFound();
  const t = TESTI[lang];
  // le iniziali sono maiuscole (C, o CA per le prime due lettere); /it/l/it/c deve funzionare lo stesso
  const scelta = iniziale?.[0] ? decodeURIComponent(iniziale[0]).toLocaleUpperCase('it') : null;
  if (scelta && Array.from(scelta).length > 2) notFound();
  const [ind, geo, pl] = await Promise.all([indice(lang, 0), lingueGeo(lang), paroleLingua(codice, lang, scelta)]);
  const l = ind.lingue.find((x) => x.codice === codice);
  if (!l || (scelta && !pl.iniziali.some((x) => x.iniziale === Array.from(scelta)[0]))) notFound();
  const dueLettere = (x: string) => Array.from(x).map((c, i) => (i ? c.toLocaleLowerCase('it') : c)).join('');
  const nomi = new Map(geo.map((g) => [g.codice, g.nome]));
  const genitore = l.varieta_di ? t.varietaDi(nomi.get(l.varieta_di) ?? l.varieta_di)
    : l.antenato ? t.discendeDaLingua(nomi.get(l.antenato) ?? l.antenato) : null;
  return (
    <>
      <Link className="indietro" href={`/${lang}`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className={`voce-titolo ${classeRamo(l.ramo)}`}>{l.nome}<span className="sigla">{l.sigla}</span></h1>
        <p className={`meta ${classeRamo(l.ramo)}`}>
          <span className="lingua-n">{t.famigliaRamo(l.famiglia_nome, l.ramo === 'proto' ? null : l.ramo_nome)}</span>
          {genitore && <span>{genitore}</span>}
          <span>{t.paroleN(pl.totale)}</span>
        </p>
      </header>
      {pl.iniziale !== null && pl.iniziali.length > 1 && (
        <nav className="iniziali" aria-label={t.iniziali}>
          {pl.iniziali.map((x) => (
            <Link key={x.iniziale} href={`/${lang}/l/${codice}/${encodeURIComponent(x.iniziale)}`}
              aria-current={x.iniziale === pl.iniziale ? 'page' : undefined} title={t.paroleN(x.n)}>{x.iniziale}</Link>
          ))}
        </nav>
      )}
      {pl.sottoiniziali.length > 1 && (
        <nav className="iniziali sotto" aria-label={t.sottoIniziali}>
          {pl.sottoiniziali.map((x) => (
            <Link key={x.iniziale} href={`/${lang}/l/${codice}/${encodeURIComponent(x.iniziale)}`}
              aria-current={x.iniziale === pl.sottoiniziale ? 'page' : undefined} title={t.paroleN(x.n)}>{dueLettere(x.iniziale)}</Link>
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
