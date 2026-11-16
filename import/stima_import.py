#!/usr/bin/env python3
"""Stima di un import prima di farlo: confronta il pacchetto dati nuovo con quello di prima, conta le righe nuove e ne
calcola lo spazio nel database con i byte per riga misurati sul database vero. Conta le voci senza etimologia, per lingua, prima e dopo. Misura quanto le lingue si incontrano
(famiglie con più lingue moderne, prestiti tra lingue moderne) e, per ogni lingua esaminata, che voci entrano, in quali
famiglie, quanto costano gli ambiti possibili e un campione di catene da guardare a mano.

    python3 stima_import.py prima/ dati/ fr,de,ru --attuale 557 [--frequenze fr=f.tsv.gz,de=d.tsv.gz]

Le cartelle contengono i .tsv.gz del pacchetto. Le frequenze sono i dati/frequenze_*.tsv.gz o le liste di FrequencyWords
(una forma e un numero per riga). I byte per riga, indici compresi (pg_total_relation_size / righe), sono quelli del
database del 6 novembre 2026: 290 mila voci, 349 MB. Si rimisurano quando cambia lo schema.
"""
import gzip, os, random, sys
from collections import Counter, defaultdict

BYTE = {'lessema': 510, 'ipotesi': 425, 'relazione': 355, 'mv_famiglia': 100, 'glossa': 340, 'attestazione': 336}
MODERNE = ('it', 'en', 'fr', 'de', 'ru', 'es', 'pt')


def leggi(d, nome):
    p = os.path.join(d, f'{nome}.tsv.gz')
    if not os.path.exists(p):
        return []
    with gzip.open(p, 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def vuoto(x):
    return x in ('', '\\N')


def mb(b):
    return b / 1024 / 1024


def grafo(d):
    """L'ipotesi accolta di ogni voce, il suo primo etimo, tutti gli etimi, e gli archi delle ipotesi accolte."""
    accolta = {h[1]: h[0] for h in leggi(d, 'ipotesi') if h[3] == 'accolta'}
    primo, etimi, archi, n_rel = {}, defaultdict(list), [], Counter()
    for r in leggi(d, 'relazioni'):            # chiave, ipotesi, esito, etimo, tipo, ordine
        etimi[r[2]].append(r[3])
        n_rel[r[2]] += 1
        if accolta.get(r[2]) == r[1]:
            archi.append((r[2], r[3]))
            o = int(r[5]) if r[5].isdigit() else 99
            if r[2] not in primo or o < primo[r[2]][1]:
                primo[r[2]] = (r[3], o)
    return accolta, {k: e for k, (e, _) in primo.items()}, etimi, archi, n_rel


def catena(primo, k):
    passi, visti = [k], {k}
    while k in primo and primo[k] not in visti and len(passi) < 12:
        k = primo[k]
        passi.append(k)
        visti.add(k)
    return passi


def famiglie(less, primo):
    """Per ogni cima, le lingue moderne delle voci che ci arrivano per il primo etimo."""
    f = defaultdict(set)
    for k, r in less.items():
        if r[1] in MODERNE and k in primo:
            f[catena(primo, k)[-1]].add(r[1])
    return f


def frequenti(arg, lingue):
    """--frequenze fr=percorso,de=percorso (o un percorso solo, per la prima lingua): forme in minuscolo."""
    insiemi = {}
    for voce in arg.split(','):
        lingua, percorso = voce.split('=', 1) if '=' in voce else (lingue[0], voce)
        aperto = gzip.open(percorso, 'rt', encoding='utf-8') if percorso.endswith('.gz') else open(percorso, encoding='utf-8')
        with aperto as f:
            insiemi[lingua] = {(r.split('\t')[1] if percorso.endswith('.gz') else r.split()[0]).lower()
                               for r in f if r.strip() and (r.count('\t') if percorso.endswith('.gz') else 1)}
    return insiemi


if __name__ == '__main__':
    prima_d, dopo_d, lingue = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
    attuale = float(sys.argv[sys.argv.index('--attuale') + 1]) if '--attuale' in sys.argv else None
    freq = frequenti(sys.argv[sys.argv.index('--frequenze') + 1], lingue) if '--frequenze' in sys.argv else {}
    p_less, d_less = {r[0]: r for r in leggi(prima_d, 'lessemi')}, {r[0]: r for r in leggi(dopo_d, 'lessemi')}
    nuove = [k for k in d_less if k not in p_less]
    tolte = [k for k in p_less if k not in d_less]
    righe = {n: (len(leggi(prima_d, n)), len(leggi(dopo_d, n))) for n in ('ipotesi', 'relazioni', 'attestazioni')}
    d_ip = righe['ipotesi'][1] - righe['ipotesi'][0]
    d_rel = righe['relazioni'][1] - righe['relazioni'][0]
    d_att = righe['attestazioni'][1] - righe['attestazioni'][0]
    # le voci straniere nuove con una glossa inglese: per il sito italiano vanno tradotte (una riga di glossa ciascuna)
    da_tradurre = sum(1 for k in nuove if d_less[k][1] != 'it' and not vuoto(d_less[k][7]))
    base = mb(len(nuove) * BYTE['lessema'] + d_ip * BYTE['ipotesi'] + d_rel * (BYTE['relazione'] + BYTE['mv_famiglia'])
              + d_att * BYTE['attestazione'])
    con_glosse = base + mb(da_tradurre * BYTE['glossa'])
    print(f'voci: {len(p_less)} → {len(d_less)} (+{len(nuove)}, −{len(tolte)}); ipotesi {d_ip:+}; passaggi {d_rel:+}; '
          f'attestazioni {d_att:+}')
    print(f'spazio in più: {base:.0f} MB senza glosse tradotte, {con_glosse:.0f} MB con le glosse italiane di {da_tradurre} voci')
    if attuale is not None:
        print(f'database: {attuale:.0f} MB → {attuale + base:.0f}–{attuale + con_glosse:.0f} MB (piano Launch di Neon: lo spazio si paga a consumo)')
    per = Counter(d_less[k][1] for k in nuove) - Counter(p_less[k][1] for k in tolte)
    print('voci nuove per lingua:', ', '.join(f'{l} {n}' for l, n in per.most_common(15)))

    # le lingue si incontrano: famiglie con più lingue moderne, prestiti tra lingue moderne
    p_accolta, p_primo, _, p_archi, _ = grafo(prima_d)
    accolta, primo, etimi, archi, n_rel = grafo(dopo_d)
    # le voci senza etimologia (le radici escluse), per lingua: le lingue di chiusura nuove collegano quelle che c'erano già
    orfane = lambda less, acc: Counter(r[1] for k, r in less.items() if k not in acc and not r[2].endswith('-'))
    po, do = orfane(p_less, p_accolta), orfane(d_less, accolta)
    tot = Counter(r[1] for r in d_less.values())
    print(f'\nvoci senza etimologia: {sum(po.values())} → {sum(do.values())}; dove cambiano di più:',
          ', '.join(f'{l} {po[l]} → {do[l]} (su {tot[l]})' for l in sorted(po, key=lambda l: do[l] - po[l])[:20]))
    p_fam, d_fam = famiglie(p_less, p_primo), famiglie(d_less, primo)
    soglia = lambda f, n: sum(1 for v in f.values() if len(v) >= n)
    print(f'\nfamiglie con almeno 2 lingue moderne: {soglia(p_fam, 2)} → {soglia(d_fam, 2)}; con almeno 3: '
          f'{soglia(p_fam, 3)} → {soglia(d_fam, 3)}; con almeno 4: {soglia(p_fam, 4)} → {soglia(d_fam, 4)}')
    nome = lambda less, k: (lambda r: (f'{r[1]}:{r[2]}' + (f' ({r[3]})' if r[3] not in ('1', '', '\\N') else '')) if r else k)(less.get(k))
    larghe = sorted(d_fam.items(), key=lambda x: (-len(x[1]), x[0]))[:8]
    print('  le più larghe:', '; '.join(f"{nome(d_less, k)} ({', '.join(sorted(v))})" for k, v in larghe))
    def prestiti(less, ar):
        c = Counter()
        for esito, etimo in ar:
            a, b = (less.get(etimo) or ['', ''])[1], (less.get(esito) or ['', ''])[1]
            if a in MODERNE and b in MODERNE and a != b:
                c[f'{a}→{b}'] += 1
        return c
    pp, dp = prestiti(p_less, p_archi), prestiti(d_less, archi)
    print(f'prestiti tra lingue moderne: {sum(pp.values())} → {sum(dp.values())};',
          ', '.join(f'{k} {v}' for k, v in (dp - pp).most_common(14)))

    def costo(k):
        n_ip = 1 if k in accolta else 0
        return BYTE['lessema'] + n_ip * BYTE['ipotesi'] + n_rel[k] * (BYTE['relazione'] + BYTE['mv_famiglia'])
    def chiusura(chiavi):
        dentro, coda = set(chiavi), list(chiavi)
        while coda:
            for e in etimi.get(coda.pop(), ()):
                if e not in dentro and e not in p_less and e in d_less:
                    dentro.add(e)
                    coda.append(e)
        return dentro

    for lingua in lingue:
        voci = [r for r in d_less.values() if r[1] == lingua]
        proprie = [r for r in voci if r[0] not in p_less]
        print(f'\n{lingua}: {len(voci)} voci ({len(proprie)} nuove); con un\'etimologia {sum(r[0] in accolta for r in voci)}; '
              f'nomi propri {sum(r[6] == "np" for r in voci)}; locuzioni {sum(" " in r[2] for r in voci)}; '
              f'traslitterate {sum(not vuoto(r[5]) for r in voci)}')
        print('  per parte del discorso:', dict(Counter(r[6] if not vuoto(r[6]) else '?' for r in voci).most_common(10)))
        con = [r[0] for r in proprie if r[0] in primo]
        cime = [catena(primo, k)[-1] for k in con]
        gia = sum(1 for c in cime if c in p_less)
        miste = sum(1 for c in cime if len(d_fam.get(c, ())) >= 2)
        print(f'  delle {len(con)} catene nuove: {gia} ({100 * gia / max(len(con), 1):.0f}%) arrivano in una famiglia che '
              f'c\'è già; {miste} ({100 * miste / max(len(con), 1):.0f}%) in una famiglia con altre lingue moderne')
        print('  lingua della cima:', dict(Counter((d_less.get(c) or ['', '?'])[1] for c in cime).most_common(10)))
        print('  lingua del primo etimo:', dict(Counter((d_less.get(primo[k]) or ['', '?'])[1] for k in con).most_common(10)))
        comune = lambda r: r[6] != 'np' and ' ' not in r[2]
        fuori = lambda r: r[0] in primo and (d_less.get(primo[r[0]]) or ['', lingua])[1] != lingua
        # «in una famiglia»: la catena accolta arriva a una cima che il dizionario ha già (la regola delle lingue classiche)
        in_famiglia = lambda r: r[0] in primo and catena(primo, r[0])[-1] in p_less
        ambiti = [('tutte', proprie), ('senza nomi propri né locuzioni', [r for r in proprie if comune(r)]),
                  ('con un\'etimologia, senza nomi propri né locuzioni', [r for r in proprie if comune(r) and r[0] in primo]),
                  ('in una famiglia che c\'è già, senza nomi propri né locuzioni', [r for r in proprie if comune(r) and in_famiglia(r)]),
                  ('etimo fuori dalla lingua, senza nomi propri né locuzioni', [r for r in proprie if comune(r) and fuori(r)])]
        if lingua in freq:
            ambiti.append((f'lessico comune ({len(freq[lingua])} forme)', [r for r in proprie if comune(r) and r[2].lower() in freq[lingua]]))
            ambiti.append(('lessico comune ed etimo fuori', [r for r in proprie if comune(r) and (fuori(r) or r[2].lower() in freq[lingua])]))
        print(f'  ambiti (voci della lingua + voci portate dalle catene = spazio):')
        for nome_a, rr in ambiti:
            c = chiusura([r[0] for r in rr])
            print(f'    {nome_a}: {len(rr)} + {len(c) - len(rr)} = {mb(sum(costo(k) for k in c)):.0f} MB')
        print('  campione di catene:')
        for k in random.Random(1).sample(con, min(20, len(con))):
            print('    ' + ' < '.join(nome(d_less, x) for x in catena(primo, k)))
