import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import { TESTI } from '@/lib/i18n';
import { classeArco, classeRamo, fmt, G } from '@/lib/forme';
import { costruisciAlbero, type NodoAlbero } from '@/lib/albero';
import type { NodoPiatto } from '@/lib/tipi';

// Stemma come elenco annidato: leggibile su qualunque schermo e anche senza JavaScript.
export default function StemmaVerticale({ lang, nodi }: { lang: Lang; nodi: NodoPiatto[] }) {
  const { radice } = costruisciAlbero(nodi);
  const ramo = (n: NodoAlbero): React.ReactNode => (
    <li key={n.id} className={n.tipo ? classeArco(n.tipo) : undefined}>
      <Link className={`riga ${classeRamo(n.ramo)}`} href={`/${lang}/w/${n.slug}`}>
        <span className="lemma">{fmt(n)}</span>
        <span className="sigla">{n.lingua_sigla}</span>
        {n.tipo_etichetta && <span className="tp">{n.tipo_etichetta}</span>}
        {n.glossa && <span className="gl">{G(n.glossa, lang)}</span>}
      </Link>
      {n.figli.length > 0 && <ol>{n.figli.map(ramo)}</ol>}
    </li>
  );
  return <ol className="stemma-v" aria-label={TESTI[lang].stemmaDi(fmt(radice))}>{ramo(radice)}</ol>;
}
