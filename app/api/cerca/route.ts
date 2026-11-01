import type { NextRequest } from 'next/server';
import { cerca } from '@/lib/dati';
import { isLang } from '@/lib/i18n';

export async function GET(req: NextRequest) {
  const q = (req.nextUrl.searchParams.get('q') ?? '').slice(0, 80).trim();
  const l = req.nextUrl.searchParams.get('lang') ?? 'it';
  const lang = isLang(l) ? l : 'it';
  if (!q) return Response.json([]);
  const righe = await cerca(q, lang);
  return Response.json(righe, { headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=86400' } });
}
