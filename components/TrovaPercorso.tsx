'use client';
import Link from 'next/link';
import { useMemo, useRef, useState } from 'react';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo, fmt, G } from '@/lib/forme';
import type { NodoPiatto } from '@/lib/tipi';
import { useFamiglia } from '@/components/useFamiglia';

const piano = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').replace(/^\*/, '').toLowerCase();

// Trova il percorso: una parola della famiglia e la sua catena dalla radice, un passaggio per riga. Le parole della
// famiglia arrivano solo quando il lettore comincia a scrivere (useFamiglia), così la pagina resta leggera.
export default function TrovaPercorso({ lang, slug, nodi: dati }: { lang: Lang; slug: string; nodi?: NodoPiatto[] | null }) {
  const t = TESTI[lang].percorso;
  const [q, setQ] = useState('');
  const [scelta, setScelta] = useState<number | null>(null);
  const [sel, setSel] = useState(0);
  const { nodi, stato, carica } = useFamiglia(lang, slug, dati);
  const lista = useRef<HTMLUListElement>(null);

  const perId = useMemo(() => new Map((nodi ?? []).map((n) => [n.id, n])), [nodi]);
  const figli = useMemo(() => {
    const m = new Map<number, number>();
    for (const n of nodi ?? []) if (n.padre != null) m.set(n.padre, (m.get(n.padre) ?? 0) + 1);
    return m;
  }, [nodi]);
  const trovate = useMemo(() => {
    const c = piano(q.trim());
    if (!c || !nodi) return [];
    const punta = (n: NodoPiatto) => {
      const l = piano(n.lemma);
      return l === c ? 0 : l.startsWith(c) ? 1 : l.includes(c) ? 2 : piano(n.glossa ?? '').includes(c) ? 3 : 9;
    };
    return nodi.slice(1).map((n) => [punta(n), n] as const).filter(([p]) => p < 9)
      .sort((a, b) => a[0] - b[0] || +(b[1].lingua === lang) - +(a[1].lingua === lang) || a[1].lemma.length - b[1].lemma.length)
      .slice(0, 12).map(([, n]) => n);
  }, [q, nodi, lang]);

  const percorso = useMemo(() => {
    if (scelta == null) return [];
    const out: NodoPiatto[] = [];
    const visti = new Set<number>();
    for (let n = perId.get(scelta); n && !visti.has(n.id); n = n.padre != null ? perId.get(n.padre) : undefined) {
      visti.add(n.id);
      out.push(n);
    }
    return out.reverse();
  }, [scelta, perId]);

  const scegli = (n: NodoPiatto) => { setScelta(n.id); setQ(''); };
  return (
    <section className="percorso" aria-label={t.titolo}>
      <div className="percorso-campo">
        <input type="search" className="st-cerca" placeholder={t.cerca} aria-label={t.cerca} value={q}
          aria-expanded={trovate.length > 0} aria-controls="percorso-trovate" autoComplete="off"
          onFocus={carica} onChange={(e) => { carica(); setQ(e.target.value); setSel(0); }}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown') { e.preventDefault(); setSel((s) => Math.min(s + 1, trovate.length - 1)); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); setSel((s) => Math.max(s - 1, 0)); }
            else if (e.key === 'Enter' && trovate[sel]) { e.preventDefault(); scegli(trovate[sel]); }
            else if (e.key === 'Escape') setQ('');
          }} />
        {stato === 'carica' && q && <span className="st-conta">{t.carica}</span>}
        {stato === 'pronto' && q.trim() && !trovate.length && <span className="st-conta">{t.nessuna}</span>}
      </div>
      {trovate.length > 0 && (
        <ul className="percorso-trovate" id="percorso-trovate" role="listbox" ref={lista}>
          {trovate.map((n, i) => (
            <li key={n.id} role="option" aria-selected={i === sel} className={classeRamo(n.ramo)}
              onMouseDown={(e) => { e.preventDefault(); scegli(n); }} onMouseEnter={() => setSel(i)}>
              <span className="lemma">{fmt(n)}</span> <span className="sigla">{n.lingua_sigla}</span>
              {n.glossa && <span className="gl"> {G(n.glossa, lang)}</span>}
            </li>
          ))}
        </ul>
      )}
      {percorso.length > 0 && (
        <div className="percorso-esito">
          <p className="percorso-titolo">
            {t.dallaRadice(fmt(percorso[0]), fmt(percorso[percorso.length - 1]), percorso.length - 1)}
            <button type="button" className="btn-chip" onClick={() => setScelta(null)}>{t.chiudi}</button>
          </p>
          <ol className="percorso-catena">
            {percorso.map((n, i) => (
              <li key={n.id} className={`${classeRamo(n.ramo)}${i === percorso.length - 1 ? ' arrivo' : ''}`}>
                {i > 0 && (
                  <span className="passo">{n.dubbio && <abbr className="dub" title={TESTI[lang].legameDubbio}>?</abbr>}{n.tipo_etichetta ?? '↓'}</span>
                )}
                <span className="nodo">
                  <Link className="voce" href={`/${lang}/w/${n.slug}`} prefetch={false}><span className="lemma">{fmt(n)}</span></Link>
                  <span className="sigla">{n.lingua_nome}</span>
                  {n.glossa && <span className="gl">{G(n.glossa, lang)}</span>}
                  {i > 0 && (figli.get(n.id) ?? 0) > 0 && (
                    <Link className="quanti" href={`/${lang}/r/${n.slug}/stemma`} prefetch={false}>{t.apriRamo(figli.get(n.id)!)}</Link>
                  )}
                </span>
              </li>
            ))}
          </ol>
        </div>
      )}
    </section>
  );
}
