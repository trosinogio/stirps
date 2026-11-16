import type { NextRequest } from 'next/server';
import { scheda } from '@/lib/dati';
import { nodiFamiglia } from '@/lib/albero';
import { isLang } from '@/lib/i18n';

// Le parole di una famiglia, per lo stemma che si apre sul posto e per «trova il percorso»: la pagina di una famiglia
// grande non le porta con sé (sarebbero centinaia di kilobyte), il browser le chiede solo quando il lettore cerca o apre
// un ramo.
export async function GET(req: NextRequest, { params }: { params: Promise<{ slug: string[] }> }) {
  const { slug } = await params;
  const l = req.nextUrl.searchParams.get('lang') ?? 'it';
  const lang = isLang(l) ? l : 'it';
  const sc = await scheda(slug.map(decodeURIComponent).join('/'), lang);
  if (!sc) return Response.json(null, { status: 404 });
  // le glosse accorciate e senza i campi vuoti: per *kap-² (3.929 parole) da 1.155 a 929 KB, 133 KB compressi
  const nodi = nodiFamiglia(sc).map((n) => Object.fromEntries(Object.entries({ ...n, glossa: n.glossa && n.glossa.length > 90 ? n.glossa.slice(0, 88) + '…' : n.glossa })
    .filter(([, v]) => v != null && v !== false)));
  return Response.json(nodi, { headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=86400' } });
}
