import Link from 'next/link';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo } from '@/lib/forme';
import { alberoLingue, tutte } from '@/lib/albero-lingue';
import type { LinguaIndice } from '@/lib/tipi';

// Lo stemma delle lingue del dizionario: i rami indoeuropei, poi le altre famiglie più ricche, ciascuno con le sue lingue
// più ricche; il resto nella pagina delle lingue, che ha l'albero intero. Negli stessi colori che il sito usa per i rami.
const RAMI_MOSTRATI = 7;
const FAMIGLIE_MOSTRATE = 5;

function Riga({ nome, classe, lingue, lang }: { nome: string; classe: string; lingue: LinguaIndice[]; lang: Lang }) {
  const loc = lang === 'it' ? 'it-IT' : 'en-GB';
  const ls = [...lingue].sort((a, b) => b.n - a.n);
  return (
    <li className={classe}>
      <span className="albero-ramo">{nome}</span>
      <span className="albero-lingue">
        {ls.slice(0, 3).map((l) => (
          <Link key={l.codice} href={`/${lang}/l/${l.codice}`} prefetch={false}>{l.nome}<span>{l.n.toLocaleString(loc)}</span></Link>
        ))}
        {ls.length > 3 && <span className="albero-piu">+{ls.length - 3}</span>}
      </span>
    </li>
  );
}

export default function AlberoRami({ lang, lingue }: { lang: Lang; lingue: LinguaIndice[] }) {
  const t = TESTI[lang];
  const famiglie = alberoLingue(lingue);
  const ie = famiglie.find((f) => f.famiglia === 'indoeuropea');
  const altre = famiglie.filter((f) => f !== ie && f.famiglia && f.famiglia !== 'translingue');
  const restanti = altre.slice(FAMIGLIE_MOSTRATE);
  const maiuscola = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
  return (
    <figure className="albero-rami" aria-label={t.ramiAria}>
      <div className="albero-radice" aria-hidden="true">√</div>
      {ie && (
        <>
          <p className="albero-famiglia">{t.alberoL.indoeuropee}</p>
          <ul>
            {ie.rami.slice(0, RAMI_MOSTRATI).map((r) => (
              <Riga key={r.ramo} nome={maiuscola(r.nome)} classe={classeRamo(r.ramo)} lingue={tutte(r.radici)} lang={lang} />
            ))}
          </ul>
        </>
      )}
      <p className="albero-famiglia">{t.alberoL.altreFamiglie}</p>
      <ul>
        {altre.slice(0, FAMIGLIE_MOSTRATE).map((f) => (
          <Riga key={f.famiglia} nome={maiuscola(f.nome)} classe={classeRamo(f.rami[0]?.ramo ?? 'proto')}
                lingue={[...tutte(f.capo), ...f.rami.flatMap((r) => tutte(r.radici))]} lang={lang} />
        ))}
        {restanti.length > 0 && (
          <li className="r-proto">
            <span className="albero-ramo">
              <Link href={`/${lang}/lingue`}>{t.alberoL.altreFamiglieN(restanti.length, restanti.reduce((s, f) => s + f.lingue, 0))}</Link>
            </span>
          </li>
        )}
      </ul>
      <figcaption>{t.ramiNota(lingue.length)}</figcaption>
    </figure>
  );
}
