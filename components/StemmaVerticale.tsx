import Link from 'next/link';
import type { ReactNode } from 'react';
import type { Lang } from '@/lib/i18n';
import { TESTI } from '@/lib/i18n';
import { classeArco, classeRamo, fmt, G } from '@/lib/forme';
import { costruisciAlbero, dimensioni, dividiFigli, nomiNascondibili, type NodoAlbero } from '@/lib/albero';
import type { NodoPiatto } from '@/lib/tipi';

// Stemma come elenco annidato: leggibile su qualunque schermo e anche senza JavaScript.
// I nomi propri da nascondere portano la classe «np» (li mostra o nasconde StemmaAdattivo); oltre la soglia i figli
// minori stanno in un <details>, la lista a tendina nativa, con il numero dei loro discendenti. Con «livelli» l'elenco si ferma
// a quella profondità (i rami di poche parole restano interi): sotto, il numero dei discendenti porta allo stemma del ramo.
// Con «chiusiDa» (la famiglia intera, caricata nel browser da StemmaAdattivo) l'albero c'è tutto, ma da quella profondità
// ogni ramo sta chiuso in un <details> con il numero dei suoi discendenti, e «aperti» dice quali aprire.
const PICCOLO = 5;

export default function StemmaVerticale({ lang, nodi, livelli, chiusiDa, aperti }: {
  lang: Lang; nodi: NodoPiatto[]; livelli?: number; chiusiDa?: number; aperti?: Set<number>;
}) {
  const t = TESTI[lang];
  const { radice } = costruisciAlbero(nodi);
  const nascosti = nomiNascondibili(radice);
  const dim = dimensioni(radice);
  const classi = (n: NodoAlbero, np: boolean) => [n.tipo ? classeArco(n.tipo) : '', np ? 'np' : '', n.dubbio ? 'dubbio' : ''].filter(Boolean).join(' ') || undefined;
  const riga = (n: NodoAlbero) => (
    <Link className={`riga ${classeRamo(n.ramo)}`} href={`/${lang}/w/${n.slug}`} prefetch={false}>
      {n.dubbio && <abbr className="dub" title={t.legameDubbio}>?</abbr>}
      <span className="lemma">{fmt(n)}</span>
      <span className="sigla">{n.lingua_sigla}</span>
      {n.tipo_etichetta && <span className="tp">{n.tipo_etichetta}</span>}
      {n.glossa && <span className="gl">{G(n.glossa, lang)}</span>}
    </Link>
  );
  const quanti = (c: NodoAlbero) => (dim.get(c.id) ?? 0) > 0 && (
    <Link className="quanti" data-id={c.id} href={`/${lang}/r/${c.slug}/stemma`} prefetch={false} title={t.apriStemmaDi(fmt(c))}>
      {t.discendentiN(dim.get(c.id)!)}
    </Link>
  );
  const ramo = (n: NodoAlbero, np: boolean, liv: number): ReactNode => {
    const nascostoQui = (c: NodoAlbero) => np || nascosti.has(c.id);
    const { mostrati, raccolti } = dividiFigli(n.figli, dim, nascostoQui);
    const comuni = raccolti.filter((c) => !nascostoQui(c)).length;
    const sotto = (
          <ol>
            {mostrati.map((c) => ramo(c, nascostoQui(c), liv + 1))}
            {raccolti.length > 0 && (
              <li className={`raccolti${comuni ? '' : ' np'}`}>
                <details>
                  <summary>
                    {t.altreParole(comuni)}
                    {raccolti.length > comuni && <span className="np"> {t.eNomiPropri(raccolti.length - comuni)}</span>}
                  </summary>
                  <ul>
                    {raccolti.map((c) => chiusiDa != null ? ramo(c, nascostoQui(c), liv + 1) : (
                      <li key={c.id} className={classi(c, nascostoQui(c))} data-lingua={c.lingua} data-nodo={c.id}>
                        {riga(c)}
                        {quanti(c)}
                      </li>
                    ))}
                  </ul>
                </details>
              </li>
            )}
          </ol>
    );
    return (
      <li key={n.id} className={classi(n, np)} data-lingua={n.lingua} data-nodo={n.id}>
        {riga(n)}
        {livelli != null && liv >= livelli && (dim.get(n.id) ?? 0) > PICCOLO ? quanti(n)
          : n.figli.length > 0 && (chiusiDa != null && liv >= chiusiDa
            ? <details className="ramo-chiuso" open={aperti?.has(n.id)}><summary className="quanti">{t.discendentiN(dim.get(n.id) ?? 0)}</summary>{sotto}</details>
            : sotto)}
      </li>
    );
  };
  return <ol className="stemma-v" aria-label={t.stemmaDi(fmt(radice))}>{ramo(radice, false, 0)}</ol>;
}
