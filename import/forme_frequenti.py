#!/usr/bin/env python3
"""Le forme flesse italiane più frequenti e i loro lemmi, per l'analisi di un testo (dati/forme_it.tsv.gz, tabella
forma_lemma, analizza_testo()): andava → andare, occhi → occhio, era → essere.

Le forme sono quelle del lessico di frequenza (dati/frequenze_it.tsv.gz, 50 mila), i lemmi vengono dalle forme flesse
di Wiktionary (forme.tsv di filtra.py, con FORME) e devono essere voci del dizionario. Una forma che è anche un lemma
(era, porta) non ha bisogno di una riga per sé: l'analisi prova sempre anche la forma stessa.

    python3 forme_frequenti.py ../dati/frequenze_it.tsv.gz dati/it/forme.tsv dati/it/tsv/lessemi.tsv > forme_it.tsv
"""
import gzip, sys
from collections import defaultdict


def main():
    frequenze, forme, lessemi = sys.argv[1:4]
    voci = set()
    with open(lessemi, encoding='utf-8') as f:
        for r in f:
            c = r.rstrip('\n').split('\t')
            if len(c) > 4 and c[1] == 'it' and c[4] != 't':
                voci.add(c[2])
    lemmi = defaultdict(set)
    with open(forme, encoding='utf-8') as f:
        for r in f:
            c = r.rstrip('\n').split('\t')
            if len(c) >= 2 and c[1] in voci and c[0].lower() != c[1].lower():
                lemmi[c[0].lower()].add(c[1])
    righe = 0
    with gzip.open(frequenze, 'rt', encoding='utf-8') as f:
        for r in f:
            c = r.rstrip('\n').split('\t')
            if len(c) < 2 or c[0] != 'it':
                continue
            for lemma in sorted(lemmi.get(c[1].lower(), ())):
                print(f'it\t{c[1].lower()}\t{lemma}')
                righe += 1
    print(f'forme frequenti con un lemma: {righe} righe, da {len(lemmi)} forme flesse note', file=sys.stderr)


if __name__ == '__main__':
    main()
