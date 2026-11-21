// L'indirizzo pubblico del sito: per la mappa e per robots.txt. Con il dominio nuovo basta la variabile SITO_URL.
export const SITO = (process.env.SITO_URL ?? 'https://dizionario-etimologico.vercel.app').replace(/\/$/, '');
// Google accetta fino a 50 mila indirizzi per mappa
export const VOCI_PER_MAPPA = 40000;
// Le famiglie hanno blocchi loro (1…BLOCCHI_FAMIGLIE), per non superare i 20 MB di una pagina su Vercel: con 63 mila
// famiglie il blocco 0, che le conteneva tutte, pesava 20,03 MB (21 novembre 2026). Un blocco senza famiglie è vuoto.
export const BLOCCHI_FAMIGLIE = 4;
// quanti blocchi ha la mappa: 0 le pagine fisse e le lingue, poi le famiglie, poi le voci
export const blocchiMappa = (voci: number) => 1 + BLOCCHI_FAMIGLIE + Math.ceil(voci / VOCI_PER_MAPPA);
