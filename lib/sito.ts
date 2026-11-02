// L'indirizzo pubblico del sito: per la mappa e per robots.txt. Con il dominio nuovo basta la variabile SITO_URL.
export const SITO = (process.env.SITO_URL ?? 'https://dizionario-etimologico.vercel.app').replace(/\/$/, '');
// Google accetta fino a 50 mila indirizzi per mappa
export const VOCI_PER_MAPPA = 40000;
