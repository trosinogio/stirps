'use client';
import { useState, type ReactNode } from 'react';

// Il gioco: chi è parente di chi. Le opzioni arrivano già mescolate dal server; la spiegazione (le due catene fino
// alla radice comune) è già pronta e si mostra dopo la scelta.
export interface Opzione { slug: string; etichetta: string; sigla: string }

export default function Indovinello({ domanda, opzioni, giusta, spiegazione, testi, altro }: {
  domanda: ReactNode; opzioni: Opzione[]; giusta: string; spiegazione: ReactNode;
  testi: { esatto: string; sbagliato: string; altro: string; titolo: string }; altro: string;
}) {
  const [scelta, setScelta] = useState<string | null>(null);
  return (
    <section className="indovinello" aria-live="polite">
      <p className="storia-tipo">{testi.titolo}</p>
      <h3 className="storia-titolo">{domanda}</h3>
      <div className="indovinello-opzioni">
        {opzioni.map((o) => {
          const stato = scelta === null ? '' : o.slug === giusta ? 'giusta' : o.slug === scelta ? 'sbagliata' : 'spenta';
          return (
            <button key={o.slug} type="button" className={`opzione ${stato}`} disabled={scelta !== null}
              onClick={() => setScelta(o.slug)}>
              <i>{o.etichetta}</i> <span className="sigla">{o.sigla}</span>
            </button>
          );
        })}
      </div>
      {scelta !== null && (
        <div className="indovinello-esito">
          <div className="indovinello-spiegazione"><b>{scelta === giusta ? testi.esatto : testi.sbagliato}</b> {spiegazione}</div>
          <a className="btn" href={altro}>{testi.altro}</a>
        </div>
      )}
    </section>
  );
}
