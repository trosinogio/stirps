import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { indice } from '@/lib/dati';
import { classeRamo, ORDINE_LINGUE, ORDINE_RAMI } from '@/lib/forme';
import type { LinguaIndice } from '@/lib/tipi';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: TESTI[lang].lingue } : {};
}

export default async function Lingue({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const ind = await indice(lang, 0);
  const famiglie = new Map<string, Map<string, LinguaIndice[]>>();
  for (const l of ind.lingue) {
    const f = l.famiglia_nome ?? '—';
    if (!famiglie.has(f)) famiglie.set(f, new Map());
    const rami = famiglie.get(f)!;
    if (!rami.has(l.ramo)) rami.set(l.ramo, []);
    rami.get(l.ramo)!.push(l);
  }
  const posL = (c: string) => (ORDINE_LINGUE.indexOf(c) + 1000) % 1000;
  return (
    <>
      <Link className="indietro" href={`/${lang}`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className="voce-titolo">{t.lingue}</h1>
        <p className="nota-sez">{t.lingueNota}</p>
      </header>
      <div className="famiglie-l">
        {[...famiglie.entries()].map(([f, rami]) => (
          <section key={f} className="famiglia-l">
            <h3>{t.famiglia(f)}</h3>
            {[...rami.entries()].sort((a, b) => ORDINE_RAMI.indexOf(a[0]) - ORDINE_RAMI.indexOf(b[0])).map(([r, ls]) => (
              <div key={r} className={`ramo-l ${classeRamo(r)}`}>
                <div className="nome-r">{ls[0].ramo_nome ?? r}</div>
                <div className="lingue-r">
                  {ls.sort((a, b) => posL(a.codice) - posL(b.codice)).map((l) => (
                    <Link key={l.codice} className="lingua-b" href={`/${lang}/l/${l.codice}`}>{l.nome}<span>{l.n}</span></Link>
                  ))}
                </div>
              </div>
            ))}
          </section>
        ))}
      </div>
    </>
  );
}
