import Link from 'next/link';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo, fmt, G, omografo, ORDINE_LINGUE, ORDINE_RAMI } from '@/lib/forme';
import { costruisciAlbero, dimensioni, nomiNascondibili, type NodoAlbero } from '@/lib/albero';
import { intercala, VoceLink } from '@/components/comuni';
import type { NodoPiatto } from '@/lib/tipi';

const PRIME = 12;        // parole della lingua del lettore con la glossa
const ANCHE = 30;        // le altre, solo il lemma
const RAMI = 8;          // figli diretti della cima
const PER_LINGUA = 6;    // parole per ogni altra lingua

// La prima vista di una famiglia: le parole della lingua del lettore (le più usate per prime), i rami principali
// (i figli diretti della cima, ordinati per quante parole portano) e, lingua per lingua, le parole più vicine alla cima.
// Lo stemma intero e l'elenco completo per lingua restano nelle altre schede.
export default function SintesiFamiglia({ lang, nodi, ranghi, base }: { lang: Lang; nodi: NodoPiatto[]; ranghi: Map<string, number>; base: string }) {
  const t = TESTI[lang], s = t.sintesi;
  const { radice, tutti } = costruisciAlbero(nodi);
  const dim = dimensioni(radice);
  const nascosti = nomiNascondibili(radice);
  const prof = new Map<number, number>();
  const giro = (n: NodoAlbero, d: number) => { prof.set(n.id, d); n.figli.forEach((c) => giro(c, d + 1)); };
  giro(radice, 0);
  const vicine = (a: NodoAlbero, b: NodoAlbero) => prof.get(a.id)! - prof.get(b.id)! || (b.glossa ? 1 : 0) - (a.glossa ? 1 : 0) || a.lemma.localeCompare(b.lemma);
  const comuni = nodi.slice(1).map((n) => tutti.get(n.id)!).filter((n) => !n.nome_proprio);

  // il lessico di frequenza conta forme: il rango vale solo per la prima voce di quella forma (pain, non pain², il pane)
  const rango = (n: NodoAlbero) => (omografo(n.slug) ? Infinity : ranghi.get(n.lemma) ?? Infinity);
  const mie = comuni.filter((n) => n.lingua === lang).sort((a, b) => rango(a) - rango(b) || vicine(a, b));
  const prime = mie.slice(0, PRIME), anche = mie.slice(PRIME, PRIME + ANCHE), restano = mie.length - PRIME - ANCHE;

  const rami = radice.figli.filter((c) => !nascosti.has(c.id))
    .sort((a, b) => (dim.get(b.id) ?? 0) - (dim.get(a.id) ?? 0) || a.lemma.localeCompare(b.lemma));
  const massimo = Math.max(1, ...rami.map((c) => dim.get(c.id) ?? 0));

  const perLingua = new Map<string, NodoAlbero[]>();
  for (const n of comuni) if (n.lingua !== lang) perLingua.set(n.lingua, [...(perLingua.get(n.lingua) ?? []), n]);
  // l'ordine di ORDINE_LINGUE; una lingua che non c'è va dopo le altre del suo ramo, o in fondo
  const ultimaDelRamo = new Map<string, number>();
  for (const [c, ns] of perLingua) {
    const i = ORDINE_LINGUE.indexOf(c), r = ns[0].ramo;
    if (i >= 0 && r) ultimaDelRamo.set(r, Math.max(ultimaDelRamo.get(r) ?? -1, i));
  }
  const pos = (c: string, r: string | null) => {
    const i = ORDINE_LINGUE.indexOf(c);
    return i >= 0 ? i : r && ultimaDelRamo.has(r) ? ultimaDelRamo.get(r)! + 0.5 : 1000 + (r && ORDINE_RAMI.includes(r) ? ORDINE_RAMI.indexOf(r) : 99);
  };
  const lingue = [...perLingua.entries()].sort((a, b) => pos(a[0], a[1][0].ramo) - pos(b[0], b[1][0].ramo) || b[1].length - a[1].length);

  return (
    <div className="sintesi">
      {mie.length > 0 && (
        <section className="sintesi-sez">
          <h2 className="sintesi-tit">{s.nellaLingua(mie.length)}</h2>
          {ranghi.size > 0 && <p className="sintesi-nota">{s.perUso}</p>}
          <ul className="sintesi-prime">
            {prime.map((n) => (
              <li key={n.id}>
                <VoceLink n={n} lang={lang} sigla={false} />
                {n.glossa && <span className="gl" title={G(n.glossa, lang)}>{G(n.glossa, lang)}</span>}
              </li>
            ))}
          </ul>
          {anche.length > 0 && (
            <p className="sintesi-anche">
              {intercala(anche.map((n) => <VoceLink key={n.id} n={n} lang={lang} sigla={false} />), (i) => <span key={'s' + i}>, </span>)}
              {restano > 0 ? <> … <Link href={`${base}/lingue#l-${lang}`} prefetch={false}>{s.tutte(mie.length)}</Link></> : '.'}
            </p>
          )}
        </section>
      )}

      {rami.length > 0 && (
        <section className="sintesi-sez">
          <h2 className="sintesi-tit">{s.rami}</h2>
          <p className="sintesi-nota">{s.ramiNota(fmt(radice))}</p>
          <ol className="sintesi-rami">
            {rami.slice(0, RAMI).map((c) => {
              const d = dim.get(c.id) ?? 0;
              return (
                <li key={c.id} className={classeRamo(c.ramo)}>
                  <span className="sr-voce">
                    <VoceLink n={c} lang={lang} />
                    {c.glossa && <span className="gl">{G(c.glossa, lang)}</span>}
                  </span>
                  <span className="sr-quanti">
                    <span className="sr-barra" style={{ width: `${Math.max(2, (100 * d) / massimo)}%` }} aria-hidden="true" />
                    {d > 0 && <Link className="quanti" href={`/${lang}/r/${c.slug}`} prefetch={false} title={s.apriFamiglia(fmt(c))}>{t.discendentiN(d)}</Link>}
                  </span>
                </li>
              );
            })}
          </ol>
          {rami.length > RAMI && <p className="sintesi-anche"><Link href={`${base}/stemma`} prefetch={false}>{s.altriRami(rami.length - RAMI)}</Link></p>}
        </section>
      )}

      {lingue.length > 0 && (
        <section className="sintesi-sez">
          <h2 className="sintesi-tit">{s.altreLingue(lingue.length)}</h2>
          <p className="sintesi-nota">{s.altreLingueNota}</p>
          {lingue.map(([c, ns]) => (
            <div key={c} className={`riga-lingua ${classeRamo(ns[0].ramo)}`}>
              <div className="nome-l">{ns[0].lingua_nome} <span className="n">{ns.length}</span></div>
              <div className="parole">
                {[...ns].sort(vicine).slice(0, PER_LINGUA).map((n) => <span key={n.id} className="parola-l"><VoceLink n={n} lang={lang} sigla={false} /></span>)}
                {ns.length > PER_LINGUA && <Link className="quanti" href={`${base}/lingue#l-${c}`} prefetch={false}>{t.altreParole(ns.length - PER_LINGUA)}</Link>}
              </div>
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
