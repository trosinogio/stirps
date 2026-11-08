#!/usr/bin/env python3
"""La linea del senso tra una parola e il suo etimo (regola di Giovanni, 8 novembre 2026: «la lezione del tre e del
dente»). Un passaggio vero lega due significati: lo stesso (tres «three» > tre «three»), o uno che si può far derivare
dall'altro (testa «coccio» > testa «capo»). Un arco tra due significati senza nessun legame (*tréyes «three» < *ǵómbʰos
«tooth») è quasi sempre un errore di lettura.

Il controllo guarda le glosse inglesi del pacchetto: due glosse hanno una linea di senso evidente se condividono una
parola piena (dopo una riduzione grezza delle desinenze). Prima di usarlo si misura:
- sugli archi accolti, quante volte la linea è evidente, per tipo di passaggio;
- sulle stesse parole con un etimo scelto a caso tra gli altri archi, quante volte lo è per caso;
- e sono scritti gli archi senza una linea evidente tra due forme ricostruite (il caso di *tréyes), che vanno alla
  redazione: lì il senso va tracciato, o l'arco è sbagliato.

    python3 controlla_sensi.py lessemi.tsv ipotesi.tsv relazioni.tsv [senza_senso.tsv]

I file possono essere compressi. Il rapporto va sullo standard error; senza_senso.tsv: chiave dell'esito, chiave
dell'etimo, glossa dell'esito, glossa dell'etimo, tipo.
"""
import gzip, random, re, sys
from collections import Counter

VUOTE = set('''a an the of to in on at by for with from or and as be is are was were it its this that these those
which who whom whose what someone something somebody person people thing things act action state quality
condition having being used use kind type sort form way manner make made do does done get got go
very much more most less some any all other another such same also not no only just like into out up down over
under about between through within without upon via etc e.g i.e esp especially usually often generally certain
particular specific oneself his her their them they he she him its our your my me us we you
word term name noun verb adjective adverb particle prefix suffix variant alternative obsolete archaic plural
singular masculine feminine neuter dative genitive accusative nominative vocative ablative instrumental locative
first second third person present past participle infinitive imperative subjunctive indicative
relating related pertaining belonging characteristic place where'''.split())


def righe(percorso):
    apri = gzip.open if percorso.endswith('.gz') else open
    with apri(percorso, 'rt', encoding='utf-8') as f:
        for r in f:
            yield r.rstrip('\n').split('\t')


def radice(w):
    """Una riduzione grezza delle desinenze inglesi: teeth/tooth restano diversi, hates/hated/hating diventano hat."""
    for fine in ('ingly', 'edly', 'ings', 'ing', 'ness', 'ment', 'ers', 'ied', 'ies', 'est', 'ed', 'er', 'es', 'ly', 's'):
        if len(w) - len(fine) >= 3 and w.endswith(fine):
            return w[:-len(fine)]
    return w


def parole(glossa):
    g = re.sub(r'\([^)]*\)', ' ', (glossa or '').lower())
    return {radice(w) for w in re.findall(r"[a-z]+", g) if w not in VUOTE and len(w) >= 3}


def legate(a, b):
    """Una parola in comune, o una contenuta nell'altra (seventh e seven, immortal e mortal, renew e new)."""
    if a & b:
        return True
    return any((len(x) >= 3 and x in y) or (len(y) >= 3 and y in x) for x in a for y in b)


def main():
    lessemi_p, ipotesi_p, relazioni_p = sys.argv[1:4]
    uscita = sys.argv[4] if len(sys.argv) > 4 else None
    voce = {}
    for c in righe(lessemi_p):
        if len(c) > 7:
            voce[c[0]] = (c[1], c[2], c[4] == 't', c[7] if c[7] not in ('', '\\N') else None)
    accolte = {c[0] for c in righe(ipotesi_p) if len(c) > 3 and c[3] == 'accolta'}
    archi = []
    for c in righe(relazioni_p):
        if len(c) > 4 and c[1] in accolte and c[2] in voce and c[3] in voce:
            ge, gt = voce[c[2]][3], voce[c[3]][3]
            if ge and gt:
                archi.append((c[2], c[3], c[4], parole(ge), parole(gt)))
    archi = [a for a in archi if a[3] and a[4]]
    conta, legati = Counter(), Counter()
    for e, t, tipo, pe, pt in archi:
        conta[tipo] += 1
        legati[tipo] += legate(pe, pt)
    tot, leg = sum(conta.values()), sum(legati.values())
    # le stesse parole con l'etimo di un altro arco, scelto a caso: quanto si toccano due glosse per caso
    rnd = random.Random(8)
    etimi = [a[4] for a in archi]
    a_caso = sum(1 for a in archi if legate(a[3], rnd.choice(etimi)))
    print(f'linea del senso evidente (una parola piena in comune) negli archi accolti: {leg} su {tot} ({leg / max(1, tot):.0%}); '
          f'con un etimo a caso: {a_caso / max(1, tot):.1%}', file=sys.stderr)
    for tipo, n in conta.most_common():
        print(f'  {tipo}: {legati[tipo]} su {n} ({legati[tipo] / n:.0%})', file=sys.stderr)
    # i casi da guardare: archi tra due forme ricostruite, senza una parola in comune e non verso una radice
    sospetti = [a for a in archi if voce[a[0]][2] and voce[a[1]][2] and voce[a[0]][0] == voce[a[1]][0]
                and not legate(a[3], a[4]) and not voce[a[1]][1].endswith('-') and not voce[a[0]][1].endswith('-')]
    print(f'archi tra due parole ricostruite della stessa lingua senza una linea evidente: {len(sospetti)} '
          f'({dict(Counter(voce[a[0]][0] for a in sospetti).most_common(6))})', file=sys.stderr)
    sospetti.sort(key=lambda a: (voce[a[0]][0] != 'ine-pro', voce[a[0]][0]))
    for e, t, tipo, _, _ in sospetti[:25]:
        print(f'  {voce[e][0]} *{voce[e][1]} «{voce[e][3][:40]}» < {voce[t][0]} *{voce[t][1]} «{voce[t][3][:40]}» ({tipo})',
              file=sys.stderr)
    if uscita:
        with open(uscita, 'w', encoding='utf-8') as f:
            for e, t, tipo, _, _ in archi:
                if not legate(parole(voce[e][3]), parole(voce[t][3])):
                    f.write('\t'.join((e, t, voce[e][3], voce[t][3], tipo)) + '\n')


if __name__ == '__main__':
    main()
