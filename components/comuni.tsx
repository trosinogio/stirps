import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import { TESTI } from '@/lib/i18n';
import { classeRamo, fmt, ORDINE_RAMI, ramoDi } from '@/lib/forme';
import type { Nodo } from '@/lib/tipi';

type NodoMinimo = Pick<Nodo, 'slug' | 'lemma' | 'ramo' | 'ricostruito' | 'lingua_sigla'>;

export function VoceLink({ n, lang, sigla = true, radice = false }: { n: NodoMinimo; lang: Lang; sigla?: boolean; radice?: boolean }) {
  return (
    <Link className={`voce ${classeRamo(n.ramo)}`} href={`/${lang}/${radice ? 'r' : 'w'}/${n.slug}`}>
      <span className="lemma">{fmt(n)}</span>
      {sigla && <span className="sigla">{n.lingua_sigla}</span>}
    </Link>
  );
}

export function BarraRami({ rami }: { rami: Record<string, number> }) {
  const voci = Object.entries(rami)
    .map(([r, n]) => [ramoDi(r), n] as const)
    .sort((a, b) => ORDINE_RAMI.indexOf(a[0]) - ORDINE_RAMI.indexOf(b[0]));
  return (
    <span className="barra" aria-hidden="true">
      {voci.map(([r, n]) => <span key={r} className={`r-${r}`} style={{ flex: `${n} 1 0` }} />)}
    </span>
  );
}

export function Fiducia({ n }: { n: number }) {
  return (
    <span className="fiducia" aria-hidden="true">
      {[1, 2, 3, 4].map((i) => <i key={i} className={i <= n ? 'on' : ''} />)}
    </span>
  );
}

export function Legenda({ lang }: { lang: Lang }) {
  const t = TESTI[lang].legenda;
  const tratti: [string, string][] = [['e-eredita', t.eredita], ['e-prestito', t.prestito], ['e-dotto', t.dotto], ['e-formazione', t.formazione], ['e-indeterminata', t.indeterminata]];
  return (
    <p className="legenda">
      {tratti.map(([c, testo]) => (
        <span key={c}>
          <svg width="30" height="8" aria-hidden="true"><path d="M1 4H29" className={`st-arco ${c}`} /></svg>
          {testo}
        </span>
      ))}
      <span>
        <svg width="12" height="12" aria-hidden="true"><circle cx="6" cy="6" r="4" className="leg-ric" /></svg>
        {t.ricostruita}
      </span>
    </p>
  );
}

export function intercala<T>(arr: T[], sep: (i: number) => React.ReactNode): React.ReactNode[] {
  return arr.flatMap((x, i) => (i ? [sep(i), x as React.ReactNode] : [x as React.ReactNode]));
}
