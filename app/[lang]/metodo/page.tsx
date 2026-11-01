import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { isLang } from '@/lib/i18n';
import { METODO } from '@/lib/contenuti';
import PaginaTesto from '@/components/PaginaTesto';

export async function generateMetadata({ params }: { params: Promise<{ lang: string }> }): Promise<Metadata> {
  const { lang } = await params;
  return isLang(lang) ? { title: METODO[lang].titolo } : {};
}

export default async function Metodo({ params }: { params: Promise<{ lang: string }> }) {
  const { lang } = await params;
  if (!isLang(lang)) notFound();
  return <PaginaTesto pagina={METODO[lang]} lang={lang} />;
}
