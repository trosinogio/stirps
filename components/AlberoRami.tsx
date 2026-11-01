import Link from 'next/link';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo } from '@/lib/forme';
import type { LinguaIndice } from '@/lib/tipi';

// Lo stemma delle lingue del dizionario: un ramo per riga, con le lingue più ricche. Non una parola:
// il disegno di tutto il progetto, negli stessi colori che il sito usa per i rami in ogni voce.
const RAMI = ['italica', 'ellenica', 'germanica', 'slava', 'indoiranica', 'semitica'];

export default function AlberoRami({ lang, lingue }: { lang: Lang; lingue: LinguaIndice[] }) {
  const t = TESTI[lang];
  const loc = lang === 'it' ? 'it-IT' : 'en-GB';
  const perRamo = RAMI.map((r) => {
    const ls = lingue.filter((l) => l.ramo === r).sort((a, b) => b.n - a.n);
    return { ramo: r, nome: ls[0]?.ramo_nome ?? r, lingue: ls };
  }).filter((x) => x.lingue.length);
  const altre = lingue.filter((l) => !RAMI.includes(l.ramo));
  return (
    <figure className="albero-rami" aria-label={t.ramiAria}>
      <div className="albero-radice" aria-hidden="true">√</div>
      <ul>
        {perRamo.map((x) => (
          <li key={x.ramo} className={classeRamo(x.ramo)}>
            <span className="albero-ramo">{x.nome}</span>
            <span className="albero-lingue">
              {x.lingue.slice(0, 3).map((l) => (
                <Link key={l.codice} href={`/${lang}/l/${l.codice}`}>{l.nome}<span>{l.n.toLocaleString(loc)}</span></Link>
              ))}
              {x.lingue.length > 3 && <span className="albero-piu">+{x.lingue.length - 3}</span>}
            </span>
          </li>
        ))}
        {altre.length > 0 && (
          <li className="r-proto">
            <span className="albero-ramo">{t.altreLingue}</span>
            <span className="albero-lingue">
              <Link href={`/${lang}/lingue`}>{lang === 'it' ? `${altre.length} lingue` : `${altre.length} languages`}</Link>
            </span>
          </li>
        )}
      </ul>
      <figcaption>{t.ramiNota(lingue.length)}</figcaption>
    </figure>
  );
}
