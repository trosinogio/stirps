import type { Metadata } from 'next';
import { notFound, redirect } from 'next/navigation';
import { isLang } from '@/lib/i18n';
import { TESTI_REDAZIONE } from '@/lib/testi-redazione';
import { redattoreCorrente } from '@/lib/auth/redattore';
import Accesso from '@/components/redazione/Accesso';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { robots: { index: false } };

export default async function PaginaAccesso({ params, searchParams }: { params: Promise<{ lang: string }>; searchParams: Promise<{ esito?: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  const { esito } = await searchParams;
  const t = TESTI_REDAZIONE[lang];
  const { redattore } = await redattoreCorrente();
  if (redattore) redirect(`/${lang}/redazione`);
  return (
    <article className="pagina-testo">
      <header className="testa-voce">
        <h1 className="voce-titolo">{t.accesso}</h1>
        <p className="pagina-intro">{t.accessoIntro}</p>
      </header>
      {esito && t.esiti[esito] && <p className="red-esito red-esito-errore" role="alert">{t.esiti[esito]}</p>}
      <Accesso lang={lang} />
    </article>
  );
}
