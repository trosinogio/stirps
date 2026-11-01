import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import { classeRamo, fmt } from '@/lib/forme';
import type { Percorso } from '@/lib/percorsi';
import type { Nodo } from '@/lib/tipi';
import { Citazioni } from './Testo';

export function Parola({ n, lang }: { n?: Nodo; lang: Lang }) {
  if (!n) return null;
  return (
    <Link className={`voce ${classeRamo(n.ramo)}`} href={`/${lang}/w/${n.slug}`}>
      <span className="lemma">{fmt(n)}</span>
      <span className="sigla">{n.lingua_sigla}</span>
    </Link>
  );
}

// Storie di parole: titolo, testo, e le catene vere dall'antenato alla parola di oggi
export default function Storie({ percorsi, nodi, lang }: { percorsi: Percorso[]; nodi: Map<string, Nodo>; lang: Lang }) {
  return (
    <ul className="storie">
      {percorsi.map((p) => (
        <li key={p.id} className="percorso">
          <h3><Link href={`/${lang}/${p.apri}`}>{p.titolo[lang]}</Link></h3>
          <p><Citazioni testo={p.testo[lang]} /></p>
          {p.catene.map((c, i) => (
            <p key={i} className="catena-mini">
              {c.map((s, j) => (
                <span key={s} className="anello">
                  {j > 0 && <span className="maggiore" aria-hidden="true">&gt;</span>}
                  <Parola n={nodi.get(s)} lang={lang} />
                </span>
              ))}
            </p>
          ))}
        </li>
      ))}
    </ul>
  );
}
