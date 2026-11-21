import type { MetadataRoute } from 'next';
import { contaVociMappa } from '@/lib/dati';
import { SITO, blocchiMappa } from '@/lib/sito';

// robots.txt: tutto aperto salvo la redazione e le API; elenca i blocchi della mappa del sito (Next non fa l'indice)
export const revalidate = 86400;

export default async function robots(): Promise<MetadataRoute.Robots> {
  const n = await contaVociMappa();
  const blocchi = blocchiMappa(n);
  return {
    rules: { userAgent: '*', allow: '/', disallow: ['/it/redazione', '/en/redazione', '/api/'] },
    sitemap: Array.from({ length: blocchi }, (_, i) => `${SITO}/sitemap/${i}.xml`),
  };
}
