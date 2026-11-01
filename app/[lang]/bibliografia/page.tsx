import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { opere } from '@/lib/dati';
import type { Opera } from '@/lib/tipi';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

const AMBITI = ['italiano', 'romanzo', 'latino', 'greco', 'indoeuropeo', 'germanico', 'slavo', 'indoiranico', 'semitico', 'rete'];

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: TESTI[lang].bibliografia } : {};
}

function Citazione({ o }: { o: Opera }) {
  // Autore, Titolo, edizione, Editore, anno: lo stile delle bibliografie italiane, senza la città che l'archivio non registra
  const dopo = [o.edizione, o.editore, o.anno ? String(o.anno) : null].filter(Boolean).join(', ');
  return (
    <>
      {o.autore && <>{o.autore}, </>}
      <i>{o.titolo}</i>
      {dopo && <>, {dopo}</>}
      {o.nota && <span className="nota-opera">{o.nota}</span>}
    </>
  );
}

export default async function Bibliografia({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const tutte = await opere();
  return (
    <article className="pagina-testo bibliografia">
      <header className="testa-voce">
        <h1 className="voce-titolo">{t.bibliografia}</h1>
        <p className="pagina-intro">{t.bibliografiaIntro}</p>
      </header>
      {AMBITI.map((a) => {
        const qui = tutte.filter((o) => o.ambito === a);
        if (!qui.length) return null;
        return (
          <section key={a}>
            <h2>{t.ambiti[a] ?? a}</h2>
            <dl className="opere">
              {qui.map((o) => (
                <div key={o.sigla}>
                  <dt>{o.sigla}</dt>
                  <dd>
                    <Citazione o={o} />
                    <span className="segni">
                      {o.url && <a href={o.url} target="_blank" rel="noopener noreferrer">{t.inRete}</a>}
                      {o.pubblico_dominio && <span>{t.pubblicoDominio}</span>}
                      {o.modello_url && <span>{t.dalleVoci}</span>}
                    </span>
                  </dd>
                </div>
              ))}
            </dl>
          </section>
        );
      })}
    </article>
  );
}
