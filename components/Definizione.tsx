import type { Lessema } from '@/lib/tipi';
import { TESTI, type Lang } from '@/lib/i18n';
import Automatica from '@/components/Automatica';

// La definizione della voce, sotto la glossa: della redazione, o scritta da Claude (segnata ≈ finché non è rivista).
// Le definizioni automatiche sono in italiano: sul sito inglese lo dichiara, come per le note.
export default function Definizione({ L, lang }: { L: Lessema; lang: Lang }) {
  if (!L.definizione) return null;
  const t = TESTI[lang];
  const altrove = L.definizione_lingua && L.definizione_lingua !== lang ? L.definizione_lingua : null;
  return (
    <p className="definizione" lang={altrove ?? undefined}>
      {L.definizione_automatica && <Automatica lang={lang} modello={L.definizione_modello ?? 'claude'} />}
      {L.definizione}
      {altrove && <span className="marca-lingua">({t.inLingua(t.nomiLingue[altrove] ?? altrove)})</span>}
    </p>
  );
}
