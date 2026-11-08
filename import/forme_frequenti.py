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
import os, re, sys
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
    # le voci, senza le pagine di servizio di Wiktionary («i/languages A to L») e le locuzioni
    voci = {c[2] for c in leggi(lessemi) if len(c) > 4 and c[1] == 'it' and c[4] != 't' and not re.search(r'[/ ]', c[2])}
    voci_min = {v.lower(): v for v in voci if v == v.lower()}      # Sara (nome) non ferma sara → sarà
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
        """Le voci a cui una forma rimanda. Si passa per un'altra forma solo se è elisa (dell' → l' → lo): una grafia
        antica come tramite porterebbe fuori strada (hai → ai, che è a + i). Una forma elisa che è anche una voce (l')
        si segue lo stesso, perché la voce non dice da dove viene."""
        out = set()
        for l in rimandi.get(forma, ()):
            lm = l.lower()
            elisa = lm.endswith("'")
            if l in voci and not (elisa and lm in riduzioni and lm in rimandi):
                out.add(l)
            elif elisa and lm in rimandi and prof < 3:
                out |= risolvi(lm, prof + 1)
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

    def completa(forma):
        """Le voci di una forma che non ne ha di sue: l'accento (piu → più, sara → sarà), l'apostrofo che il lessico dei
        sottotitoli toglie (po → po' → poco), la vocale di una forma elisa (un' → una, uno)."""
        cand = con_accento(forma)
        if not forma.endswith("'"):
            cand.append(forma + "'")
        elif len(forma) >= 2:
            cand += [forma[:-1] + v for v in 'aoei']
        trovate = set()
        for x in cand:
            if x in voci_min and x not in riduzioni:
                trovate.add(voci_min[x])
            trovate |= risolvi(x)
            if trovate and not forma.endswith("'"):
                break
        return trovate

    righe = 0
    conti = defaultdict(int)
    viste = set()
    frequenti = [c[1].lower() for c in leggi(frequenze) if len(c) >= 2 and c[0] == 'it']
    # le riduzioni con l'apostrofo entrano anche se il lessico non le ha (po', un'): il lessico dei sottotitoli le scrive
    # senza, ma chi incolla un testo no
    for forma in frequenti + sorted(r for r in riduzioni if r.endswith("'")):
        if forma in viste:
            continue
        viste.add(forma)
        lemmi, sostituisce = risolvi(forma), forma in riduzioni
        if forma in voci_min and not sostituisce:
            lemmi.discard(voci_min[forma])
        if not lemmi:
            lemmi = completa(forma)
            if lemmi:
                sostituisce = forma not in voci_min
                conti['completate'] += 1
        for lemma in sorted(lemmi):
            print(f"it\t{forma}\t{lemma}\t{'t' if sostituisce else 'f'}")
            righe += 1
        if lemmi:
            conti['riduzioni' if forma in riduzioni else 'forme'] += 1
    print(f'forme frequenti con un lemma: {righe} righe ({dict(conti)}), da {len(rimandi)} forme note', file=sys.stderr)


if __name__ == '__main__':
    main()
