// _parola_ nei testi: forma citata, in corsivo (l'asterisco resta alle forme ricostruite)
export function Citazioni({ testo }: { testo: string }) {
  return <>{testo.split(/(_[^_]+_)/).map((x, i) => (x.length > 2 && x.startsWith('_') && x.endsWith('_') ? <i key={i}>{x.slice(1, -1)}</i> : x))}</>;
}
