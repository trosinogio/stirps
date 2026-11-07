#!/usr/bin/env python3
"""Controllo di qualità delle radici: per ogni parola che dichiara la sua radice in Wiktionary ({{root}}, radici.tsv),
confronta la radice dichiarata con la cima a cui arriva la sua catena accolta (primo etimo a ogni passo).

    python3 controlla_radici.py ../dati            # i conti, per esito e per lingua, con esempi

Esiti: «giusta» (la cima della catena è la radice dichiarata); «sale oltre la radice» (la attraversa e poi
continua: la radice mostrata è un'altra); «omografa generica» (arriva a un nodo
della stessa forma senza significato, *(s)ker- invece di *(s)ker-@cut); «variante di notazione» (la stessa radice
scritta in un altro modo: *(s)teg- e *teg-, *mey- (small) e *mey-); «per un altro etimo» (la radice dichiarata è quella
di un altro elemento: eye-catcher segue eye, *h₃ekʷ-, e dichiara la radice di catcher, *kap-); «si ferma su una
parola ricostruita» (*ḱréddʰeh₁ti, senza salire alla radice); «altra radice» (arriva a un'altra radice ricostruita:
spesso un'altra ricostruzione della stessa, *kap- e *keh₂p-); «si ferma prima» (la catena finisce su una parola
attestata o su una forma intermedia).
"""
import gzip, os, random, re, sys, unicodedata
from collections import Counter, defaultdict


def leggi(d, nome):
    with gzip.open(os.path.join(d, f'{nome}.tsv.gz'), 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def senza_id(k):
    return k.split('@', 1)[0]


def notazione(k):
    """La radice senza i segni che ne cambiano solo la scrittura: *(s)teg- e *teg-, *mey- (small) e *mey-, u e w."""
    t = senza_id(k).split(':', 2)[-1]
    t = re.sub(r'\s*\(.*?\)\s*', '', t.replace('(s)', ''))
    t = ''.join(c for c in unicodedata.normalize('NFD', t) if not unicodedata.combining(c))
    return t.strip('*-').replace('u', 'w').replace('i', 'y')


if __name__ == '__main__':
    d = sys.argv[1]
    lessemi = {r[0]: r for r in leggi(d, 'lessemi')}
    accolta = {h[1]: h[0] for h in leggi(d, 'ipotesi') if h[3] == 'accolta'}     # esito → ipotesi accolta
    primo, etimi = {}, defaultdict(list)
    for r in leggi(d, 'relazioni'):                                               # chiave, ipotesi, esito, etimo, tipo, ordine
        if accolta.get(r[2]) == r[1]:
            etimi[r[2]].append(r[3])
            if r[5] == '1':
                primo.setdefault(r[2], r[3])

    def raggiunte(k):
        """Le voci raggiunte per tutti gli etimi, non solo il primo."""
        visti, coda = {k}, [k]
        while coda:
            for e in etimi.get(coda.pop(), ()):
                if e not in visti:
                    visti.add(e)
                    coda.append(e)
        return visti
    dichiarate = defaultdict(set)
    for parola, radice in leggi(d, 'radici'):
        dichiarate[parola].add(radice)
    esiti, per_lingua, esempi = Counter(), defaultdict(Counter), defaultdict(list)
    for parola, radici in dichiarate.items():
        if parola not in lessemi:
            continue
        cammino, k = [parola], parola
        while k in primo and primo[k] not in cammino:
            k = primo[k]
            cammino.append(k)
        cima = cammino[-1]
        raggiunta_tutta = raggiunte(parola)
        if cima in radici or any('@' not in r and r == senza_id(cima) for r in radici):
            esito = 'giusta'            # anche la radice dichiarata generica (*bʰeh₁-) con la catena sulla variante precisa
        elif radici & raggiunta_tutta - set(cammino) or any('@' not in r and r == senza_id(x) for r in radici
                                                            for x in raggiunta_tutta - set(cammino)):
            esito = 'giusta per un altro elemento del composto'   # sanctify: sanctus + -fico < faciō < *dʰeh₁-
        elif radici & set(cammino):
            esito = 'sale oltre la radice'          # la attraversa e poi continua: la cima mostrata è un'altra
        elif any(senza_id(r) == senza_id(c) for r in radici for c in cammino):
            esito = 'omografa generica'
        elif lessemi.get(cima, [''] * 5)[4] == 't' and cima.split(':')[1].endswith('-pro'):
            raggiunta = raggiunte(parola)
            if any(notazione(r) == notazione(cima) for r in radici):
                esito = 'variante di notazione'
            elif not lessemi[cima][2].endswith('-'):
                esito = 'si ferma su una parola ricostruita'
            elif radici & raggiunta or any(notazione(r) == notazione(x) for r in radici for x in raggiunta):
                esito = 'per un altro etimo'
            else:
                esito = 'altra radice'
        else:
            esito = 'si ferma prima'
        esiti[esito] += 1
        per_lingua[lessemi[parola][1]][esito] += 1
        esempi[esito].append(f"{lessemi[parola][2]} → {lessemi.get(cima, ['', '', cima])[2]} (dichiara {', '.join(sorted(r.split(':', 2)[2] for r in radici))})")
    tot = sum(esiti.values())
    giuste = esiti['giusta'] + esiti['giusta per un altro elemento del composto']
    print(f'parole con una radice dichiarata: {tot}; giuste in tutto (anche per un altro elemento del composto): '
          f'{giuste} ({100 * giuste / tot:.1f}%)')
    for e, n in esiti.most_common():
        print(f'  {e}: {n} ({100 * n / tot:.1f}%)')
    print('per lingua:', {l: dict(c) for l, c in sorted(per_lingua.items(), key=lambda x: -sum(x[1].values()))[:6]})
    random.seed(1)
    for e in esiti:
        print(f'— {e}:', ' · '.join(random.sample(esempi[e], min(6, len(esempi[e])))))
