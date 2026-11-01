// Testi della pagina delle storie
import type { Lang } from './i18n';

export const TESTI_STORIE: Record<Lang, {
  intro: string; oggi: string; oggiNota: string; altre: string; altreNota: string; rimescola: string; tutte: string;
  gioco: string; domanda: string; esatto: string; sbagliato: string; altroGioco: string; spiegazione: string;
  redazione: string; redazioneNota: string; vuoto: string;
}> = {
  it: {
    intro: 'Ogni parola ha una storia. Alcune le racconta la redazione; molte altre le trova il dizionario stesso, seguendo le sue catene: a ogni visita ne escono di nuove.',
    oggi: 'La storia di oggi',
    oggiNota: 'Cambia ogni giorno a mezzanotte, e ogni giorno di un tipo diverso.',
    altre: 'Altre storie',
    altreNota: 'Composte dalle catene del dizionario, tra le parole che usiamo ogni giorno: ogni parola rimanda alla sua voce.',
    rimescola: 'Altre storie ↻',
    tutte: 'Tutte',
    gioco: 'Gioco',
    domanda: 'Chi è parente di',
    esatto: 'Esatto!',
    sbagliato: 'No:',
    altroGioco: 'Un altro indovinello',
    spiegazione: 'risalgono entrambe alla radice indoeuropea',
    redazione: 'Le storie della redazione',
    redazioneNota: 'Scritte a mano, con le catene vere del dizionario.',
    vuoto: 'Nessuna storia di questo tipo, per ora.',
  },
  en: {
    intro: 'Every word has a story. Some are told by the editors; many more are found by the dictionary itself, following its chains: every visit brings new ones.',
    oggi: 'Today’s story',
    oggiNota: 'It changes every day at midnight, and each day it is a different kind.',
    altre: 'More stories',
    altreNota: 'Composed from the dictionary’s chains, among the words we use every day: every word links to its entry.',
    rimescola: 'More stories ↻',
    tutte: 'All',
    gioco: 'Game',
    domanda: 'Which word is related to',
    esatto: 'Right!',
    sbagliato: 'No:',
    altroGioco: 'Another riddle',
    spiegazione: 'both go back to the Indo-European root',
    redazione: 'Stories by the editors',
    redazioneNota: 'Written by hand, with the dictionary’s real chains.',
    vuoto: 'No stories of this kind yet.',
  },
};
