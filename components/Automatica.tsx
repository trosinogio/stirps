import type { Lang } from '@/lib/i18n';

// Il segno delle glosse tradotte automaticamente: «≈», con la spiegazione al passaggio del mouse
const TITOLO: Record<Lang, string> = {
  it: 'Traduzione automatica della glossa inglese di Wiktionary, da verificare',
  en: 'Machine translation of Wiktionary’s English gloss, to be checked',
};
export default function Automatica({ lang }: { lang: Lang }) {
  return <abbr className="automatica" title={TITOLO[lang]} aria-label={TITOLO[lang]}>≈</abbr>;
}
