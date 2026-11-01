import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { indice, nodiPerSlug, statoLavori } from '@/lib/dati';
import { classeRamo, fmt, G } from '@/lib/forme';
import { PERCORSI, NOME, slugPercorsi } from '@/lib/percorsi';
import { BarraRami } from '@/components/comuni';
import Marchio from '@/components/Marchio';
import Ricerca from '@/components/Ricerca';
import AlberoRami from '@/components/AlberoRami';
import Storie, { Parola } from '@/components/Storie';
import StoriaCarta from '@/components/StoriaCarta';
import { storiaDelGiorno } from '@/lib/storie';
import { TESTI_STORIE } from '@/lib/testi-storie';

export const revalidate = 300;
// nessuna pagina in fase di build: si generano alla prima visita e restano in cache (ISR)
export async function generateStaticParams() { return []; }

export default async function Home({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const [ind, nodi, stato, oggi] = await Promise.all([indice(lang, 40), nodiPerSlug(slugPercorsi(), lang), statoLavori(), storiaDelGiorno(lang)]);
  const radiciAmpie = ind.radici.filter((r) => r.dichiarata).sort((a, b) => b.discendenti - a.discendenti).slice(0, 6);
  const nome = nodi.get(NOME.voce);
  const totale = stato.redazione + stato.importate;

  return (
    <>
      {/* 1. il progetto: nome, che cosa fa, una ricerca; accanto, lo stemma delle sue lingue */}
      <section className="vetrina">
        <div className="vetrina-testo">
          <h1 className="vetrina-titolo"><Marchio grande nome={t.titolo} /></h1>
          <p className="vetrina-sottotitolo">{t.sottotitolo}</p>
          {nome && (
            <p className="vetrina-nome">
              <Link className={`voce ${classeRamo(nome.ramo)}`} href={`/${lang}/w/${nome.slug}`}>
                <span className="lemma">{nome.lemma}</span><span className="sigla">{nome.lingua_sigla}</span>
              </Link>
              <span className="gl">{t.heroNome.glossa},</span>
              <span>{t.heroNome.daQui}</span>
              {NOME.discendenti.map((s) => <Parola key={s} n={nodi.get(s)} lang={lang} />)}
            </p>
          )}
          <p className="vetrina-lead">{t.heroLead}</p>
          <Ricerca lang={lang} grande />
          <p className="vetrina-azioni">
            <Link className="btn btn-pieno" href={`/${lang}/radici`}>{t.esploraRadici}</Link>
            <Link className="btn" href={`/${lang}/metodo`}>{t.comeFunziona}</Link>
          </p>
        </div>
        <AlberoRami lang={lang} lingue={ind.lingue} />
      </section>

      <section className="sezione-home progetto">
        <h2>{t.progettoTitolo}</h2>
        <div className="progetto-griglia">
          {t.progetto.map((x) => (
            <div key={x.titolo}>
              <h3>{x.titolo}</h3>
              <p>{x.testo}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="sezione-home lavori">
        <h2>{t.statoTitolo}</h2>
        <p>{t.statoTesto(stato.redazione, stato.importate)}</p>
        <div className="stato-barra" aria-hidden="true">
          <span className="stato-redazione" style={{ flexGrow: Math.max(stato.redazione / totale, 0.012) }} />
          <span className="stato-importate" style={{ flexGrow: stato.importate / totale }} />
        </div>
        <p className="stato-legenda">
          <span><i className="stato-redazione" />{t.statoLegenda.redazione}</span>
          <span><i className="stato-importate" />{t.statoLegenda.importate}</span>
        </p>
      </section>

      {/* 2. le parole */}
      <section className="sezione-home sezione-parole">
        <h2>{t.paroleTitolo}</h2>
        <p className="nota-sez">{t.storieNota}</p>
        {oggi && (
          <div className="home-oggi">
            <p className="home-oggi-titolo">{TESTI_STORIE[lang].oggi}</p>
            <StoriaCarta s={oggi} lang={lang} />
          </div>
        )}
        <Storie percorsi={PERCORSI.slice(0, 4)} nodi={nodi} lang={lang} />
        <p className="altre"><Link className="btn" href={`/${lang}/storie`}>{t.tutteLeStorie}</Link></p>
        <div className="esplora-griglia">
          <div>
            <h3>{t.radiciAmpie}</h3>
            <ul className="radici">
              {radiciAmpie.map((r) => (
                <li key={r.id}>
                  <Link className="rad-riga" href={`/${lang}/r/${r.slug}`}>
                    <span className={`rad-nome ${classeRamo(r.ramo)}`}>
                      <span className="lemma">{fmt(r)}</span>
                      <span className="sigla">{r.lingua_sigla}</span>
                      {r.glossa && <span className="gl">{G(r.glossa, lang)}</span>}
                    </span>
                    <span className="rad-conti">{t.paroleLingue(r.discendenti, r.lingue)}</span>
                    <BarraRami rami={r.rami} />
                  </Link>
                </li>
              ))}
            </ul>
            <p className="altre"><Link className="btn" href={`/${lang}/radici`}>{t.tutteLeRadici(ind.totali.radici)}</Link></p>
          </div>
          <div>
            <h3>{t.lingueAmpie}</h3>
            <p className="lingue-top">
              {[...ind.lingue].sort((a, b) => b.n - a.n).slice(0, 10).map((l) => (
                <Link key={l.codice} className={`lingua-b ${classeRamo(l.ramo)}`} href={`/${lang}/l/${l.codice}`}>{l.nome}<span>{l.n.toLocaleString(lang === 'it' ? 'it-IT' : 'en-GB')}</span></Link>
              ))}
            </p>
            <p className="altre"><Link className="btn" href={`/${lang}/lingue`}>{t.tutteLeLingue(ind.lingue.length)}</Link></p>
          </div>
        </div>
      </section>

      <section className="sezione-home chi">
        <h2>{t.nav.chiSiamo}</h2>
        <p>{t.chiSiamoTeaser}</p>
        <p className="altre"><Link className="btn" href={`/${lang}/chi-siamo`}>{t.leggiChiSiamo}</Link></p>
      </section>
    </>
  );
}
