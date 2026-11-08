import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { isLang } from '@/lib/i18n';
import { NORME } from '@/lib/contenuti';
import PaginaTesto from '@/components/PaginaTesto';

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: NORME[lang].titolo } : {};
}

export default async function Norme({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  return <PaginaTesto pagina={NORME[lang]} lang={lang} />;
}
