#!/usr/bin/env python3
"""Stima di un import prima di farlo: confronta il pacchetto dati nuovo con quello di prima, conta le righe nuove e ne
calcola lo spazio nel database con i byte per riga misurati sul database vero; per una lingua mostra che voci entrano
e un campione di catene da guardare a mano.

    python3 stima_import.py prima/ dati/ en --attuale 349     # cartelle con lessemi, ipotesi, relazioni… .tsv.gz

I byte per riga, indici compresi (pg_total_relation_size / righe), sono quelli del database del 6 novembre 2026:
290 mila voci, 349 MB. Si rimisurano quando cambia lo schema.
"""
import gzip, os, random, sys
from collections import Counter

BYTE = {'lessema': 510, 'ipotesi': 425, 'relazione': 355, 'mv_famiglia': 100, 'glossa': 340, 'attestazione': 336}
LIMITE_MB = 512          # il piano gratuito di Neon


def leggi(d, nome):
    p = os.path.join(d, f'{nome}.tsv.gz')
    if not os.path.exists(p):
        return []
    with gzip.open(p, 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def vuoto(x):
    return x in ('', '\\N')


if __name__ == '__main__':
    prima_d, dopo_d, lingua = sys.argv[1], sys.argv[2], sys.argv[3]
    attuale = float(sys.argv[sys.argv.index('--attuale') + 1]) if '--attuale' in sys.argv else None
    p_less, d_less = {r[0]: r for r in leggi(prima_d, 'lessemi')}, {r[0]: r for r in leggi(dopo_d, 'lessemi')}
    nuove = [k for k in d_less if k not in p_less]
    tolte = [k for k in p_less if k not in d_less]
    righe = {n: (len(leggi(prima_d, n)), len(leggi(dopo_d, n))) for n in ('ipotesi', 'relazioni', 'attestazioni')}
    d_ip = righe['ipotesi'][1] - righe['ipotesi'][0]
    d_rel = righe['relazioni'][1] - righe['relazioni'][0]
    d_att = righe['attestazioni'][1] - righe['attestazioni'][0]
    # le voci straniere nuove con una glossa inglese: per il sito italiano vanno tradotte (una riga di glossa ciascuna)
    da_tradurre = sum(1 for k in nuove if d_less[k][1] != 'it' and not vuoto(d_less[k][7]))
    mb = lambda b: b / 1024 / 1024
    base = mb(len(nuove) * BYTE['lessema'] + d_ip * BYTE['ipotesi'] + d_rel * (BYTE['relazione'] + BYTE['mv_famiglia'])
              + d_att * BYTE['attestazione'])
    con_glosse = base + mb(da_tradurre * BYTE['glossa'])
    print(f'voci: {len(p_less)} → {len(d_less)} (+{len(nuove)}, −{len(tolte)}); ipotesi {d_ip:+}; passaggi {d_rel:+}; '
          f'attestazioni {d_att:+}')
    print(f'spazio in più: {base:.0f} MB senza glosse tradotte, {con_glosse:.0f} MB con le glosse italiane di {da_tradurre} voci')
    if attuale is not None:
        print(f'database: {attuale:.0f} MB → {attuale + base:.0f}–{attuale + con_glosse:.0f} MB (limite del piano gratuito {LIMITE_MB} MB)')
    per = Counter(d_less[k][1] for k in nuove) - Counter(p_less[k][1] for k in tolte)
    print('voci nuove per lingua:', ', '.join(f'{l} {n}' for l, n in per.most_common(15)))

    # la lingua esaminata: che voci entrano
    voci = [r for r in d_less.values() if r[1] == lingua]
    accolta = {}
    for h in leggi(dopo_d, 'ipotesi'):
        if h[3] == 'accolta':
            accolta[h[1]] = h[0]
    print(f'\n{lingua}: {len(voci)} voci; con un\'etimologia {sum(r[0] in accolta for r in voci)}; '
          f'nomi propri {sum(r[6] == "np" for r in voci)}; locuzioni (più parole) {sum(" " in r[2] for r in voci)}; '
          f'con trattino {sum("-" in r[2].strip("-") for r in voci)}; ricostruite {sum(r[4] == "t" for r in voci)}')
    print('  per parte del discorso:', dict(Counter(r[6] if not vuoto(r[6]) else '?' for r in voci).most_common(12)))
    # dove arrivano le catene: la lingua della cima (primo etimo a ogni passo)
    primo = {}
    for r in leggi(dopo_d, 'relazioni'):
        if r[1] in accolta.values():
            o = int(r[5]) if r[5].isdigit() else 99
            if r[2] not in primo or o < primo[r[2]][1]:
                primo[r[2]] = (r[3], o)
    def catena(k):
        passi, visti = [k], {k}
        while k in primo and primo[k][0] not in visti and len(passi) < 12:
            k = primo[k][0]; passi.append(k); visti.add(k)
        return passi
    def nome(k):
        r = d_less.get(k)
        return f'{r[1]}:{r[2]}' if r else k
    con = [r[0] for r in voci if r[0] in primo]
    cime = Counter((d_less.get(catena(k)[-1]) or ['', '?'])[1] for k in con)
    print(f'  lingua della cima delle {len(con)} catene:', dict(cime.most_common(12)))
    lunghezze = Counter(min(len(catena(k)) - 1, 6) for k in con)
    print('  passaggi per catena (6 = sei o più):', dict(sorted(lunghezze.items())))
    # gli ambiti possibili: quante voci della lingua e quanto spazio, togliendo nomi propri, locuzioni, formazioni interne
    # (il primo etimo è una parola della stessa lingua: doghouse < dog + house). Le voci nuove delle altre lingue (le
    # chiusure: inglese medio e antico, protogermanico…) servono a tutti gli ambiti e si contano a parte.
    n_ip, n_rel, etimo1 = Counter(), Counter(), {}
    for h in leggi(dopo_d, 'ipotesi'):
        n_ip[h[1]] += 1
    for r in leggi(dopo_d, 'relazioni'):
        n_rel[r[2]] += 1
    for k, (e, _) in primo.items():
        etimo1[k] = (d_less.get(e) or ['', '?'])[1]
    gia = {k for k in p_less}
    proprie = [r for r in voci if r[0] not in gia]
    def costo(rr):
        return mb(sum(BYTE['lessema'] + n_ip[r[0]] * BYTE['ipotesi'] + n_rel[r[0]] * (BYTE['relazione'] + BYTE['mv_famiglia'])
                      for r in rr))
    ambiti = [('tutte', proprie),
              ('senza nomi propri', [r for r in proprie if r[6] != 'np']),
              ('senza nomi propri né locuzioni', [r for r in proprie if r[6] != 'np' and ' ' not in r[2]]),
              ('solo con l\'etimo fuori dalla lingua', [r for r in proprie if etimo1.get(r[0], lingua) != lingua]),
              ('etimo fuori, senza nomi propri né locuzioni',
               [r for r in proprie if etimo1.get(r[0], lingua) != lingua and r[6] != 'np' and ' ' not in r[2]])]
    altre = [k for k in nuove if d_less[k][1] != lingua]
    print(f'\nambiti per {lingua} (voci nuove; più {len(altre)} voci nuove di altre lingue, circa '
          f'{mb(len(altre) * (BYTE["lessema"] + BYTE["ipotesi"] + BYTE["relazione"] + BYTE["mv_famiglia"])):.0f} MB):')
    for nome_a, rr in ambiti:
        print(f'  {nome_a}: {len(rr)} voci, {costo(rr):.0f} MB')
    print('  lingua del primo etimo:', dict(Counter(etimo1.get(r[0], '—') for r in proprie).most_common(10)))

    print('\ncampione di catene (da guardare a mano prima di pubblicare):')
    for k in random.Random(1).sample(con, min(40, len(con))):
        print('  ' + ' < '.join(nome(x) for x in catena(k)))
