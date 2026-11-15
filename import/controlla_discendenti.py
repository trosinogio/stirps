#!/usr/bin/env python3
"""I discendenti dichiarati da Wiktionary: quanto concordano con le etimologie che abbiamo già?

Le pagine delle radici, delle protolingue e delle parole latine e greche elencano i loro discendenti ramo per ramo
(sezione «Descendants»; filtra.py con DISCENDENTI li scrive, una riga per nodo). Ogni nodo dell'albero dice: questa
parola viene da quella che le sta sopra. Prima di usarli per dare un'etimologia alle parole che non ne hanno, si
misurano (un'analisi automatica si misura prima di usarla): dove la parola ha già la sua etimologia accolta, quante
volte l'albero dei discendenti dice la stessa cosa?

    python3 controlla_discendenti.py dati/it/tsv 'dati/*/discendenti.tsv' [archi.tsv]

Per ogni arco dell'albero (genitore → figlio), l'esito:
- «concorde, diretto»: il genitore è l'etimo della parola nella catena accolta;
- «concorde, più su»: il genitore è un antenato nella catena (l'albero salta un passaggio, o la catena ne ha uno in più);
- «concorde, stessa famiglia»: la catena accolta non passa dal genitore, ma i due hanno un antenato in comune (l'albero
  cita un'altra grafia o un altro passaggio della stessa parola: enm rolle < fro role, e noi fro rolle);
- «rovesciato»: nella nostra catena è il genitore a discendere dal figlio;
- «diverso»: la parola ha un'etimologia accolta che non passa dal genitore;
- «nuovo»: la parola c'è e non ha etimologia: l'arco che i discendenti potrebbero dare;
- «figlio assente», «genitore assente»: una delle due parole non è nel dizionario.
La misura è concordi / (concordi + rovesciati + diversi), in tutto, per segno dell'arco (ereditato, prestito, derivato,
incerto) e per lingua del figlio. archi.tsv: gli archi «nuovo» e «diverso», per guardarli a mano.
"""
import glob
import os
import random
import sys
from collections import Counter, defaultdict

from wiktionary import codice_lingua, nome_pagina


def leggi(percorso):
    apri = open
    if not os.path.exists(percorso) and os.path.exists(percorso + '.gz'):
        import gzip
        percorso, apri = percorso + '.gz', gzip.open
    with apri(percorso, 'rt', encoding='utf-8') as f:
        for r in f:
            yield r.rstrip('\n').split('\t')


def main():
    tsv = sys.argv[1]
    per_pagina = defaultdict(list)          # (lingua, pagina) → chiavi (una per omografo)
    for c in leggi(os.path.join(tsv, 'lessemi.tsv')):
        # il lemma di una forma ricostruita sta senza asterisco: qui lo riprende, come nelle citazioni
        per_pagina[(c[1], ('*' if c[4] == 't' and not c[2].startswith('*') else '') + c[2])].append(c[0])
    accolte = {c[0] for c in leggi(os.path.join(tsv, 'ipotesi.tsv')) if c[3] == 'accolta'}
    etimi = defaultdict(set)
    for c in leggi(os.path.join(tsv, 'relazioni.tsv')):
        if c[1] in accolte:
            etimi[c[2]].add(c[3])

    def antenati(k, limite=12):
        visti, giro = set(), {k}
        for _ in range(limite):
            giro = {e for x in giro for e in etimi.get(x, ())} - visti
            if not giro:
                break
            visti |= giro
        return visti

    def chiavi(lingua, parola, omografo=None):
        lingua = codice_lingua(lingua)
        parola = parola.strip()
        if lingua.endswith('-pro') and not parola.startswith('*'):
            parola = '*' + parola
        ks = per_pagina.get((lingua, nome_pagina(lingua, parola)), [])
        if omografo and len(ks) > 1:
            precisa = [k for k in ks if k.endswith(f':{omografo}')] if omografo > 1 else [k for k in ks if k.count(':') == 2]
            ks = precisa or ks
        return ks

    esiti, per_segno, per_lingua, per_lingua_gen = Counter(), defaultdict(Counter), defaultdict(Counter), defaultdict(Counter)
    esempi = defaultdict(list)
    righe = pagine = 0
    visti = set()
    for percorso in sorted(glob.glob(sys.argv[2])):
        lingua_pagina = os.path.basename(os.path.dirname(percorso))
        pila, corrente = [], None
        for c in leggi(percorso):
            if len(c) < 7:
                continue
            righe += 1
            # il numero dell'etimologia può avere una sottovoce («1.1»): vale la parte intera
            parola, ric, prof, lf, pf, segni = c[0], c[2], int(c[3] or 1), c[4], c[5], c[6]
            omo = int(c[1].split('.')[0]) if c[1].split('.')[0].isdigit() else 1
            if (parola, omo) != corrente:
                corrente, pagine = (parola, omo), pagine + 1
                pila = [(0, lingua_pagina, ('*' if ric and not parola.startswith('*') else '') + parola, omo)]
            while pila and pila[-1][0] >= prof:
                pila.pop()
            if not pila:
                continue
            _, lg, pg, og = pila[-1]
            if not pf.strip():
                pila.append((prof, lg, pg, og))    # il nome di un ramo: ciò che gli sta sotto discende dal nodo sopra
                continue
            pila.append((prof, lf, pf, None))
            arco = (lg, pg, lf, pf)
            if arco in visti or (codice_lingua(lg), pg) == (codice_lingua(lf), pf):
                continue
            visti.add(arco)
            kg, kf = chiavi(lg, pg, og), chiavi(lf, pf)
            segno = 'incerto' if 'unc' in segni else 'prestito' if any(s in segni for s in ('bor', 'lbor', 'slb')) \
                else 'derivato' if 'der' in segni else 'calco' if 'clq' in segni else 'ereditato'
            if not kf:
                esito = 'figlio assente'
            elif not kg:
                esito = 'genitore assente'
            else:
                dirette = {e for k in kf for e in etimi.get(k, ())}
                if not dirette:
                    esito = 'nuovo'
                elif dirette & set(kg):
                    esito = 'concorde, diretto'
                elif set(kg) & {a for k in kf for a in antenati(k)}:
                    esito = 'concorde, più su'
                elif set(kf) & {a for k in kg for a in antenati(k)}:
                    esito = 'rovesciato'
                elif {a for k in kf for a in antenati(k)} & {a for k in kg for a in antenati(k)}:
                    esito = 'concorde, stessa famiglia'
                else:
                    esito = 'diverso'
            esiti[esito] += 1
            per_segno[segno][esito] += 1
            per_lingua[codice_lingua(lf)][esito] += 1
            per_lingua_gen[codice_lingua(lg)][esito] += 1
            if esito in ('nuovo', 'diverso', 'rovesciato'):
                ora = ', '.join(sorted({e.split(':', 1)[1] for k in kf for e in etimi.get(k, ())})[:3])
                esempi[esito].append((lg, pg, lf, pf, segno, ora))

    def misura(c):
        si = c['concorde, diretto'] + c['concorde, più su'] + c['concorde, stessa famiglia']
        no = c['rovesciato'] + c['diverso']
        return f"{si / max(1, si + no):.0%} su {si + no}"

    print(f'discendenti dichiarati: {pagine} pagine, {righe} righe, {sum(esiti.values())} archi distinti; '
          f'dove la parola ha già un\'etimologia l\'albero concorda nel {misura(esiti)} (diretto {esiti["concorde, diretto"]}, '
          f'più su {esiti["concorde, più su"]}, nella stessa famiglia per altra via {esiti["concorde, stessa famiglia"]}, diverso {esiti["diverso"]}, rovesciato {esiti["rovesciato"]}); '
          f'archi nuovi possibili {esiti["nuovo"]}; figlio assente {esiti["figlio assente"]}, genitore assente {esiti["genitore assente"]}')
    print('per segno dell\'arco: ' + '; '.join(f'{s} {misura(c)}, nuovi {c["nuovo"]}' for s, c in sorted(per_segno.items())))
    for titolo, tab in (('per lingua del figlio', per_lingua), ('per lingua del genitore', per_lingua_gen)):
        print(titolo + ' (concordanza, nuovi, figlio assente):')
        for l, c in sorted(tab.items(), key=lambda x: -(x[1]['nuovo'] + x[1]['concorde, diretto'] + x[1]['diverso']))[:30]:
            print(f'  {l}: {misura(c)}, nuovi {c["nuovo"]}, assenti {c["figlio assente"]}')
    caso = random.Random(13)
    for esito in ('diverso', 'rovesciato', 'nuovo'):
        print(f'{esito}, un campione a caso:')
        for lg, pg, lf, pf, segno, ora in caso.sample(esempi[esito], min(40, len(esempi[esito]))):
            print(f'  {lf} {pf} < {lg} {pg} ({segno})' + (f'; ora: {ora}' if ora else ''))
    greci = [e for e in esempi['nuovo'] if 'grc' in (e[0], e[2])]
    print(f'nuovi con il greco antico da una parte: {len(greci)}')
    for lg, pg, lf, pf, segno, ora in caso.sample(greci, min(30, len(greci))):
        print(f'  {lf} {pf} < {lg} {pg} ({segno})')
    if len(sys.argv) > 3:
        with open(sys.argv[3], 'w', encoding='utf-8') as f:
            for esito in ('nuovo', 'diverso', 'rovesciato'):
                for e in esempi[esito]:
                    f.write('\t'.join((esito,) + e) + '\n')


if __name__ == '__main__':
    main()
