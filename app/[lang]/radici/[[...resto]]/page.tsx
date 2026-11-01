import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { elencoRadici, PER_PAGINA } from '@/lib/dati';
import { classeRamo, fmt, G } from '@/lib/forme';

export const revalidate = 300;
export async function generateStaticParams() { return []; }

function leggi(resto: string[] | undefined) {
  const parti = resto ?? [];
  const provvisorie = parti[0] === 'provvisorie';
  const n = Number(provvisorie ? parti[1] : parti[0]);
  return { provvisorie, pagina: Number.isInteger(n) && n > 0 ? n : 1, valido: parti.length <= (provvisorie ? 2 : 1) };
}

export async function generateMetadata({ params }: { params: Promise<{ lang: string; resto?: string[] }> }): Promise<Metadata> {
  const { lang, resto } = await params;
  if (!isLang(lang)) return {};
  const t = TESTI[lang];
  return { title: leggi(resto).provvisorie ? t.capostipitiProvvisori : t.radici };
}

export default async function Radici({ params }: { params: Promise<{ lang: string; resto?: string[] }> }) {
  const { lang, resto } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const { provvisorie, pagina, valido } = leggi(resto);
  if (!valido) notFound();
  const el = await elencoRadici(lang, !provvisorie, pagina);
  const pagine = Math.max(1, Math.ceil(el.totale / PER_PAGINA));
  if (pagina > pagine) notFound();
  const base = `/${lang}/radici${provvisorie ? '/provvisorie' : ''}`;
  const href = (p: number) => (p === 1 ? base : `${base}/${p}`);
  return (
    <>
      <Link className="indietro" href={`/${lang}`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className="voce-titolo">{provvisorie ? t.capostipitiProvvisori : t.radici}</h1>
        <p className="nota-sez">{provvisorie ? t.capostipitiNota : t.radiciNota}</p>
      </header>
      <ul className="radici">
        {el.radici.map((r) => (
          <li key={r.id}>
            <Link className="rad-riga" href={`/${lang}/r/${r.slug}`}>
              <span className={`rad-nome ${classeRamo(r.ramo)}`}>
                <span className="lemma">{fmt(r)}</span>
                <span className="sigla">{r.lingua_sigla}</span>
                {r.glossa && <span className="gl">{G(r.glossa, lang)}</span>}
              </span>
              <span className="rad-conti">{t.paroleLingue(r.discendenti, r.lingue)}</span>
            </Link>
          </li>
        ))}
      </ul>
      {pagine > 1 && (
        <nav className="paginazione" aria-label={t.paginaDi(pagina, pagine)}>
          {pagina > 1 && <Link className="btn" href={href(pagina - 1)}>{t.precedenti}</Link>}
          <span>{t.paginaDi(pagina, pagine)}</span>
          {pagina < pagine && <Link className="btn" href={href(pagina + 1)}>{t.successive}</Link>}
        </nav>
      )}
    </>
  );
}
