'use client';
import Link from 'next/link';
import { useState } from 'react';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo } from '@/lib/forme';
import { MAX_CARATTERI } from '@/lib/parole';
import type { AnalisiTesto as Analisi, EsempioAnalisi } from '@/lib/tipi';

const VIE = ['popolare', 'dotta', 'prestito', 'altro'] as const;
// il numero dell'omografo, come nel resto del sito: la² (la nota) accanto a la (l'articolo)
const omografo = (slug: string) => { const n = /-(\d+)$/.exec(slug)?.[1]; return n ? <sup>{n}</sup> : null; };

export default function AnalisiTesto({ lang }: { lang: Lang }) {
  const t = TESTI[lang].analisi;
  const [testo, setTesto] = useState('');
  const [ris, setRis] = useState<Analisi | null | undefined>(undefined);
  const [stato, setStato] = useState<'pronto' | 'in-corso' | 'errore'>('pronto');

  const analizza = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!testo.trim()) return;
    setStato('in-corso');
    try {
      const r = await fetch('/api/analizza', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ testo, lang }) });
      if (!r.ok) throw new Error(String(r.status));
      setRis((await r.json()) as Analisi | null);
      setStato('pronto');
    } catch {
      setStato('errore');
    }
  };

  const esempi = (xs: EsempioAnalisi[]) => xs.map((x, i) => (
    <span key={x.slug}>{i > 0 && ', '}<Link href={`/${lang}/w/${x.slug}`} prefetch={false}>{x.lemma}{omografo(x.slug)}</Link></span>
  ));
  const totale = ris ? ris.origini.reduce((s, o) => s + o.peso, 0) + ris.senza_origine.peso : 0;
  const pct = (x: number) => (totale ? (100 * x) / totale : 0);

  return (
    <div className="analisi">
      <form onSubmit={analizza}>
        <textarea value={testo} onChange={(e) => setTesto(e.target.value)} maxLength={MAX_CARATTERI} rows={10}
                  placeholder={t.segnaposto} aria-label={t.segnaposto} />
        <div className="analisi-azioni">
          <button type="submit" disabled={stato === 'in-corso' || !testo.trim()}>{stato === 'in-corso' ? t.inCorso : t.pulsante}</button>
          <span className="nota-sez">{t.limite(MAX_CARATTERI)}</span>
        </div>
      </form>
      {stato === 'errore' && <p className="nota-sez" role="alert">{t.errore}</p>}
      {ris === null && <p className="nota-sez">{t.vuoto}</p>}
      {ris && (
        <section className="analisi-esito" aria-live="polite">
          <p>{t.riepilogo(Math.round(ris.riconosciute), Math.round(ris.occorrenze), ris.lemmi)}</p>
          <ul className="analisi-origini">
            {ris.origini.map((o) => (
              <li key={o.codice} className={classeRamo(o.ramo ?? '')}>
                <div className="analisi-riga">
                  <span className="lingua-n">{o.nome}</span>
                  <span className="analisi-numeri">{pct(o.peso).toFixed(1)}% · {t.occorrenze(Math.round(o.peso))} · {t.lemmi(o.lemmi)}</span>
                </div>
                <div className="analisi-barra" style={{ width: `${Math.max(pct(o.peso), 0.5)}%` }}>
                  {VIE.filter((v) => o.vie[v] > 0).map((v) => (
                    <span key={v} className={`via-${v}`} style={{ flexGrow: o.vie[v] }} title={`${t.vie[v]}: ${Math.round(o.vie[v])}`} />
                  ))}
                </div>
                <p className="analisi-vie">{VIE.filter((v) => o.vie[v] > 0).map((v) => `${t.vie[v]} ${Math.round((100 * o.vie[v]) / o.peso)}%`).join(' · ')}</p>
                <p className="analisi-esempi">{esempi(o.esempi)}</p>
              </li>
            ))}
            {ris.senza_origine.lemmi > 0 && (
              <li>
                <div className="analisi-riga">
                  <span className="lingua-n">{t.senzaOrigine}</span>
                  <span className="analisi-numeri">{pct(ris.senza_origine.peso).toFixed(1)}% · {t.occorrenze(Math.round(ris.senza_origine.peso))} · {t.lemmi(ris.senza_origine.lemmi)}</span>
                </div>
                <p className="analisi-esempi">{esempi(ris.senza_origine.esempi)}</p>
              </li>
            )}
          </ul>
          {ris.sconosciute.length > 0 && (
            <p className="analisi-sconosciute"><strong>{t.sconosciute}:</strong> {ris.sconosciute.join(', ')}</p>
          )}
        </section>
      )}
      <p className="nota-sez analisi-metodo">{t.metodo}</p>
    </div>
  );
}
