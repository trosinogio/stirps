import type { MetadataRoute } from 'next';
import { contaVociMappa, radiciELingueMappa, vociMappa } from '@/lib/dati';
import { SITO, VOCI_PER_MAPPA } from '@/lib/sito';

// Mappa del sito divisa in blocchi (/sitemap/0.xml, /sitemap/1.xml…): il blocco 0 ha le pagine fisse, le famiglie e le
// lingue; gli altri le voci, 40 mila per blocco. Ogni indirizzo italiano ha l'alternativa inglese. Elenco in robots.txt.
export const revalidate = 86400;

const PAGINE = ['', '/radici', '/lingue', '/storie', '/metodo', '/chi-siamo', '/bibliografia'];

function voce(percorso: string, agg?: string): MetadataRoute.Sitemap[number] {
  return {
    url: `${SITO}/it${percorso}`,
    ...(agg ? { lastModified: agg } : {}),
    alternates: { languages: { it: `${SITO}/it${percorso}`, en: `${SITO}/en${percorso}` } },
  };
}

export async function generateSitemaps() {
  const n = await contaVociMappa();
  return Array.from({ length: 1 + Math.ceil(n / VOCI_PER_MAPPA) }, (_, id) => ({ id }));
}

export default async function sitemap(props: { id: Promise<string> }): Promise<MetadataRoute.Sitemap> {
  const id = Number(await props.id);
  if (id === 0) {
    const { radici, lingue } = await radiciELingueMappa();
    return [...PAGINE.map((p) => voce(p)), ...lingue.map((c) => voce(`/l/${c}`)), ...radici.map((s) => voce(`/r/${s}`))];
  }
  return (await vociMappa(id - 1, VOCI_PER_MAPPA)).map((v) => voce(`/w/${v.slug}`, v.agg));
}
