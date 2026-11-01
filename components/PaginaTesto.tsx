import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import type { Pagina } from '@/lib/contenuti';
import { Legenda } from './comuni';
import { Citazioni } from './Testo';

// Una pagina di testo (Metodo, Chi siamo): titolo, introduzione, sezioni
export default function PaginaTesto({ pagina, lang }: { pagina: Pagina; lang: Lang }) {
  return (
    <article className="pagina-testo">
      <header className="testa-voce">
        <h1 className="voce-titolo">{pagina.titolo}</h1>
        <p className="pagina-intro"><Citazioni testo={pagina.intro} /></p>
      </header>
      {pagina.sezioni.map((s) => (
        <section key={s.titolo}>
          <h2>{s.titolo}</h2>
          {s.testo.map((x, i) => <p key={i}><Citazioni testo={x} /></p>)}
          {s.legenda && <Legenda lang={lang} />}
          {s.collegamento && <p className="altre"><Link className="btn" href={`/${lang}/${s.collegamento[1]}`}>{s.collegamento[0]}</Link></p>}
          {s.tipi && (
            <dl className="tipi">
              {s.tipi.map(([k, v]) => (<div key={k}><dt>{k}</dt><dd><Citazioni testo={v} /></dd></div>))}
            </dl>
          )}
        </section>
      ))}
    </article>
  );
}
