// Le parole di un testo, per l'analisi (analizza_testo()): sequenze di lettere, con l'apostrofo dell'elisione attaccato
// alla parola che lo precede (l', dell', po'), contate per forma in minuscolo
export const MAX_CARATTERI = 20000;
export const MAX_FORME = 5000;

export function contaForme(testo: string): { forme: string[]; conteggi: number[] } {
  const conta = new Map<string, number>();
  for (const m of testo.slice(0, MAX_CARATTERI).replace(/’/g, "'").matchAll(/\p{L}+'?/gu)) {
    const f = m[0].toLowerCase();
    conta.set(f, (conta.get(f) ?? 0) + 1);
  }
  const voci = [...conta.entries()].sort((a, b) => b[1] - a[1]).slice(0, MAX_FORME);
  return { forme: voci.map(([f]) => f), conteggi: voci.map(([, n]) => n) };
}
