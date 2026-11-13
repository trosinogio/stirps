#!/usr/bin/env python3
"""Radici omografe: una pagina cita una radice con un senso che non è quello della radice?

Wiktionary distingue le radici omografe con un identificativo (*(s)ker-@cut, *(s)ker-@turn), ma molte pagine citano
la radice senza identificativo, e alcune citano una radice omografa che non ha una pagina (*tewk- «to push, press»,
da cui il protoslavo *tъkati, accanto a *tewk- «to become swollen, fat»): nel dizionario finiscono tutte nello stesso
nodo, e la famiglia mescola parole che non sono parenti. L'indizio è la glossa con cui la pagina cita la radice
(t=): se non ha una linea di senso con la glossa della radice (controlla_sensi.py: una parola piena in comune, o una
dentro l'altra), la citazione va guardata.

Prima di usarlo per spostare archi, il controllo si misura (un'analisi automatica si misura prima di usarla):
- per le radici con una pagina, quante citazioni stanno nel gruppo di senso della glossa della pagina (le glosse si
  raggruppano per legami, anche indiretti: «to swell» – «to swell, grow» – «to grow»), e quante fuori;
- per i nodi generici di radici omografe dichiarate, quante citazioni senza identificativo hanno una glossa che si
  lega a una sola delle omografe (lì l'arco si potrebbe precisare), a più d'una, a nessuna;
- e un campione delle citazioni fuori dal gruppo, con le pagine che le fanno, da giudicare a mano.

    python3 controlla_omografe.py glosse_radici.tsv [fuori.tsv]

glosse_radici.tsv lo scrive wiktionary.py con GLOSSE_RADICI=percorso: radice, lingua, lemma, glossa, volte, se è la
glossa della pagina, se è il nodo generico di omografe dichiarate, le pagine che la citano. fuori.tsv: radice, glossa
della radice, glossa citata, volte, pagine.
"""
import random
import sys
from collections import Counter, defaultdict

from controlla_sensi import legate, parole


def gruppo(glosse, partenza):
    """Le glosse legate a quella di partenza, anche attraverso altre glosse."""
    p = {g: parole(g) for g in glosse}
    dentro, coda = {partenza}, [partenza]
    while coda:
        a = coda.pop()
        for g in glosse:
            if g not in dentro and p[a] and p[g] and legate(p[a], p[g]):
                dentro.add(g)
                coda.append(g)
    return dentro


def main():
    radici = defaultdict(list)
    for r in open(sys.argv[1], encoding='utf-8'):
        c = r.rstrip('\n').split('\t')
        if len(c) >= 8:
            radici[c[0]].append({'lingua': c[1], 'lemma': c[2], 'glossa': c[3], 'n': int(c[4]), 'propria': c[5] == 't',
                                 'generico': c[6] == 't', 'citanti': c[7]})
    con_pagina = dentro = fuori_n = 0
    fuori, per_lingua = [], Counter()
    # le omografe dichiarate di ogni (lingua, lemma): chiave → glosse
    precise = defaultdict(dict)
    for k, gl in radici.items():
        if '@' in k:
            precise[(gl[0]['lingua'], gl[0]['lemma'])][k] = [g['glossa'] for g in gl] + [k.split('@', 1)[1]]
    generici = Counter()
    esempi_generici = []
    for k, gl in radici.items():
        if gl[0]['generico']:
            # nodo generico: a quale delle omografe porta la glossa citata?
            for g in gl:
                pg = parole(g['glossa'])
                legati = [kp for kp, glp in precise[(g['lingua'], g['lemma'])].items()
                          if pg and any(legate(pg, parole(x)) for x in glp if parole(x))]
                esito = 'una sola omografa' if len(legati) == 1 else 'più omografe' if legati else 'nessuna omografa'
                generici[esito] += g['n']
                if len(legati) == 1 and len(esempi_generici) < 15:
                    esempi_generici.append(f"  *{g['lemma']} «{g['glossa'][:50]}» ×{g['n']} → {legati[0]} ({g['citanti'][:70]})")
            continue
        propria = next((g for g in gl if g['propria']), None)
        if not propria or len(gl) < 2:
            continue
        con_pagina += 1
        nel_gruppo = gruppo([g['glossa'] for g in gl], propria['glossa'])
        for g in gl:
            if g['propria']:
                continue
            if g['glossa'] in nel_gruppo:
                dentro += g['n']
            else:
                fuori_n += g['n']
                per_lingua[g['lingua']] += g['n']
                fuori.append((k, g['lemma'], propria['glossa'], g['glossa'], g['n'], g['citanti']))
    tot = dentro + fuori_n
    print(f'radici con una pagina e almeno una citazione con glossa: {con_pagina}; citazioni: {tot}, '
          f'nel gruppo di senso della pagina {dentro} ({dentro / max(1, tot):.0%}), fuori {fuori_n} '
          f'({len({f[0] for f in fuori})} radici; {dict(per_lingua.most_common(5))})')
    print(f'nodi generici di radici omografe, citazioni senza identificativo per glossa: {dict(generici)}')
    for e in esempi_generici:
        print(e)
    fuori.sort(key=lambda f: (-f[4], f[0]))
    print('citazioni fuori dal gruppo, le più frequenti:')
    for k, lemma, propria, citata, n, citanti in fuori[:40]:
        print(f'  {k.split(":")[0]} *{lemma} «{propria[:45]}» ≠ «{citata[:45]}» ×{n} ({citanti[:80]})')
    print('citazioni fuori dal gruppo, un campione a caso (per giudicare a mano quante sono radici diverse):')
    for k, lemma, propria, citata, n, citanti in random.Random(13).sample(fuori, min(40, len(fuori))):
        print(f'  {k.split(":")[0]} *{lemma} «{propria[:45]}» ≠ «{citata[:45]}» ×{n} ({citanti[:80]})')
    if len(sys.argv) > 2:
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            for k, lemma, propria, citata, n, citanti in fuori:
                f.write('\t'.join((k, propria, citata, str(n), citanti)) + '\n')


if __name__ == '__main__':
    main()
