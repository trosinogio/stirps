'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo, fmt, G } from '@/lib/forme';
import type { RisultatoRicerca } from '@/lib/tipi';

export default function Ricerca({ lang, grande = false, base }: { lang: Lang; grande?: boolean; base?: string }) {
  const id = grande ? 'q-grande' : 'q';
  const t = TESTI[lang];
  const router = useRouter();
  const [q, setQ] = useState('');
  const [ris, setRis] = useState<RisultatoRicerca[] | null>(null);
  const [att, setAtt] = useState(0);
  const [aperto, setAperto] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const v = q.trim();
    if (!v) { setRis(null); return; }
    const ctrl = new AbortController();
    const id = setTimeout(() => {
      fetch(`/api/cerca?lang=${lang}&q=${encodeURIComponent(v)}`, { signal: ctrl.signal })
        .then((r) => r.json())
        .then((d: RisultatoRicerca[]) => { setRis(d); setAtt(0); })
        .catch(() => {});
    }, 140);
    return () => { clearTimeout(id); ctrl.abort(); };
  }, [q, lang]);

  useEffect(() => {
    const fuori = (e: MouseEvent) => { if (box.current && !box.current.contains(e.target as Node)) setAperto(false); };
    document.addEventListener('click', fuori);
    return () => document.removeEventListener('click', fuori);
  }, []);

  const scegli = (r: RisultatoRicerca) => { setAperto(false); setQ(''); router.push(`${base ?? `/${lang}/w/`}${r.slug}`); };
  const mostra = aperto && q.trim() !== '' && ris !== null;

  return (
    <div className={grande ? 'cerca cerca-grande' : 'cerca'} ref={box}>
      <label htmlFor={id} className="sr">{t.cercaEtichetta}</label>
      <input
        id={id} className="cerca-campo" type="search" value={q} placeholder={grande ? t.cercaGrande : t.cercaSegnaposto}
        autoComplete="off" autoCapitalize="off" spellCheck={false}
        role="combobox" aria-expanded={mostra} aria-controls={`${id}-risultati`} aria-autocomplete="list"
        aria-activedescendant={mostra && ris && ris.length ? `${id}-ris-${att}` : undefined}
        onChange={(e) => { setQ(e.target.value); setAperto(true); }}
        onFocus={() => { if (q.trim()) setAperto(true); }}
        onKeyDown={(e) => {
          const n = ris?.length ?? 0;
          if (e.key === 'ArrowDown') { e.preventDefault(); if (n) setAtt((a) => (a + 1) % n); }
          else if (e.key === 'ArrowUp') { e.preventDefault(); if (n) setAtt((a) => (a - 1 + n) % n); }
          else if (e.key === 'Enter') { e.preventDefault(); if (ris && ris[att]) scegli(ris[att]); }
          else if (e.key === 'Escape') setAperto(false);
        }}
      />
      {mostra && (
        <ul id={`${id}-risultati`} className="cerca-risultati" role="listbox">
          {ris!.length ? ris!.map((r, i) => (
            <li key={r.slug} id={`${id}-ris-${i}`} role="option" aria-selected={i === att} className={classeRamo(r.voce.ramo)} onClick={() => scegli(r)}>
              <span className="lemma">{fmt(r.voce)}</span>
              <span className="ris-info">
                <span className="sigla">{r.voce.lingua_nome}</span>
                {r.voce.translit ? ' ' + r.voce.translit : ''}
                {r.voce.glossa ? ', ' + G(r.voce.glossa, lang) : ''}
                {r.per_significato && <span className="ris-sig">{t.perSignificato}</span>}
              </span>
            </li>
          )) : <li className="nessuno" role="option" aria-selected={false} aria-disabled="true">{t.nessunRisultato}</li>}
        </ul>
      )}
    </div>
  );
}
