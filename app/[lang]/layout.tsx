import type { Metadata, Viewport } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Atkinson_Hyperlegible, Gentium_Book_Plus } from 'next/font/google';
import { isLang, TESTI } from '@/lib/i18n';
import { ANTEPRIMA } from '@/lib/dati';
import Ricerca from '@/components/Ricerca';
import CambiaLingua from '@/components/CambiaLingua';
import Marchio from '@/components/Marchio';
import Navigazione from '@/components/Navigazione';
import '../globals.css';

const serif = Gentium_Book_Plus({
  subsets: ['latin', 'latin-ext', 'greek', 'greek-ext', 'cyrillic', 'cyrillic-ext'],
  weight: ['400', '700'], style: ['normal', 'italic'], variable: '--font-serif', display: 'swap',
});
const sans = Atkinson_Hyperlegible({
  subsets: ['latin', 'latin-ext'], weight: ['400', '700'], style: ['normal', 'italic'], variable: '--font-sans', display: 'swap',
});

export const viewport: Viewport = { width: 'device-width', initialScale: 1, viewportFit: 'cover' };

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  if (!isLang(lang)) return {};
  const t = TESTI[lang];
  return { title: { default: t.titolo, template: `%s | ${t.titolo}` }, description: t.descrizioneSito };
}

export default async function Layout({ children, params }: { children: React.ReactNode; params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  return (
    <html lang={lang} className={`${serif.variable} ${sans.variable}`}>
      <body>
        <header className="testata">
          <div className="testata-in">
            <Link className="marchio" href={`/${lang}`} aria-label={t.tornaIndice}>
              <Marchio nome={t.titolo} />
            </Link>
            <Navigazione lang={lang} />
            <Ricerca lang={lang} />
            <CambiaLingua lang={lang} />
          </div>
        </header>
        <main id="app">{children}</main>
        <footer className="piede">
          <div className="piede-in">
            <div className="piede-marchio">
              <Marchio nome={t.titolo} />
              <p>{t.sottotitolo}</p>
            </div>
            <nav aria-label={t.piede.esplora}>
              <h2>{t.piede.esplora}</h2>
              <Link href={`/${lang}/radici`}>{t.nav.radici}</Link>
              <Link href={`/${lang}/lingue`}>{t.nav.lingue}</Link>
              <Link href={`/${lang}/storie`}>{t.nav.storie}</Link>
              <Link href={`/${lang}/analisi`}>{t.nav.analisi}</Link>
            </nav>
            <nav aria-label={t.piede.progetto}>
              <h2>{t.piede.progetto}</h2>
              <Link href={`/${lang}/metodo`}>{t.nav.metodo}</Link>
              <Link href={`/${lang}/norme`}>{t.nav.norme}</Link>
              <Link href={`/${lang}/bibliografia`}>{t.bibliografia}</Link>
              <Link href={`/${lang}/chi-siamo`}>{t.nav.chiSiamo}</Link>
              <Link href={`/${lang}/redazione`}>{lang === 'it' ? 'Redazione' : 'Editorial'}</Link>
            </nav>
            <div>
              <h2>{t.piede.dati}</h2>
              <p>{t.piede.datiTesto}</p>
            </div>
          </div>
          <p className="piede-nota">{t.piede.prototipo}{ANTEPRIMA ? ` ${t.anteprima}` : ''}</p>
        </footer>
      </body>
    </html>
  );
}
