'use client';
import { useState } from 'react';
import Link from 'next/link';
import { TESTI, type Lang } from '@/lib/i18n';
import { classeRamo, fmt, G } from '@/lib/forme';
import type { Nodo } from '@/lib/tipi';

export default function Eroe({ lang, eroi }: { lang: Lang; eroi: { radice: Nodo; riflessi: Nodo[] }[] }) {
  const [i, setI] = useState(0);
  const t = TESTI[lang];
  const e = eroi[i % eroi.length];
  const nl = new Set(e.riflessi.map((d) => d.lingua)).size;
  return (
    <section className="eroe" aria-label={t.eroeAria}>
      <Link className={`eroe-radice ${classeRamo(e.radice.ramo)}`} href={`/${lang}/r/${e.radice.slug}`}>
        <span className="lemma">{fmt(e.radice)}</span>
        <span className="sigla">{e.radice.lingua_nome}</span>
        {e.radice.glossa && <span className="gl">{G(e.radice.glossa, lang)}</span>}
      </Link>
      <ul className="riflessi" key={e.radice.id}>
        {e.riflessi.map((d, k) => (
          <li key={d.id} style={{ ['--i' as string]: k }}>
            <Link className={`riflesso ${classeRamo(d.ramo)}`} href={`/${lang}/w/${d.slug}`}>
              <span className="lemma">{d.lemma}</span>
              <span className="sigla">{d.lingua_nome}</span>
            </Link>
          </li>
        ))}
      </ul>
      <p className="didascalia">{t.eroeDidascalia(nl)}</p>
      <div className="azioni">
        <Link className="btn" href={`/${lang}/r/${e.radice.slug}`}>{t.apriStemma}</Link>
        {eroi.length > 1 && <button type="button" className="btn" onClick={() => setI(i + 1)}>{t.altraRadice}</button>}
      </div>
    </section>
  );
}
