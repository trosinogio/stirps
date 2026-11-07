import type { NextRequest } from 'next/server';
import { analizzaTesto } from '@/lib/dati';
import { isLang } from '@/lib/i18n';
import { contaForme } from '@/lib/parole';

// L'analisi di un testo: riceve il testo, lo divide in forme e chiede al database le loro origini
export async function POST(req: NextRequest) {
  const corpo = (await req.json().catch(() => null)) as { testo?: unknown; lang?: unknown } | null;
  const testo = typeof corpo?.testo === 'string' ? corpo.testo : '';
  const lang = typeof corpo?.lang === 'string' && isLang(corpo.lang) ? corpo.lang : 'it';
  const { forme, conteggi } = contaForme(testo);
  if (!forme.length) return Response.json(null);
  return Response.json(await analizzaTesto(forme, conteggi, lang));
}
