import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI, type Lang } from '@/lib/i18n';
import { nodiPerSlug, periodiLingue } from '@/lib/dati';
import { fmt } from '@/lib/forme';
import { PERCORSI, slugPercorsi } from '@/lib/percorsi';
import { hash, indovinello, isTipo, storiaDelGiorno, storie, TIPI_STORIA, type Percorso, type Storia } from '@/lib/storie';
import { TESTI_STORIE } from '@/lib/testi-storie';
import Storie from '@/components/Storie';
import StoriaCarta, { Catena, ETICHETTE_TIPO } from '@/components/StoriaCarta';
import Indovinello from '@/components/Indovinello';
import LineaTempo, { type ArcoTempo, type NodoTempo } from '@/components/LineaTempo';

// ogni visita sceglie storie nuove: la pagina si compone a ogni richiesta
export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: TESTI[lang].storie } : {};
}

const caso = () => Math.floor(Math.random() * 1_000_000_000);

// i percorsi di una storia come linea del tempo: le generazioni contano dalla parola di oggi
async function tempo(s: Storia): Promise<{ nodi: NodoTempo[]; archi: ArcoTempo[] } | null> {
  const percorsi: Percorso[] = s.tipo === 'viaggio' ? [s.percorso] : s.tipo === 'famiglia' ? [] : [s.a, s.b];
  if (!percorsi.length) return null;
  const periodi = await periodiLingue([...new Set(percorsi.flat().map((n) => n.lingua))]);
  const nodi = new Map<number, NodoTempo>();
  const archi: ArcoTempo[] = [];
  percorsi.forEach((p, k) => p.forEach((n, i) => {
    const generazione = p.length - 1 - i;
    const prima = nodi.get(n.id);
    const per = periodi.get(n.lingua);
    if (!prima || prima.generazione < generazione) {
      nodi.set(n.id, {
        id: n.id, slug: n.slug, etichetta: fmt(n), sigla: n.lingua_sigla, lingua_nome: n.lingua_nome, ramo: n.ramo ?? null,
        ricostruita: per?.ricostruita ?? !!n.ricostruito,
        periodo: per?.anno_da != null ? { da: per.anno_da, a: per.anno_a } : null,
        attestata: n.attestata ?? null,
        principale: prima?.principale || (k === 0 && i === p.length - 1), generazione,
      });
    }
    if (i < p.length - 1) archi.push({ da: n.id, a: p[i + 1].id, tipo: n.tipo ?? 'generico', etichetta: n.tipo_nome });
  }));
  return { nodi: [...nodi.values()], archi };
}

function Filtri({ lang, tipo }: { lang: Lang; tipo?: string }) {
  const ts = TESTI_STORIE[lang];
  return (
    <nav className="filtri-storie" aria-label={ts.altre}>
      <Link href={`/${lang}/storie`} className={!tipo ? 'attivo' : ''}>{ts.tutte}</Link>
      {TIPI_STORIA.map((x) => (
        <Link key={x} href={`/${lang}/storie?tipo=${x}`} className={`filtro-${x} ${tipo === x ? 'attivo' : ''}`}>{ETICHETTE_TIPO[lang][x]}</Link>
      ))}
    </nav>
  );
}

export default async function PaginaStorie({ params, searchParams }: {
  params: Promise<{ lang: string }>; searchParams: Promise<{ s?: string; g?: string; tipo?: string }>;
}) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const sp = await searchParams;
  const t = TESTI[lang];
  const ts = TESTI_STORIE[lang];
  const seme = Number(sp.s) || caso();
  const semeGioco = Number(sp.g) || caso();
  const tipo = isTipo(sp.tipo) ? sp.tipo : undefined;
  const [oggi, altre, gioco, nodi] = await Promise.all([
    storiaDelGiorno(lang), storie(lang, seme, 10, tipo), indovinello(lang, semeGioco), nodiPerSlug(slugPercorsi(), lang),
  ]);
  const griglia = altre.filter((s) => s.chiave !== oggi?.chiave).slice(0, 9);
  const lineaOggi = oggi ? await tempo(oggi) : null;
  const qui = (extra: string) => `/${lang}/storie?${extra}`;

  // il gioco: opzioni mescolate sul server, così server e browser le mostrano nello stesso ordine
  const opzioni = gioco
    ? [gioco.giusta, ...gioco.sbagliate]
        .map((n) => ({ slug: n.slug, etichetta: fmt(n), sigla: n.lingua_sigla }))
        .sort((a, b) => hash(a.slug + semeGioco) - hash(b.slug + semeGioco))
    : [];

  return (
    <>
      <header className="testa-voce">
        <h1 className="voce-titolo">{t.storie}</h1>
        <p className="pagina-intro">{ts.intro}</p>
      </header>

      {oggi && (
        <section className="sez storie-oggi">
          <h2>{ts.oggi}</h2>
          <p className="nota-sez">{ts.oggiNota}</p>
          <StoriaCarta s={oggi} lang={lang} grande
            extra={lineaOggi && <LineaTempo lang={lang} nodi={lineaOggi.nodi} archi={lineaOggi.archi} t={t} />} />
        </section>
      )}

      {gioco && (
        <section className="sez">
          <Indovinello
            domanda={<>{ts.domanda} <i>{fmt(gioco.parola)}</i>?</>}
            opzioni={opzioni}
            giusta={gioco.giusta.slug}
            spiegazione={
              <>
                <i>{fmt(gioco.parola)}</i> {lang === 'it' ? 'e' : 'and'} <i>{fmt(gioco.giusta)}</i> {ts.spiegazione} <i>{fmt(gioco.radice)}</i>.
                <Catena p={gioco.percorso_parola} lang={lang} />
                <Catena p={gioco.percorso_giusta} lang={lang} />
              </>
            }
            testi={{ esatto: ts.esatto, sbagliato: ts.sbagliato, altro: ts.altroGioco, titolo: ts.gioco }}
            altro={qui(`g=${caso()}${tipo ? `&tipo=${tipo}` : ''}`)}
          />
        </section>
      )}

      <section className="sez">
        <div className="storie-testa">
          <h2>{ts.altre}</h2>
          <a className="btn btn-pieno" href={qui(`s=${caso()}${tipo ? `&tipo=${tipo}` : ''}`)}>{ts.rimescola}</a>
        </div>
        <p className="nota-sez">{ts.altreNota}</p>
        <Filtri lang={lang} tipo={tipo} />
        {griglia.length
          ? <div className="storie-griglia">{griglia.map((s) => <StoriaCarta key={s.chiave} s={s} lang={lang} />)}</div>
          : <p className="vuoto">{ts.vuoto}</p>}
      </section>

      <section className="sez">
        <h2>{ts.redazione}</h2>
        <p className="nota-sez">{ts.redazioneNota}</p>
        <Storie percorsi={PERCORSI} nodi={nodi} lang={lang} />
      </section>
    </>
  );
}
