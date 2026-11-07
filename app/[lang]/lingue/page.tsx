import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI, type Lang } from '@/lib/i18n';
import { indice } from '@/lib/dati';
import { classeRamo } from '@/lib/forme';
import { alberoLingue, type NodoLingua } from '@/lib/albero-lingue';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: TESTI[lang].lingue } : {};
}

const MOSTRATI = 8;          // figli di una lingua mostrati subito; gli altri in una tendina
const PICCOLA = 3;           // una famiglia con meno lingue va tra le «altre famiglie»

function Nodi({ nodi, lang }: { nodi: NodoLingua[]; lang: Lang }) {
  const t = TESTI[lang];
  const loc = lang === 'it' ? 'it-IT' : 'en-GB';
  const voce = (n: NodoLingua) => (
    <li key={n.l.codice}>
      <Link className="lingua-b" href={`/${lang}/l/${n.l.codice}`} prefetch={false}>{n.l.nome}<span>{n.l.n.toLocaleString(loc)}</span></Link>
      {n.varieta.length > 0 && (
        <span className="varieta-l">
          {t.alberoL.varieta}:{' '}
          {n.varieta.map((v, i) => (
            <span key={v.codice}>{i > 0 && ' · '}<Link href={`/${lang}/l/${v.codice}`} prefetch={false}>{v.nome}</Link> {v.n.toLocaleString(loc)}</span>
          ))}
        </span>
      )}
      {n.figli.length > 0 && <Nodi nodi={n.figli} lang={lang} />}
    </li>
  );
  // le lingue senza discendenti, se sono tante, vanno in fila; quelle con discendenti restano nell'albero
  return (
    <ul className="albero-l">
      {nodi.slice(0, MOSTRATI).map(voce)}
      {nodi.length > MOSTRATI && (
        <li className="altre-l">
          <details>
            <summary>{t.alberoL.altre(nodi.length - MOSTRATI)}</summary>
            <ul className="albero-l">{nodi.slice(MOSTRATI).map(voce)}</ul>
          </details>
        </li>
      )}
    </ul>
  );
}

export default async function Lingue({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const loc = lang === 'it' ? 'it-IT' : 'en-GB';
  const ind = await indice(lang, 0);
  const famiglie = alberoLingue(ind.lingue);
  const grandi = famiglie.filter((f) => f.lingue >= PICCOLA && f.famiglia && f.famiglia !== 'translingue');
  const piccole = famiglie.filter((f) => !grandi.includes(f));
  return (
    <>
      <Link className="indietro" href={`/${lang}`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className="voce-titolo">{t.lingue}</h1>
        <p className="nota-sez">{t.lingueNota}</p>
      </header>
      <nav className="indice-famiglie" aria-label={t.lingue}>
        {grandi.map((f) => <a key={f.famiglia} href={`#f-${f.famiglia}`}>{f.nome}</a>)}
        {piccole.length > 0 && <a href="#f-altre">{t.alberoL.altreFamiglie}</a>}
      </nav>
      {grandi.map((f) => (
        <section key={f.famiglia} id={`f-${f.famiglia}`} className="famiglia-albero">
          <h2>{t.famiglia(f.nome)} <span className="conta-l">{t.alberoL.conta(f.lingue, f.parole)}</span></h2>
          {f.capo.some((n) => n.l.codice.endsWith('-pro')) && (
            <Nodi nodi={f.capo.filter((n) => n.l.codice.endsWith('-pro'))} lang={lang} />
          )}
          {f.rami.map((r) => (
            <div key={r.ramo} className={`ramo-albero ${classeRamo(r.ramo)}`}>
              <h3>{r.nome} <span className="conta-l">{t.alberoL.conta(r.lingue, r.parole)}</span></h3>
              <Nodi nodi={r.radici} lang={lang} />
            </div>
          ))}
          {f.capo.some((n) => !n.l.codice.endsWith('-pro')) && (
            <div className={f.rami.length ? 'ramo-albero' : 'ramo-albero senza-rami'}>
              {f.rami.length > 0 && <h3>{t.alberoL.altreLingue}</h3>}
              <Nodi nodi={f.capo.filter((n) => !n.l.codice.endsWith('-pro'))} lang={lang} />
            </div>
          )}
        </section>
      ))}
      {piccole.length > 0 && (
        <section id="f-altre" className="famiglia-albero">
          <h2>{t.alberoL.altreFamiglie}</h2>
          <dl className="famiglie-piccole">
            {piccole.map((f) => (
              <div key={f.famiglia || '-'}>
                <dt>{f.famiglia ? f.nome : '—'}</dt>
                <dd>
                  {[...f.capo, ...f.rami.flatMap((r) => r.radici)].map((n, i) => (
                    <span key={n.l.codice}>{i > 0 && ' · '}<Link href={`/${lang}/l/${n.l.codice}`} prefetch={false}>{n.l.nome}</Link> {n.l.n.toLocaleString(loc)}</span>
                  ))}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}
    </>
  );
}
