#!/usr/bin/env python3
"""Riapplica a un pacchetto dati già fatto (dati/*.tsv.gz) le regole sulle voci valide di wiktionary.py, senza
riscaricare i dump: toglie le voci che non sono parole (lemma_valido), gli archi che le toccano e le ipotesi rimaste
senza archi, come fa il parser con togli_non_validi(). Utile quando cambiano le regole e non i dati.

    python3 filtra_pacchetto.py ../dati
"""
import gzip, io, os, sys
from collections import Counter
from wiktionary import lemma_valido


def leggi(cartella, nome):
    with gzip.open(os.path.join(cartella, f'{nome}.tsv.gz'), 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def scrivi(cartella, nome, righe):
    dati = ''.join('\t'.join(r) + '\n' for r in righe).encode('utf-8')
    with open(os.path.join(cartella, f'{nome}.tsv.gz'), 'wb') as f:      # come gzip -9 -n: niente nome né data
        with gzip.GzipFile(filename='', mode='wb', compresslevel=9, fileobj=f, mtime=0) as g:
            g.write(dati)


def valida(r):   # chiave, lingua, lemma, omografo, ricostruito, translit, pos, glossa
    return lemma_valido(r[1], r[2].replace('\\\\', '\\'), r[4] == 't')


if __name__ == '__main__':
    d = sys.argv[1]
    lessemi = leggi(d, 'lessemi')
    via = {r[0] for r in lessemi if not valida(r)}
    relazioni, ipotesi = leggi(d, 'relazioni'), leggi(d, 'ipotesi')   # relazioni: chiave, ipotesi, esito, etimo, …
    prima = Counter(r[1] for r in relazioni)
    relazioni = [r for r in relazioni if r[2] not in via and r[3] not in via]
    dopo = Counter(r[1] for r in relazioni)
    tolte = {h[0] for h in ipotesi if h[1] in via or (prima[h[0]] and not dopo[h[0]])}
    conta = Counter(voci=len(via), ipotesi=len(tolte), archi=sum(prima.values()) - sum(dopo[k] for k in dopo if k not in tolte))
    scrivi(d, 'lessemi', [r for r in lessemi if r[0] not in via])
    scrivi(d, 'ipotesi', [h for h in ipotesi if h[0] not in tolte])
    scrivi(d, 'relazioni', [r for r in relazioni if r[1] not in tolte])
    scrivi(d, 'radici', [r for r in leggi(d, 'radici') if r[0] not in via and r[1] not in via])
    scrivi(d, 'doppioni', [r for r in leggi(d, 'doppioni') if r[0] not in via and r[1] not in via])
    scrivi(d, 'attestazioni', [r for r in leggi(d, 'attestazioni') if r[1] not in via])
    if os.path.exists(os.path.join(d, 'dizionari.tsv.gz')):
        diz = leggi(d, 'dizionari')
        buoni = [r for r in diz if valida(r)]
        conta['voci_dei_dizionari'] = len(diz) - len(buoni)
        scrivi(d, 'dizionari', buoni)
    print('tolte:', dict(conta), file=sys.stderr)
