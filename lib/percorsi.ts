// Storie di parole per la pagina iniziale: catene vere del grafo, dall'antenato alla parola di oggi.
// Gli indirizzi sono verificati sul database; il link principale porta alla voce o alla radice.
// Nei testi _parola_ è una forma citata, in corsivo (l'asterisco resta alle forme ricostruite).
import type { Lang } from './i18n';

export interface Percorso {
  id: string;
  titolo: Record<Lang, string>;
  testo: Record<Lang, string>;
  catene: string[][];
  apri: string;            // percorso relativo: w/<slug> (voce) o r/<slug> (radice)
}

export const PERCORSI: Percorso[] = [
  {
    id: 'zero',
    titolo: { it: 'Zero e cifra', en: 'Zero and cipher' },
    testo: {
      it: 'L’arabo _ṣifr_, «vuoto», è entrato in italiano due volte: come numero e come segno.',
      en: 'The Arabic _ṣifr_, ‘empty’, entered Italian twice: as a number and as a sign.',
    },
    catene: [['ar/sfr', 'ar/sifr', 'la-med/zephirum', 'it/zefiro-2', 'it/zero'], ['ar/sifr', 'la-med/cifra', 'it/cifra']],
    apri: 'w/it/zero',
  },
  {
    id: 'burro',
    titolo: { it: 'Burro e butirro', en: 'Burro and butirro' },
    testo: {
      it: 'Lo stesso latino _butyrum_: diretto in _butirro_, passato dal francese antico in _burro_.',
      en: 'The same Latin _butyrum_: straight into _butirro_, and into _burro_ by way of Old French.',
    },
    catene: [['grc/bouturon', 'la/butyrum', 'it/butirro'], ['la/butyrum', 'fro/bure', 'it/burro']],
    apri: 'w/it/burro',
  },
  {
    id: 'notte',
    titolo: { it: 'Notte', en: 'Night' },
    testo: {
      it: 'La stessa parola indoeuropea, arrivata per eredità in dieci lingue: _notte_, _nuit_, _night_, _Nacht_, _νύξ_.',
      en: 'The same Indo-European word, inherited by ten languages: _notte_, _nuit_, _night_, _Nacht_, _νύξ_.',
    },
    catene: [['ine-pro/nokwts', 'la/nox', 'it/notte']],
    apri: 'r/ine-pro/nokwts',
  },
  {
    id: 'fegato',
    titolo: { it: 'Fegato', en: 'Liver' },
    testo: {
      it: 'Il latino _ficatum_ era il fegato d’oca ingrassato con i fichi, calco del greco _συκωτόν_: il nome del piatto ha preso il posto di quello dell’organo.',
      en: 'Latin _ficatum_ was goose liver fattened with figs, a calque of Greek _συκωτόν_: the name of the dish replaced the name of the organ.',
    },
    catene: [['la/ficus', 'la/ficatum', 'it/fegato'], ['grc/sykoton', 'la/ficatum']],
    apri: 'w/it/fegato',
  },
  {
    id: 'disastro',
    titolo: { it: 'Disastro', en: 'Disaster' },
    testo: {
      it: 'Una cattiva stella: _dis-_ e _astro_. Il francese l’ha preso come _désastre_, l’inglese come _disaster_.',
      en: 'An ill-starred word: _dis-_ plus _astro_. French took it as _désastre_, English as _disaster_.',
    },
    catene: [['la/astrum', 'it/astro', 'it/disastro'], ['it/disastro', 'fr/desastre', 'en/disaster']],
    apri: 'w/it/disastro',
  },
  {
    id: 'podio',
    titolo: { it: 'Podio e poggio', en: 'Podio and poggio' },
    testo: {
      it: 'Il latino _podium_ è arrivato due volte: per via dotta in _podio_, per via popolare in _poggio_.',
      en: 'Latin _podium_ arrived twice: through learned use as _podio_, through everyday speech as _poggio_.',
    },
    catene: [['la/podium', 'it/podio'], ['la/podium', 'it/poggio']],
    apri: 'w/it/podio',
  },
];

export const ESEMPI = ['it/notte', 'it/zero', 'it/burro', 'it/fegato', 'it/stella', 'it/piede'];

// Radici da mostrare per prime in testa alla pagina: la stessa parola ereditata in molte lingue
export const EROI = ['ine-pro/meh2ter', 'ine-pro/ped', 'ine-pro/nokwts', 'ine-pro/h2ster', 'ine-pro/gwem'];

// Il nome del progetto è una voce del dizionario: lat. stirps, da cui stirpe e sterpo
export const NOME = { voce: 'la/stirps', discendenti: ['it/stirpe', 'it/sterpo'] };

export const slugPercorsi = () => [...new Set([...PERCORSI.flatMap((p) => p.catene.flat()), ...ESEMPI, NOME.voce, ...NOME.discendenti])];
