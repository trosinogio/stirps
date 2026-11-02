import { TESTI, type Lang } from '@/lib/i18n';

// Il segno dei testi automatici: «≈», con la spiegazione al passaggio del mouse. Senza modello è una glossa tradotta
// (OPUS-MT o Claude); con il modello è una definizione scritta da Claude, non ancora rivista.
export function nomeModello(m: string): string {
  const x = /^claude-([a-z]+)-(\d+)-(\d+)$/.exec(m);
  return x ? `Claude ${x[1][0].toUpperCase()}${x[1].slice(1)} ${x[2]}.${x[3]}` : m;
}

export default function Automatica({ lang, modello }: { lang: Lang; modello?: string | null }) {
  const t = TESTI[lang];
  const titolo = modello ? t.automaticaDefinizione(nomeModello(modello)) : t.automaticaGlossa;
  return <abbr className="automatica" title={titolo} aria-label={titolo}>≈</abbr>;
}
