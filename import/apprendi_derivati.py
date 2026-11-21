#!/usr/bin/env python3
"""I derivati trasparenti senza etimologia, in ogni lingua: le regole di formazione imparate dai dati e misurate prima
di usarle (richiesta di Giovanni del 20 novembre 2026, «aeration è senza etimologia, è chiaro che derivi dal latino
aer»). È apprendi_greco.py per le altre lingue, con due tipi di regole:
- suffisso: abolition < abolish insegna «-ition al posto di -ish» (S, ition, ish); aerator < aerate (S, or, e);
- prefisso: reaeration < aeration insegna «re- davanti a una parola» (P, re).
Una regola scatta su una parola se la base che dà è una voce della stessa lingua, senza omografi, con un'etimologia.

Ogni regola si misura dove scatta, sulle voci di etimologia nota dell'80% di addestramento: la previsione è esatta se
la base è l'etimo della voce, ed è nella famiglia giusta se la base e l'etimo arrivano alla stessa cima (aeration <
aerate o < latino aerātiō: tutte e due arrivano ad ἀήρ). Wiktionary spesso preferisce l'etimo dotto (-ation dal latino
-ātiō), e la famiglia è quello che conta per il lettore. Restano le regole con almeno SUPPORTO casi, almeno PRECISIONE
nella famiglia giusta e almeno ESATTEZZA esatte; poi il tutto si misura per lingua sul 20% tenuto da parte, e una
lingua entra solo se lì arriva a SOGLIA_LINGUA.

Le voci senza etimologia delle lingue che passano ricevono la previsione della regola migliore, come righe con opera
«analisi» nel file degli etimi (certezza 2, mai nelle storie). Il greco ha le sue regole (apprendi_greco.py).

    python3 apprendi_derivati.py etimi.tsv lessemi.tsv ipotesi.tsv relazioni.tsv [--solo-rapporto]

I file possono essere compressi (.gz), tranne gli etimi se si scrive. Il rapporto va sullo standard error.
"""
import gzip, sys, unicodedata, zlib
from collections import Counter, defaultdict

SUPPORTO, PRECISIONE, ESATTEZZA = 10, 0.9, 0.3
SOGLIA_LINGUA, MINIMO_PROVA = 0.85, 30
ESCLUSE = {'grc'}                   # apprendi_greco.py
MAX_SUFFISSO, MIN_RADICE = 6, 3


def righe(percorso):
    apri = gzip.open if percorso.endswith('.gz') else open
    with apri(percorso, 'rt', encoding='utf-8') as f:
        for r in f:
            yield r.rstrip('\n').split('\t')


def nudo(s):
    """La forma senza segni diacritici e in minuscolo: per confrontare le terminazioni (rôle e role)."""
    return ''.join(c for c in unicodedata.normalize('NFD', s.lower()) if not unicodedata.combining(c))


def parola(lemma):
    """Una parola semplice: lettere sole, niente spazi, trattini, maiuscole (i nomi propri restano fuori)."""
    return len(lemma) >= 4 and lemma.isalpha() and lemma == lemma.lower()


def regole_della_coppia(w, b):
    """Le regole che spiegano w < b: un suffisso che sostituisce la fine della base, o un prefisso davanti alla base."""
    w_, b_ = nudo(w), nudo(b)
    regole = []
    if w_.endswith(b_) and len(w_) - len(b_) <= MAX_SUFFISSO and len(b_) >= MIN_RADICE + 1:
        regole.append(('P', w_[:len(w_) - len(b_)]))
    n = 0
    while n < min(len(w_), len(b_)) and w_[n] == b_[n]:
        n += 1
    if n >= MIN_RADICE:
        for k in range(n, max(MIN_RADICE, n - 2) - 1, -1):     # anche una lettera in meno: abolition, abolish
            sw, sb = w_[k:], b_[k:]
            if sw and len(sw) <= MAX_SUFFISSO and len(sb) <= MAX_SUFFISSO:
                regole.append(('S', sw, sb))
    return regole


def main():
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    solo_rapporto = '--solo-rapporto' in sys.argv
    etimi_p, lessemi_p, ipotesi_p, relazioni_p = a[:4]
    voce = {}
    for c in righe(lessemi_p):
        if len(c) > 6 and c[4] == 'f':
            voce[c[0]] = (c[1], c[2])
    accolte = {c[0] for c in righe(ipotesi_p) if len(c) > 3 and c[3] == 'accolta'}
    primo, etimi_di = {}, defaultdict(set)
    for c in righe(relazioni_p):
        if len(c) > 5 and c[1] in accolte:
            etimi_di[c[2]].add(c[3])
            if c[5] == '1':
                primo.setdefault(c[2], c[3])

    def cima(k):
        visti = {k}
        while k in primo and primo[k] not in visti:
            k = primo[k]
            visti.add(k)
        return k

    # le voci di ogni lingua, per lemma: una base vale solo se è l'unica voce con quel lemma (niente omografi)
    per_lemma = defaultdict(list)
    for k, (lingua, lemma) in voce.items():
        per_lemma[(lingua, nudo(lemma))].append(k)
    con_etimo = set(etimi_di)
    try:
        coperte = {(c[1], c[2]) for c in righe(etimi_p) if len(c) > 8}
    except FileNotFoundError:
        coperte = set()

    def base(lingua, forma, n):
        # una base troppo corta non spiega la parola: авиатор non è авиа- + тор, analitzar non è anal + -itzar
        if len(forma) < MIN_RADICE + 1 or 2 * len(forma) < len(n):
            return None
        ks = per_lemma.get((lingua, forma))
        return ks[0] if ks and len(ks) == 1 and ks[0] in con_etimo else None

    def scatti(lingua, lemma, k, regole_lingua):
        """Le regole di questa lingua che scattano sulla voce, con la base che danno."""
        n = nudo(lemma)
        out = []
        for i in range(1, min(MAX_SUFFISSO, len(n) - MIN_RADICE) + 1):
            for sb in regole_lingua.get(('S', n[-i:]), ()):
                b = base(lingua, n[:-i] + sb, n)
                if b and b != k:
                    out.append((('S', n[-i:], sb), b))
            p = regole_lingua.get(('P', n[:i]))
            if p:
                b = base(lingua, n[i:], n)
                if b and b != k:
                    out.append((('P', n[:i]), b))
        return out

    # 1. le coppie note: voce < base della stessa lingua, una sola base
    coppie = defaultdict(list)
    for k, (lingua, lemma) in voce.items():
        if lingua in ESCLUSE or not parola(lemma) or k not in etimi_di:
            continue
        coppie[lingua].append(k)
    rapporto, nuove = [], []
    totali = Counter()
    for lingua in sorted(coppie, key=lambda x: -len(coppie[x])):
        voci = coppie[lingua]
        addestra = [k for k in voci if zlib.crc32(k.encode()) % 5]
        prova = [k for k in voci if not zlib.crc32(k.encode()) % 5]
        # le regole candidate, dalle coppie dell'addestramento con un etimo della stessa lingua
        cand = Counter()
        for k in addestra:
            for e in etimi_di[k]:
                if e in voce and voce[e][0] == lingua and parola(voce[e][1]):
                    for r in regole_della_coppia(voce[k][1], voce[e][1]):
                        cand[r] += 1
        indice = defaultdict(set)
        for r, n in cand.items():
            if n >= SUPPORTO:
                if r[0] == 'S':
                    indice[('S', r[1])].add(r[2])
                else:
                    indice[('P', r[1])] = True
        if not indice:
            continue
        # 2. ogni regola si misura dove scatta, sulle voci note dell'addestramento
        misura = defaultdict(Counter)
        for k in addestra:
            cime = {cima(e) for e in etimi_di[k]}
            for r, b in scatti(lingua, voce[k][1], k, indice):
                misura[r]['scatta'] += 1
                misura[r]['esatta'] += b in etimi_di[k]
                misura[r]['famiglia'] += cima(b) in cime or b in etimi_di[k]
        buone = {r: m['famiglia'] / m['scatta'] for r, m in misura.items()
                 if m['scatta'] >= SUPPORTO and m['famiglia'] >= PRECISIONE * m['scatta'] and m['esatta'] >= ESATTEZZA * m['scatta']}
        if not buone:
            continue
        scelte = defaultdict(set)
        for r in buone:
            if r[0] == 'S':
                scelte[('S', r[1])].add(r[2])
            else:
                scelte[('P', r[1])] = True

        def prevedi(lemma, k):
            ss = [(buone[r], len(r[1]), r, b) for r, b in scatti(lingua, lemma, k, scelte) if r in buone]
            if not ss:
                return None
            ss.sort(key=lambda x: (-x[0], -x[1]))
            return ss[0][2], ss[0][3]

        # 3. la prova sul 20% tenuto da parte
        conta = Counter()
        for k in prova:
            p = prevedi(voce[k][1], k)
            if not p:
                continue
            conta['previsioni'] += 1
            cime = {cima(e) for e in etimi_di[k]}
            conta['esatte'] += p[1] in etimi_di[k]
            conta['famiglia'] += cima(p[1]) in cime or p[1] in etimi_di[k]
        n = conta['previsioni']
        passa = n >= MINIMO_PROVA and conta['famiglia'] >= SOGLIA_LINGUA * n
        # 4. le voci senza etimologia, se la lingua passa
        senza = [(k, l) for k, (lg, l) in voce.items() if lg == lingua and k not in etimi_di and parola(l)
                 and (lingua, l) not in coperte]
        previste = 0
        esempi = []
        for k, l in sorted(senza, key=lambda x: x[1]):
            p = prevedi(l, k)
            if not p:
                continue
            previste += 1
            (r, b) = p
            if len(esempi) < 6:
                esempi.append(f'{l} < {voce[b][1]}')
            if passa and not solo_rapporto:
                affisso = (l[:len(r[1])] + '-') if r[0] == 'P' else '-' + l[-len(r[1]):]
                nuove.append(('analisi:' + k, lingua, l, 1, lingua, voce[b][1], 'derivazione', affisso, 'analisi'))
        totali['lingue_misurate'] += 1
        totali['lingue_che_passano'] += passa
        totali['voci_analizzate'] += previste if passa else 0
        rapporto.append((lingua, len(buone), n, conta['famiglia'] / max(1, n), conta['esatte'] / max(1, n), passa,
                         len(senza), previste, esempi))
    print(f'derivati trasparenti: {dict(totali)} (regole con almeno {SUPPORTO} casi, {PRECISIONE:.0%} nella famiglia, '
          f'{ESATTEZZA:.0%} esatte; una lingua passa con almeno {MINIMO_PROVA} prove e {SOGLIA_LINGUA:.0%} nella famiglia)',
          file=sys.stderr)
    for lingua, nr, n, fam, es, passa, senza, previste, esempi in rapporto[:40]:
        print(f'  {lingua}: {nr} regole, prova su {n}: nella famiglia {fam:.0%}, esatte {es:.0%} → '
              f'{"passa" if passa else "non passa"}; senza etimologia {senza}, previste {previste}: {"; ".join(esempi)}',
              file=sys.stderr)
    if solo_rapporto:
        return
    righe_etimi = list(righe(etimi_p))
    lingue_nuove = {r[1] for r in nuove}
    with open(etimi_p, 'w', encoding='utf-8') as out:
        for c in righe_etimi:
            # le righe d'analisi di un giro precedente di questo strumento si riscrivono; quelle di latino e greco
            # (analisi_composti.py, apprendi_greco.py) restano
            if not (len(c) > 8 and c[8] == 'analisi' and c[1] in lingue_nuove and c[0].startswith('analisi:') and c[1] not in ('la', 'grc')):
                out.write('\t'.join(c) + '\n')
        for r in nuove:
            out.write('\t'.join('\\N' if x is None or x == '' else str(x) for x in r) + '\n')


if __name__ == '__main__':
    main()
