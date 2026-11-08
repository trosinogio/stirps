import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, type Lang } from '@/lib/i18n';
import { TESTI_REDAZIONE } from '@/lib/testi-redazione';
import { richiediRedattore } from '@/lib/auth/redattore';
import { codaVerifica, contatori, listaLavoro, ultimeModifiche, type VoceLista } from '@/lib/redazione';
import TestataRedazione from '@/components/redazione/Testata';
import Ricerca from '@/components/Ricerca';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Redazione', robots: { index: false } };

export default async function Cruscotto({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI_REDAZIONE[lang];
  const redattore = await richiediRedattore(lang);
  const [c, coda, modifiche, prime, catene, senza] = await Promise.all([contatori(), codaVerifica(lang, 60), ultimeModifiche(15), listaLavoro(lang), listaLavoro(lang, 'catene-da-sistemare'), listaLavoro(lang, 'senza-etimologia')]);
  const verificate = prime.filter((v) => v.stato === 'verificato').length;
  const gruppi = [...new Set(prime.map((v) => v.gruppo))].map((g) => {
    const voci = prime.filter((v) => v.gruppo === g);
    return { g, tot: voci.length, ok: voci.filter((v) => v.stato === 'verificato').length };
  });
  const loc = lang === 'it' ? 'it-IT' : 'en-GB';
  return (
    <div className="redazione">
      <TestataRedazione lang={lang} redattore={redattore} />
      <p className="red-intro">{t.cruscottoIntro}</p>
      <p className="red-contatori">
        <span><b>{c.da_verificare.toLocaleString(loc)}</b> {t.daVerificare}</span>
        <span><b>{c.verificate.toLocaleString(loc)}</b> {t.verificate}</span>
        <span><b>{c.modifiche.toLocaleString(loc)}</b> {t.modificheSettimana}</span>
      </p>
      <section className="red-sezione">
        <h2>{t.apriVoce}</h2>
        <div className="red-cerca"><Ricerca lang={lang} grande base={`/${lang}/redazione/w/`} /></div>
      </section>
      {prime.length > 0 && (
        <section className="red-sezione">
          <h2>{t.prime}</h2>
          <p className="nota-sez">{t.primeNota}</p>
          <div className="red-progresso" role="progressbar" aria-valuemin={0} aria-valuemax={prime.length} aria-valuenow={verificate}>
            <div style={{ width: `${(100 * verificate) / prime.length}%` }} />
          </div>
          <p className="red-contatori"><span><b>{verificate}</b> {t.verificateSu(verificate, prime.length).replace(/^\d+ /, '')}</span></p>
          <p className="red-gruppi">
            {gruppi.map((x) => <span key={x.g} className={x.ok === x.tot ? 'completo' : ''}>{x.g} <b>{x.ok}/{x.tot}</b></span>)}
          </p>
          <div className="red-tabella-scorre">
            <table className="red-tabella">
              <thead><tr><th>N.</th><th>{t.colonne.parola}</th><th>{t.colGruppo}</th><th>{t.colonne.stato}</th><th>{t.colonne.fonti}</th><th>{t.colDate}</th></tr></thead>
              <tbody>
                {prime.map((v) => (
                  <tr key={v.slug} className={v.stato === 'verificato' ? 'red-fatta' : ''}>
                    <td>{v.posizione}</td>
                    <td>
                      <Link href={`/${lang}/redazione/w/${v.slug}`} className="lemma">{v.lemma}</Link>
                      {v.suggerimento && <span className="gl">{v.suggerimento}</span>}
                    </td>
                    <td>{v.gruppo}</td>
                    <td>{v.stato && <span className={`red-stato red-stato-${v.stato}`}>{t.stati[v.stato] ?? v.stato}</span>}</td>
                    <td>{v.fonti}</td>
                    <td>{v.date}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
      <SezioneLista lang={lang} titolo={t.catene} nota={t.cateneNota} voci={catene} />
      <SezioneLista lang={lang} titolo={t.senzaEtimologia} nota={t.senzaEtimologiaNota} voci={senza} />
      <section className="red-sezione">
        <h2>{prime.length ? t.codaFrequenza : t.coda}</h2>
        <p className="nota-sez">{t.codaNota}</p>
        <div className="red-tabella-scorre">
          <table className="red-tabella">
            <thead><tr><th>{t.colonne.parola}</th><th>{t.colonne.rango}</th><th>{t.colonne.stato}</th><th>{t.colonne.ipotesi}</th><th>{t.colonne.fonti}</th></tr></thead>
            <tbody>
              {coda.map((v) => (
                <tr key={v.slug}>
                  <td><Link href={`/${lang}/redazione/w/${v.slug}`} className="lemma">{v.lemma}</Link>{v.glossa && <span className="gl">{v.glossa}</span>}</td>
                  <td>{v.rango.toLocaleString(loc)}</td>
                  <td><span className={`red-stato red-stato-${v.stato_editoriale}`}>{t.stati[v.stato_editoriale] ?? v.stato_editoriale}</span></td>
                  <td>{v.ipotesi_accolta ?? '—'}</td>
                  <td>{v.rimandi}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section className="red-sezione">
        <h2>{t.ultimeModifiche}</h2>
        {modifiche.length ? (
          <ul className="red-storico">
            {modifiche.map((m, i) => (
              <li key={i}>
                <time dateTime={m.momento}>{new Date(m.momento).toLocaleString(loc, { dateStyle: 'short', timeStyle: 'short' })}</time>
                <span>{m.utente} {t.operazioni[m.operazione] ?? m.operazione} {t.tabelle[m.tabella] ?? m.tabella}{m.slug && <> {t.da} <Link href={`/${lang}/redazione/w/${m.slug}`}>{m.lemma}</Link></>}</span>
              </li>
            ))}
          </ul>
        ) : <p className="vuoto">{t.nessunaModifica}</p>}
      </section>
    </div>
  );
}

// una lista di lavoro ricalcolata a ogni deploy: le prime 50 voci, con il gruppo e le fonti
function SezioneLista({ lang, titolo, nota, voci }: { lang: Lang; titolo: string; nota: string; voci: VoceLista[] }) {
  const t = TESTI_REDAZIONE[lang];
  if (voci.length === 0) return null;
  return (
    <section className="red-sezione">
      <h2>{titolo} <span className="red-conta">{voci.length}</span></h2>
      <p className="nota-sez">{nota}</p>
      <div className="red-tabella-scorre">
        <table className="red-tabella">
          <thead><tr><th>N.</th><th>{t.colonne.parola}</th><th>{t.colGruppo}</th><th>{t.colonne.fonti}</th></tr></thead>
          <tbody>
            {voci.slice(0, 50).map((v) => (
              <tr key={v.slug}>
                <td>{v.posizione}</td>
                <td><Link href={`/${lang}/redazione/w/${v.slug}`} className="lemma">{v.lemma}</Link>{v.glossa && <span className="gl">{v.glossa}</span>}</td>
                <td>{v.gruppo}</td>
                <td>{v.fonti}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {voci.length > 50 && <p className="vuoto">{t.altre(voci.length - 50)}</p>}
    </section>
  );
}
