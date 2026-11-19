#!/usr/bin/env python3
"""Le parole semitiche e le loro radici: quante arrivano al protosemitico, e che cosa potrebbe portarcele.

Le voci arabe, ebraiche e aramaiche dichiarano la loro radice ({{ar-root}}, {{he-root}}), e radice_semitica() in
filtra.py ne fa un passaggio di derivazione: la catena si ferma lì, a ك ت ب o כ־ת־ב, se la pagina non dà anche un
etimo storico (كَلْب < *kalb-). Due fonti di Wiktionary possono portarla oltre, e qui si misurano prima di usarle:

1. i discendenti dichiarati dalle pagine protosemitiche (*kalb- → Arabic كَلْب, Hebrew כֶּלֶב): per ogni figlio semitico,
   se ha già l'etimo, se l'ha solo dalla radice, se non ne ha; e dove ha un etimo storico, quante volte l'albero concorda;
2. le radici corrispondenti dichiarate dalle pagine delle radici («ש־ל־ם: From Proto-Semitic *š-l-m. Cognate with Arabic
   root س ل م», RADICI_CORRISPONDENTI di filtra.py): quante radici con un etimo protosemitico dichiarano la radice di
   un'altra lingua, e se quella radice c'è e ha già un etimo.

    python3 controlla_semitico.py dati/it/tsv 'dati/*/discendenti.tsv' 'dati/*/radici_corrispondenti.tsv'
"""
import glob
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wiktionary import codice_lingua, nome_pagina      # noqa: E402
from controlla_discendenti import leggi                  # noqa: E402

SEMITICHE = {'ar', 'he', 'hbo', 'arc', 'syc', 'akk', 'uga', 'phn', 'mt', 'am', 'gez', 'tmr', 'jpa'}
PROTO = {'sem-pro', 'sem-wes-pro'}
RADICE = re.compile(r'^\S( \S)+$|^\S(־\S)+$')      # ك ت ب, כ־ת־ב


def main():
    tsv = sys.argv[1]
    lemma, per_pagina = {}, defaultdict(list)
    for c in leggi(os.path.join(tsv, 'lessemi.tsv')):
        lemma[c[0]] = (c[1], c[2])
        per_pagina[(c[1], ('*' if c[4] == 't' and not c[2].startswith('*') else '') + c[2])].append(c[0])
    accolte = {c[0] for c in leggi(os.path.join(tsv, 'ipotesi.tsv')) if c[3] == 'accolta'}
    etimi = defaultdict(set)
    for c in leggi(os.path.join(tsv, 'relazioni.tsv')):
        if c[1] in accolte:
            etimi[c[2]].add(c[3])

    def radice(k):
        return bool(RADICE.match(lemma.get(k, ('', ''))[1]))

    def cima(k):
        visti = {k}
        while True:
            su = sorted(etimi.get(k, ()) - visti)
            if not su:
                return k
            k = su[0]
            visti.add(k)

    def antenati(k):
        visti, giro = set(), {k}
        for _ in range(15):
            giro = {e for x in giro for e in etimi.get(x, ())} - visti
            if not giro:
                break
            visti |= giro
        return visti

    def chiavi(lingua, parola):
        lingua = codice_lingua(lingua)
        parola = parola.strip()
        if lingua.endswith('-pro') and not parola.startswith('*'):
            parola = '*' + parola
        return per_pagina.get((lingua, nome_pagina(lingua, parola)), [])

    # quante parole semitiche arrivano oggi al protosemitico, e dove si fermano
    print('dove si fermano le catene semitiche (lingua della cima, per lingua della parola):')
    for L in ('ar', 'he', 'arc', 'syc', 'akk'):
        ks = [k for k, (l, w) in lemma.items() if l == L and not RADICE.match(w)]
        cime = Counter()
        for k in ks:
            if etimi.get(k):
                c = cima(k)
                cime['radice della lingua' if radice(c) and lemma[c][0] == L else lemma.get(c, ('?',))[0]] += 1
            else:
                cime['senza etimologia'] += 1
        print(f'  {L}: {len(ks)} parole; ' + ', '.join(f'{x} {n}' for x, n in cime.most_common(8)))

    # 1. i discendenti dichiarati dalle pagine protosemitiche
    esiti, per_lingua, esempi = Counter(), defaultdict(Counter), defaultdict(list)
    visti = set()
    for percorso in sorted(glob.glob(sys.argv[2])):
        lingua_pagina = os.path.basename(os.path.dirname(percorso))
        if lingua_pagina not in PROTO:
            continue
        pila, corrente = [], None
        for c in leggi(percorso):
            if len(c) < 7:
                continue
            parola, ric, prof, lf, pf = c[0], c[2], int(c[3] or 1), c[4], c[5]
            if parola != corrente:
                corrente, pila = parola, [(0, lingua_pagina, ('*' if not parola.startswith('*') else '') + parola)]
            while pila and pila[-1][0] >= prof:
                pila.pop()
            if not pila:
                continue
            _, lg, pg = pila[-1]
            if not pf.strip():
                pila.append((prof, lg, pg))
                continue
            pila.append((prof, lf, pf))
            if codice_lingua(lf) not in SEMITICHE or (lg, pg, lf, pf) in visti:
                continue
            visti.add((lg, pg, lf, pf))
            kg, kf = chiavi(lg, pg), chiavi(lf, pf)
            if not kf:
                esito = 'figlio assente'
            elif not kg:
                esito = 'genitore assente'
            else:
                dirette = {e for k in kf for e in etimi.get(k, ())}
                if not dirette:
                    esito = 'senza etimologia'
                elif all(radice(e) for e in dirette):
                    esito = 'solo la radice'
                elif dirette & set(kg) or set(kg) & {a for k in kf for a in antenati(k)}:
                    esito = 'concorde'
                else:
                    esito = 'diverso'
            esiti[esito] += 1
            per_lingua[codice_lingua(lf)][esito] += 1
            if len(esempi[esito]) < 12 and esito in ('solo la radice', 'diverso', 'senza etimologia'):
                ora = ', '.join(sorted(lemma.get(e, ('', e))[1] for k in kf for e in etimi.get(k, ()))[:2])
                esempi[esito].append(f'{lf}:{pf} < {lg}:{pg}' + (f' (ora: {ora})' if ora else ''))
    conc, div = esiti['concorde'], esiti['diverso']
    print(f'discendenti delle pagine protosemitiche: {dict(esiti)}; dove la parola ha un etimo storico l\'albero '
          f'concorda nel {100 * conc / max(1, conc + div):.0f}% su {conc + div}')
    for L, c in sorted(per_lingua.items(), key=lambda x: -sum(x[1].values())):
        print(f'  {L}: {dict(c)}')
    for e, xs in esempi.items():
        print(f'  esempi, {e}: ' + ' · '.join(xs))

    # 2. le radici corrispondenti dichiarate
    corr = []
    for percorso in sorted(glob.glob(sys.argv[3])):
        la = os.path.basename(os.path.dirname(percorso))      # la lingua della pagina della radice
        for c in leggi(percorso):
            if len(c) >= 3:
                corr.append((la, c[0], c[1], c[2]))
    conti, esempi_c = Counter(), []
    for la, ra, lb, rb in dict.fromkeys(corr):
        conti['dichiarate'] += 1
        ka, kb = chiavi(la, ra), chiavi(lb, rb)
        et_a = {e for k in ka for e in etimi.get(k, ())}
        proto_a = {e for e in et_a if lemma.get(e, ('',))[0] in PROTO}
        if not proto_a:
            conti['la radice dichiarante non ha un etimo protosemitico'] += 1
            continue
        conti['con un etimo protosemitico'] += 1
        if not kb:
            conti['… e la radice corrispondente non c\'è'] += 1
            continue
        et_b = {e for k in kb for e in etimi.get(k, ())}
        if not et_b:
            conti['… e la radice corrispondente c\'è, senza etimo: l\'arco nuovo'] += 1
            if len(esempi_c) < 15:
                esempi_c.append(f'{lb}:{rb} < {lemma[sorted(proto_a)[0]][1]} (da {la}:{ra})')
        elif et_b & proto_a:
            conti['… e la radice corrispondente ha già lo stesso etimo'] += 1
        else:
            conti['… e la radice corrispondente ha un altro etimo'] += 1
    print(f'radici corrispondenti dichiarate: {dict(conti)}')
    if esempi_c:
        print('  archi nuovi possibili: ' + ' · '.join(esempi_c))


if __name__ == '__main__':
    main()
