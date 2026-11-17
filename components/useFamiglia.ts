'use client';
import { useCallback, useState } from 'react';
import type { Lang } from '@/lib/i18n';
import type { NodoPiatto } from '@/lib/tipi';

// Le parole di una famiglia, chieste a /api/famiglia una volta sola e solo quando servono (il lettore cerca un percorso o
// apre un ramo di una famiglia grande). Se la pagina le ha già (famiglia piccola), non si chiede niente.
const memoria = new Map<string, Promise<NodoPiatto[] | null>>();

export function useFamiglia(lang: Lang, slug: string, iniziali?: NodoPiatto[] | null) {
  const [nodi, setNodi] = useState<NodoPiatto[] | null>(iniziali ?? null);
  const [stato, setStato] = useState<'fermo' | 'carica' | 'pronto' | 'errore'>(iniziali ? 'pronto' : 'fermo');
  const carica = useCallback(() => {
    if (stato !== 'fermo') return;
    setStato('carica');
    const k = `${lang}/${slug}`;
    if (!memoria.has(k)) {
      memoria.set(k, fetch(`/api/famiglia/${slug}?lang=${lang}`).then((r) => (r.ok ? r.json() : null)).catch(() => null));
    }
    memoria.get(k)!.then((d) => {
      if (d) { setNodi(d); setStato('pronto'); } else { memoria.delete(k); setStato('errore'); }
    });
  }, [lang, slug, stato]);
  return { nodi, stato, carica };
}
