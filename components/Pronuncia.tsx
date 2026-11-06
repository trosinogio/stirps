import { TESTI, type Lang } from '@/lib/i18n';
import type { Pronuncia as DatiPronuncia } from '@/lib/tipi';

const COMMONS = 'https://commons.wikimedia.org/wiki/';

// La pronuncia nell'intestazione della voce, da Wiktionary: le trascrizioni IPA con la loro varietà, la sillabazione e
// l'audio di Wikimedia Commons (il file si ascolta da Commons, e il link porta alla sua pagina, con autore e licenza).
export default function Pronuncia({ pr, lang }: { pr: DatiPronuncia | null; lang: Lang }) {
  if (!pr || (!pr.ipa.length && !pr.sillabazione && !pr.audio)) return null;
  const t = TESTI[lang].pronuncia;
  return (
    <div className="pronuncia" role="group" aria-label={t.titolo}>
      {pr.ipa.length > 0 && (
        <ul className="ipa">
          {pr.ipa.map(([ipa, varieta]) => (
            <li key={ipa + varieta}>
              <span className="ipa-t" lang="und-fonipa">{ipa}</span>
              {varieta && <span className="ipa-v">{t.varieta(varieta)}</span>}
            </li>
          ))}
        </ul>
      )}
      {pr.sillabazione && <span className="sill">{t.sillabazione} {pr.sillabazione}</span>}
      {pr.audio && (
        <span className="audio">
          <audio controls preload="none" src={`${COMMONS}Special:FilePath/${encodeURIComponent(pr.audio)}`} aria-label={t.ascolta} />
          <a href={`${COMMONS}File:${encodeURIComponent(pr.audio)}`} target="_blank" rel="noopener">{t.audio}</a>
        </span>
      )}
    </div>
  );
}
