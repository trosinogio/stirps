import type { MetadataRoute } from 'next';
import { contaVociMappa, radiciELingueMappa, vociMappa } from '@/lib/dati';
import { BLOCCHI_FAMIGLIE, SITO, VOCI_PER_MAPPA, blocchiMappa } from '@/lib/sito';

// Mappa del sito divisa in blocchi (/sitemap/0.xml, /sitemap/1.xml…): il blocco 0 ha le pagine fisse e le lingue, i
// blocchi da 1 a BLOCCHI_FAMIGLIE le famiglie, gli altri le voci, 40 mila per blocco (al massimo 20 MB per pagina).
// Ogni indirizzo italiano ha l'alternativa inglese. Elenco in robots.txt.
export const revalidate = 86400;

const PAGINE = ['', '/radici', '/lingue', '/storie', '/metodo', '/norme', '/chi-siamo', '/bibliografia'];

function voce(percorso: string, agg?: string): MetadataRoute.Sitemap[number] {
  return {
    url: `${SITO}/it${percorso}`,
    ...(agg ? { lastModified: agg } : {}),
    alternates: { languages: { it: `${SITO}/it${percorso}`, en: `${SITO}/en${percorso}` } },
  };
}

export async function generateSitemaps() {
  const n = await contaVociMappa();
  return Array.from({ length: blocchiMappa(n) }, (_, id) => ({ id }));
}

export default async function sitemap(props: { id: Promise<string> }): Promise<MetadataRoute.Sitemap> {
  const id = Number(await props.id);
  if (id <= BLOCCHI_FAMIGLIE) {
    const { radici, lingue } = await radiciELingueMappa();
    if (id === 0) return [...PAGINE.map((p) => voce(p)), ...lingue.map((c) => voce(`/l/${c}`))];
    return radici.slice((id - 1) * VOCI_PER_MAPPA, id * VOCI_PER_MAPPA).map((s) => voce(`/r/${s}`));
  }
  return (await vociMappa(id - 1 - BLOCCHI_FAMIGLIE, VOCI_PER_MAPPA)).map((v) => voce(`/w/${v.slug}`, v.agg));
}
