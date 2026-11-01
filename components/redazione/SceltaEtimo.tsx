'use client';
import { useEffect, useState } from 'react';
import type { Lang } from '@/lib/i18n';
import type { EtichetteEtimo } from '@/lib/testi-redazione';

interface Trovato { slug: string; voce: { lemma: string; lingua_sigla: string; lingua_nome?: string; glossa?: string | null; ricostruito?: boolean } }

// L'etimo di un passaggio: si cerca tra le voci mentre si scrive, oppure si crea una voce nuova
export default function SceltaEtimo({ lang, lingue, t }: { lang: Lang; lingue: { codice: string; nome: string }[]; t: EtichetteEtimo }) {
  const [q, setQ] = useState('');
  const [ris, setRis] = useState<Trovato[]>([]);
  const [scelto, setScelto] = useState<Trovato | null>(null);
  const [nuovo, setNuovo] = useState(false);
  useEffect(() => {
    if (q.trim().length < 2) { setRis([]); return; }
    const ctl = new AbortController();
    const id = setTimeout(async () => {
      try {
        const r = await fetch(`/api/cerca?lang=${lang}&q=${encodeURIComponent(q.trim())}`, { signal: ctl.signal });
        setRis(await r.json());
      } catch { /* richiesta annullata */ }
    }, 180);
    return () => { clearTimeout(id); ctl.abort(); };
  }, [q, lang]);

  if (nuovo) {
    return (
      <fieldset className="scelta-etimo">
        <label>{t.lingua}
          <select name="nuova_lingua" required defaultValue="la">
            {lingue.map((l) => <option key={l.codice} value={l.codice}>{l.nome} ({l.codice})</option>)}
          </select>
        </label>
        <label>{t.lemma}<input name="nuovo_lemma" required /></label>
        <label className="riga"><input type="checkbox" name="nuovo_ricostruito" /> {t.ricostruita}</label>
        <label>{t.glossa}<input name="nuova_glossa" /></label>
        <button type="button" className="collegamento" onClick={() => setNuovo(false)}>{t.cercaTraLeVoci}</button>
      </fieldset>
    );
  }
  return (
    <fieldset className="scelta-etimo">
      <input type="hidden" name="etimo" value={scelto?.slug ?? ''} />
      {scelto ? (
        <p className="scelto">
          <span className="lemma">{scelto.voce.ricostruito ? '*' : ''}{scelto.voce.lemma}</span> <span className="sigla">{scelto.voce.lingua_sigla}</span>
          {scelto.voce.glossa && <span className="gl"> {scelto.voce.glossa}</span>}
          <button type="button" className="collegamento" onClick={() => setScelto(null)}>{t.cambia}</button>
        </p>
      ) : (
        <>
          <label>{t.cercaEtimo}<input value={q} onChange={(e) => setQ(e.target.value)} autoComplete="off" /></label>
          {ris.length > 0 && (
            <ul className="trovati">
              {ris.slice(0, 8).map((r) => (
                <li key={r.slug}>
                  <button type="button" onClick={() => { setScelto(r); setRis([]); }}>
                    <span className="lemma">{r.voce.ricostruito ? '*' : ''}{r.voce.lemma}</span> <span className="sigla">{r.voce.lingua_sigla}</span>
                    {r.voce.glossa && <span className="gl"> {r.voce.glossa}</span>}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
      <button type="button" className="collegamento" onClick={() => setNuovo(true)}>{t.nuovaVoceEtimo}</button>
    </fieldset>
  );
}
