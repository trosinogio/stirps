import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI, type Lang } from '@/lib/i18n';
import Automatica from '@/components/Automatica';
import Definizione from '@/components/Definizione';
import { lingueGeo, ranghi, scheda } from '@/lib/dati';
import { classeRamo, contaRami, fmt, G, nodiUnici, ORDINE_LINGUE, ORDINE_RAMI, ramoDi } from '@/lib/forme';
import { contaNascosti, costruisciAlbero, dimensioni, LIMITE_DISEGNO, nodiFamiglia, nomiNascondibili, sottoDubbio } from '@/lib/albero';
import { BarraRami, intercala, Legenda, VoceLink } from '@/components/comuni';
import StemmaAdattivo from '@/components/StemmaAdattivo';
import StemmaVerticale from '@/components/StemmaVerticale';
import Mappa from '@/components/Mappa';
import TrovaPercorso from '@/components/TrovaPercorso';
import SintesiFamiglia from '@/components/SintesiFamiglia';
import type { NodoPiatto, Scheda } from '@/lib/tipi';

export const revalidate = 300;
// nessuna pagina in fase di build: si generano alla prima visita e restano in cache (ISR)
export async function generateStaticParams() { return []; }
const VISTE = ['stemma', 'lingue', 'mappa'] as const;
type Vista = 'sintesi' | (typeof VISTE)[number];

function leggi(slug: string[]) {
  const parti = slug.map(decodeURIComponent);
  const ultima = parti[parti.length - 1];
  const vista: Vista = parti.length === 3 && (VISTE as readonly string[]).includes(ultima) ? (ultima as Vista) : 'sintesi';
  return { slug: (vista === 'sintesi' ? parti : parti.slice(0, 2)).join('/'), vista };
}

export async function generateMetadata({ params }: { params: Promise<{ lang: string; slug: string[] }> }): Promise<Metadata> {
  const { lang, slug } = await params;
  if (!isLang(lang)) return {};
  const sc = await scheda(leggi(slug).slug, lang);
  if (!sc) return {};
  return { title: TESTI[lang].stemmaTitolo(fmt(sc.lessema)), description: sc.lessema.glossa ?? undefined };
}

function Origine({ sc, lang }: { sc: Scheda; lang: Lang }) {
  const t = TESTI[lang], L = sc.lessema, acc = sc.ipotesi.find((i) => i.stato === 'accolta');
  if (sc.catena.length) {
    const genitori = nodiUnici(sc.catena.filter((c) => c.profondita === 1));
    return <p className="origine">{t.discendeDa}{intercala(genitori.map((c) => <VoceLink key={c.id} n={c} lang={lang} />), (i) => <span key={'s' + i}>, </span>)}.</p>;
  }
  if (acc && acc.origine !== 'etimo') {
    const alt = sc.ipotesi.filter((i) => i.stato === 'alternativa' || i.stato === 'minoritaria');
    return <p className="origine">{t.origini[acc.origine]}, {t.ipotesiAccolta}.{acc.nota ? ' ' + acc.nota : ''}{alt.length ? ' ' + t.inAlternativa + alt.map((a) => a.etichetta).join('; ') + '.' : ''}</p>;
  }
  if (L.ricostruito && L.pos === 'rad.' && L.definizione) return null;   // la definizione dice già che cos'è
  if (L.ricostruito) return <p className="origine">{L.pos === 'rad.' ? t.radiceRicostruita : t.formaRicostruitaCapo}</p>;
  if (L.pos === 'rad.') return <p className="origine">{t.radiceFormale}</p>;
  return <p className="origine">{t.capoProvvisorio}</p>;
}

function nomiNascosti(nodi: NodoPiatto[]) {
  const { radice } = costruisciAlbero(nodi);
  return contaNascosti(nomiNascondibili(radice), dimensioni(radice));
}

function PannelloLingue({ nodi, lang, dubbie }: { nodi: NodoPiatto[]; lang: Lang; dubbie: Set<number> }) {
  const per = new Map<string, Map<string, NodoPiatto[]>>();
  for (const n of nodi) {
    const r = ramoDi(n.ramo);
    if (!per.has(r)) per.set(r, new Map());
    if (!per.get(r)!.has(n.lingua)) per.get(r)!.set(n.lingua, []);
    per.get(r)!.get(n.lingua)!.push(n);
  }
  const posL = (c: string) => (ORDINE_LINGUE.indexOf(c) + 1000) % 1000;
  return (
    <>
      {[...per.entries()].sort((a, b) => ORDINE_RAMI.indexOf(a[0]) - ORDINE_RAMI.indexOf(b[0])).map(([r, lingue]) => (
        <section key={r} className={`gruppo r-${r}`}>
          <h3 className="gruppo-tit">{RAMO[lang][r] ?? r}</h3>
          {[...lingue.entries()].sort((a, b) => posL(a[0]) - posL(b[0])).map(([c, ns]) => (
            <div key={c} id={`l-${c}`} className={`riga-lingua ${classeRamo(ns[0].ramo)}`}>
              <div className="nome-l">{ns[0].lingua_nome} <span className="n">{ns.length}</span></div>
              <div className="parole">
                {ns.sort((a, b) => a.lemma.localeCompare(b.lemma)).map((n) => (
                  <span key={n.id} className="parola-l">
                    {dubbie.has(n.id) && <abbr className="dub" title={TESTI[lang].perLegameDubbio}>?</abbr>}
                    <VoceLink n={n} lang={lang} sigla={false} />
                    {n.glossa && <span className="gl"> {G(n.glossa, lang)}</span>}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </section>
      ))}
    </>
  );
}
const RAMO: Record<Lang, Record<string, string>> = {
  it: { proto: 'Protolingua comune', italica: 'Italico', ellenica: 'Ellenico', germanica: 'Germanico', slava: 'Slavo', indoiranica: 'Indoiranico', semitica: 'Semitico' },
  en: { proto: 'Common proto-language', italica: 'Italic', ellenica: 'Hellenic', germanica: 'Germanic', slava: 'Slavic', indoiranica: 'Indo-Iranian', semitica: 'Semitic' },
};

export default async function Radice({ params }: { params: Promise<{ lang: string; slug: string[] }> }) {
  const { lang, slug } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const { slug: s, vista } = leggi(slug);
  const sc = await scheda(s, lang);
  if (!sc) notFound();
  const L = sc.lessema;
  const nodi = nodiFamiglia(sc);
  const discendenti = nodi.slice(1);
  const nl = new Set(discendenti.map((n) => n.lingua)).size;
  // le parole che stanno nella famiglia per un legame dubbio (certezza 1), con i loro discendenti
  const dubbie = sottoDubbio(nodi);
  // le lingue della famiglia, le più presenti per prime: i filtri dello stemma
  const perLinguaN = new Map<string, [string, string, number]>();
  for (const n of discendenti) {
    const v = perLinguaN.get(n.lingua) ?? [n.lingua, n.lingua_nome, 0];
    v[2]++;
    perLinguaN.set(n.lingua, v);
  }
  const lingueFamiglia = [...perLinguaN.values()].sort((a, b) => b[2] - a[2] || a[1].localeCompare(b[1]));
  // risalire: la famiglia da cui discende la cima di questa
  const genitori = nodiUnici(sc.catena.filter((c) => c.profondita === 1));
  const grande = nodi.length > LIMITE_DISEGNO;
  const base = `/${lang}/r/${L.slug}`;
  const schede: [Vista, string, string][] = [['sintesi', t.schede.sintesi, base], ['stemma', t.schede.stemma, `${base}/stemma`],
    ['lingue', t.schede.lingue, `${base}/lingue`], ['mappa', t.schede.mappa, `${base}/mappa`]];
  const geo = vista === 'mappa' ? await lingueGeo(lang) : [];
  const usi = vista === 'sintesi' ? await ranghi(lang, [...new Set(discendenti.filter((n) => n.lingua === lang).map((n) => n.lemma))]) : new Map<string, number>();

  return (
    <>
      <Link className="indietro" href={`/${lang}/radici`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className={`voce-titolo ${classeRamo(L.ramo)}`}><span className="lemma">{fmt(L)}</span><span className="sigla">{L.lingua_nome}</span></h1>
        {L.translit && <p className="translit">{L.translit}</p>}
        {L.glossa && <p className="glossa-g" lang={L.glossa_lingua && L.glossa_lingua !== lang ? L.glossa_lingua : undefined}>{L.glossa_automatica && <Automatica lang={lang} />}{G(L.glossa, lang)}</p>}
        <Definizione L={L} lang={lang} />
        <Origine sc={sc} lang={lang} />
        {genitori.length > 0 && (
          <p className="azioni-voce">
            {genitori.slice(0, 2).map((g) => (
              <Link key={g.id} className="btn" href={`/${lang}/r/${g.slug}${vista === 'sintesi' ? '' : '/' + vista}`} prefetch={false}>
                ↑ {t.strumentiStemma.risali(fmt(g))}
              </Link>
            ))}
          </p>
        )}
        {discendenti.length > 0 && (
          <div className="statistiche">
            <span className="conti">{t.paroleInLingue(discendenti.length, nl)}</span>
            {dubbie.size > 0 && <span className="conti dubbie"><span className="dub" aria-hidden="true">?</span>{t.paroleDubbie(dubbie.size)}</span>}
            <BarraRami rami={contaRami(discendenti)} />
          </div>
        )}
      </header>
      {discendenti.length > 1 && <TrovaPercorso lang={lang} slug={L.slug} nodi={grande ? null : nodi} />}
      <nav className="schede" aria-label={t.vistaFamiglia}>
        {schede.map(([k, testo, href]) => <Link key={k} href={href} aria-current={k === vista ? 'page' : undefined}>{testo}</Link>)}
      </nav>
      <div className="pannello">
        {!discendenti.length ? <p className="vuoto">{t.nessunDiscendente}</p>
          : vista === 'lingue' ? <PannelloLingue nodi={nodi} lang={lang} dubbie={dubbie} />
          : vista === 'sintesi' ? <SintesiFamiglia lang={lang} nodi={nodi} ranghi={usi} base={base} />
          : vista === 'mappa' ? <Mappa lang={lang} nodi={nodi} archi={discendenti.map((n) => ({ da: n.padre!, a: n.id, tipo: n.tipo! }))} lingue={geo} />
          : (
            <>
              {grande && <p className="sintesi-nota">{t.stemmaRidotto}</p>}
              <StemmaAdattivo lang={lang} nodi={grande ? null : nodi} nascosti={nomiNascosti(nodi)} lingue={lingueFamiglia} base={base}><StemmaVerticale lang={lang} nodi={nodi} livelli={grande ? 2 : undefined} /></StemmaAdattivo>
              <Legenda lang={lang} dubbi={dubbie.size > 0} />
            </>
          )}
      </div>
      <p className="apri-voce"><Link className="btn" href={`/${lang}/w/${L.slug}`}>{t.apriVoceDi(fmt(L))}</Link></p>
    </>
  );
}
