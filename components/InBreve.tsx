import type { Testi } from '@/lib/i18n';
import type { Lang } from '@/lib/i18n';
import { datazione } from '@/lib/forme';
import { intercala, VoceLink } from '@/components/comuni';
import { nodiUnici } from '@/lib/forme';
import type { Scheda } from '@/lib/tipi';

// «In breve», come il riquadro riassuntivo dei grandi dizionari storici: l'origine (il primo passaggio e il suo etimo),
// il capostipite in cima alla catena, la prima attestazione, quante parole imparentate e in quante lingue. Tutto dai dati della
// scheda; il riquadro non compare se non ha almeno due righe.
export default function InBreve({ sc, t, lang }: { sc: Scheda; t: Testi; lang: Lang }) {
  // un composto ha più etimi al primo passo (girasole: girare + sole) e più capostipiti, uno per elemento
  const primi = nodiUnici(sc.catena.filter((n) => n.profondita === 1));
  const primo = primi[0];
  const conGenitori = new Set(sc.catena.map((n) => n.esito));
  const cime = nodiUnici(sc.catena.filter((n) => !conGenitori.has(n.id) && n.ricostruito));   // radici o parole ricostruite in cima
  const prima = [...sc.attestazioni].sort((a, b) => a.anno_da - b.anno_da)[0];
  const lingue = new Set(sc.cognati.map((c) => c.lingua)).size;
  const righe: [string, React.ReactNode][] = [];
  if (primo) righe.push([t.inBreve.origine, <>{primo.tipo_etichetta ?? primo.tipo} · {intercala(primi.map((n) => <VoceLink key={n.id} n={n} lang={lang} />), (i) => <span key={'p' + i}> + </span>)}</>]);
  const radici = cime.filter((c) => !primi.some((p) => p.id === c.id));
  if (radici.length) righe.push([radici.length > 1 ? t.inBreve.radici : t.inBreve.radice,
    <>{intercala(radici.map((c) => <VoceLink key={c.id} n={c} lang={lang} />), (i) => <span key={'r' + i}>, </span>)}</>]);
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
