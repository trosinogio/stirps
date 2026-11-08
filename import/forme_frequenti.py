#!/usr/bin/env python3
"""Le forme flesse italiane più frequenti e i loro lemmi, per l'analisi di un testo (dati/forme_it.tsv.gz, tabella
forma_lemma, analizza_testo()): andava → andare, occhi → occhio, era → essere, hanno → avere, nel → in + il.

Le forme sono quelle del lessico di frequenza (dati/frequenze_it.tsv.gz, 50 mila), i lemmi devono essere voci del
dizionario e vengono da due elenchi di filtra.py:
- forme.tsv (FORME): le pagine che sono soltanto forme flesse;
- forme_analisi.tsv (ANALISI), facoltativo: anche i sensi «form of» delle pagine con altri sensi (giorni), le
  riduzioni (dalla = da + la, l' = lo) e le tavole delle forme dei lemmi (avere: ho, hai, ha, hanno).
Una forma che rimanda a un'altra forma si segue fino alla voce (dell' → di + l' → lo). Una forma che il lessico scrive
senza accento si legge con l'accento (piu → più, puo → può → potere, perchè → perché). Una forma che è anche un lemma
(era, porta) non ha bisogno di una riga per sé: l'analisi prova sempre anche la forma stessa; ma se quel lemma è solo
una riduzione (dalla, l'), la quarta colonna (t) dice all'analisi di contare i lemmi a cui rimanda e non la voce.

    python3 forme_frequenti.py ../dati/frequenze_it.tsv.gz dati/it/forme.tsv dati/it/tsv/lessemi.tsv \
        [dati/it/forme_analisi.tsv] > forme_it.tsv
"""
import os, sys
from collections import defaultdict
import gzip

ACCENTO = {'a': 'à', 'e': 'è', 'i': 'ì', 'o': 'ò', 'u': 'ù'}
SCAMBIO = {'è': 'é', 'é': 'è', 'ì': 'í', 'ò': 'ó', 'ù': 'ú'}


def leggi(percorso):
    if not percorso or not os.path.exists(percorso):
        return []
    apri = gzip.open if percorso.endswith('.gz') else open
    with apri(percorso, 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def main():
    frequenze, forme, lessemi = sys.argv[1:4]
    analisi = sys.argv[4] if len(sys.argv) > 4 else None
    voci = {c[2] for c in leggi(lessemi) if len(c) > 4 and c[1] == 'it' and c[4] != 't'}
    voci_min = {v.lower(): v for v in voci}
    rimandi = defaultdict(set)      # forma → lemmi (voci o altre forme)
    riduzioni = set()               # le forme che sono solo riduzioni di altre parole (dalla, l')
    for c in leggi(forme):
        if len(c) >= 2 and c[0].lower() != c[1].lower():
            rimandi[c[0].lower()].add(c[1])
    for c in leggi(analisi):
        if len(c) >= 3 and c[0].lower() != c[1].lower():
            rimandi[c[0].lower()].add(c[1])
            if c[2] == 'riduzione':
                riduzioni.add(c[0].lower())

    def risolvi(forma, prof=0):
        """Le voci a cui una forma rimanda, seguendo le forme intermedie (dell' → l' → lo); una riduzione che è anche
        una voce (l') si segue lo stesso, perché la voce non dice da dove viene."""
        out = set()
        for l in rimandi.get(forma, ()):
            lm = l.lower()
            if l in voci and lm not in riduzioni:
                out.add(l)
            elif lm in rimandi and prof < 3:
                out |= risolvi(lm, prof + 1)
            elif l in voci:
                out.add(l)
        return out

    def con_accento(forma):
        """piu → più, perchè → perché, e' → è: le varianti della forma con l'accento giusto sull'ultima vocale."""
        cand = []
        if forma.endswith("'") and len(forma) >= 2 and forma[-2] in ACCENTO:
            cand.append(forma[:-2] + ACCENTO[forma[-2]])
        if forma and forma[-1] in ACCENTO:
            cand.append(forma[:-1] + ACCENTO[forma[-1]])
            if forma[-1] == 'e':
                cand.append(forma[:-1] + 'é')
        if forma and forma[-1] in SCAMBIO:
            cand.append(forma[:-1] + SCAMBIO[forma[-1]])
        return cand

    righe = 0
    conti = defaultdict(int)
    for c in leggi(frequenze):
        if len(c) < 2 or c[0] != 'it':
            continue
        forma = c[1].lower()
        lemmi, sostituisce = risolvi(forma), forma in riduzioni
        if forma in voci_min and not sostituisce:
            lemmi.discard(voci_min[forma])
        if not lemmi and forma not in voci_min:
            for x in con_accento(forma):
                if x in voci_min:
                    lemmi, sostituisce = {voci_min[x]}, True
                    conti['accento'] += 1
                    break
                if risolvi(x):
                    lemmi, sostituisce = risolvi(x), True
                    conti['accento'] += 1
                    break
        for lemma in sorted(lemmi):
            print(f"it\t{forma}\t{lemma}\t{'t' if sostituisce else 'f'}")
            righe += 1
        if lemmi:
            conti['riduzioni' if forma in riduzioni else 'forme'] += 1
    print(f'forme frequenti con un lemma: {righe} righe ({dict(conti)}), da {len(rimandi)} forme note', file=sys.stderr)


if __name__ == '__main__':
    main()
