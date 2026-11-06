import type { Testi } from '@/lib/i18n';
import type { Lang } from '@/lib/i18n';
import { datazione } from '@/lib/forme';
import { VoceLink } from '@/components/comuni';
import type { Scheda } from '@/lib/tipi';

// «In breve», come il riquadro riassuntivo dei grandi dizionari storici: l'origine (il primo passaggio e il suo etimo),
// il capostipite in cima alla catena, la prima attestazione, quante parole imparentate e in quante lingue. Tutto dai dati della
// scheda; il riquadro non compare se non ha almeno due righe.
export default function InBreve({ sc, t, lang }: { sc: Scheda; t: Testi; lang: Lang }) {
  const primo = sc.catena.find((n) => n.profondita === 1);
  const cima = sc.catena.reduce<(typeof sc.catena)[number] | null>((m, n) => (!m || n.profondita > m.profondita ? n : m), null);
  const radice = cima && cima.ricostruito ? cima : null;                // il capostipite: una radice o una parola ricostruita
  const prima = [...sc.attestazioni].sort((a, b) => a.anno_da - b.anno_da)[0];
  const lingue = new Set(sc.cognati.map((c) => c.lingua)).size;
  const righe: [string, React.ReactNode][] = [];
  if (primo) righe.push([t.inBreve.origine, <>{primo.tipo_etichetta ?? primo.tipo} · <VoceLink n={primo} lang={lang} /></>]);
  if (radice && radice.id !== primo?.id) righe.push([t.inBreve.radice, <VoceLink n={radice} lang={lang} />]);
  if (prima) righe.push([t.inBreve.attestazione, prima.stima ? t.almenoDal(datazione(prima, t)) : datazione(prima, t)]);
  if (sc.cognati.length) righe.push([t.inBreve.parenti, t.inBreve.parentiN(sc.cognati.length, lingue)]);
  if (righe.length < 2) return null;
  return (
    <aside className="in-breve" aria-label={t.inBreve.titolo}>
      <h2>{t.inBreve.titolo}</h2>
      <dl>
        {righe.map(([k, v]) => (
          <div key={k}><dt>{k}</dt><dd>{v}</dd></div>
        ))}
      </dl>
    </aside>
  );
}
