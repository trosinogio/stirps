# Licenze

Stirps ha tre parti, e ognuna ha la sua licenza.

## Il codice

Il sito, il parser, gli script e i test (tutto tranne `dati/`) sono software libero con licenza **GNU Affero General
Public License, versione 3 o successiva** (AGPL-3.0-or-later): il testo è in [`LICENSE`](LICENSE).
Copyright © 2026 Giovanni Maria Trosino.

Chi usa, modifica o ridistribuisce il codice deve tenere la stessa licenza; chi mette in rete una versione modificata
deve rendere disponibile il suo codice a chi la usa. È la scelta coerente con i dati, che hanno già l'obbligo di
condividere allo stesso modo.

## I dati

Il pacchetto `dati/` (etimologie, voci, glosse, pronunce, frequenze) ha licenza **Creative Commons
Attribuzione – Condividi allo stesso modo 4.0 Internazionale** (CC BY-SA 4.0,
https://creativecommons.org/licenses/by-sa/4.0/deed.it), perché lo impongono le fonti da cui deriva:

| Fonte | Licenza | Che cosa ne viene |
|---|---|---|
| Wiktionary, Wikizionario, Wiktionnaire (Wikimedia Foundation), via Kaikki/wiktextract | CC BY-SA 4.0 | etimologie, voci, glosse, pronunce, alberi dei discendenti |
| Perseus Digital Library (http://www.perseus.tufts.edu/; github.com/PerseusDL/lexica) | CC BY-SA | lemmi, glosse ed etimologie del Lewis & Short e del Liddell–Scott–Jones |
| FrequencyWords di Hermit Dave (OpenSubtitles 2018) | CC BY-SA 4.0 | frequenze d'uso |
| Wikidata | CC0 | definizioni brevi |

Le glosse tradotte e le definizioni scritte in automatico a partire da quei dati sono opere derivate e hanno la stessa
licenza. Chi riusa i dati deve citare Stirps e le fonti, e condividere allo stesso modo. Il Perseus chiede inoltre che
ogni testo riusato sia identificato e collegato alla sua fonte, e che le correzioni gli siano offerte.

## I testi della redazione

Le note, le definizioni e le ipotesi scritte o riviste dalla redazione **non hanno ancora una licenza**: restano
riservate finché Giovanni non decide (è una delle questioni aperte delle norme redazionali). Nel database sono lo strato
«redazione», e non fanno parte del pacchetto `dati/`.
