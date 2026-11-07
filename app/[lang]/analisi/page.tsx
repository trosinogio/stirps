import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import AnalisiTesto from '@/components/AnalisiTesto';
import { isLang, TESTI } from '@/lib/i18n';

export async function generateStaticParams() { return []; }

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: TESTI[lang].analisi.titolo, description: TESTI[lang].analisi.intro } : {};
}

// La pagina è un guscio statico: l'analisi la chiede il componente a /api/analizza
export default async function Analisi({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang].analisi;
  return (
    <>
      <header className="testa-voce">
        <h1 className="voce-titolo">{t.titolo}</h1>
        <p className="nota-sez">{t.intro}</p>
      </header>
      <AnalisiTesto lang={lang} />
    </>
  );
}
