#!/usr/bin/env python3
"""Il campo di senso delle radici (dati/campi_radici.tsv.gz, lotto «campi» di definisci.py): le parole chiave con cui
si controlla che una parola stia nella famiglia giusta (*h₃ekʷ- «eye, face, look, glance, show, sight»: ὄψις «sight»
sì, sotto *wekʷ- «speak, say, voice» no). Prima di usarlo si misura sul pacchetto:
- per le parole a uno e a due passaggi dalla radice, quante stanno nel suo campo (una parola piena in comune con la
  glossa inglese), quante nella sola glossa della radice, e quante nel campo di una radice presa a caso;
- e sono scritte le parole a un passaggio fuori dal campo, da guardare.

    python3 controlla_campi.py lessemi.tsv ipotesi.tsv relazioni.tsv campi_radici.tsv [fuori_dal_campo.tsv]

Il rapporto va sullo standard error; fuori_dal_campo.tsv: chiave della parola, chiave della radice, glossa, campo.
"""
import random, sys
from collections import Counter, defaultdict

from controlla_sensi import legate, parole, righe


def main():
    lessemi_p, ipotesi_p, relazioni_p, campi_p = sys.argv[1:5]
    uscita = sys.argv[5] if len(sys.argv) > 5 else None
    campo, testo = {}, {}
    for c in righe(campi_p):
        if len(c) > 2 and parole(c[2]):
            campo[c[0]], testo[c[0]] = parole(c[2]), c[2]
    glossa = {}
    for c in righe(lessemi_p):
        if len(c) > 7 and c[7] not in ('', '\\N'):
            glossa[c[0]] = c[7]
    accolte = {c[0] for c in righe(ipotesi_p) if len(c) > 3 and c[3] == 'accolta'}
    figli = defaultdict(set)
    for c in righe(relazioni_p):
        if len(c) > 4 and c[1] in accolte:
            figli[c[3]].add(c[2])
    rnd = random.Random(20)
    radici = sorted(campo)
    conta = Counter()
    fuori = []
    for r in radici:
        vicini = [(1, f) for f in figli.get(r, ())]
        vicini += [(2, n) for _, f in list(vicini) for n in figli.get(f, ())]
        pr = parole(glossa.get(r, ''))
        for passi, k in vicini:
            pk = parole(glossa.get(k, ''))
            if not pk:
                continue
            conta[passi, 'parole'] += 1
            nel = legate(pk, campo[r])
            conta[passi, 'nel_campo'] += nel
            conta[passi, 'nella_glossa'] += bool(pr) and legate(pk, pr)
            conta[passi, 'a_caso'] += legate(pk, campo[rnd.choice(radici)])
            if passi == 1 and not nel:
                fuori.append((k, r, glossa.get(k, ''), testo[r]))
    print(f'campi di senso: {len(campo)} radici', file=sys.stderr)
    for passi in (1, 2):
        n = conta[passi, 'parole'] or 1
        print(f'  a {passi} passaggi dalla radice: {conta[passi, "parole"]} parole con una glossa; nel campo '
              f'{conta[passi, "nel_campo"] / n:.0%}, nella sola glossa della radice {conta[passi, "nella_glossa"] / n:.0%}, '
              f'nel campo di una radice a caso {conta[passi, "a_caso"] / n:.1%}', file=sys.stderr)
    print(f'parole a un passaggio fuori dal campo: {len(fuori)}', file=sys.stderr)
    for k, r, g, t in fuori[:25]:
        print(f'  {k} «{g[:40]}» < {r} «{t[:50]}»', file=sys.stderr)
    if uscita:
        with open(uscita, 'w', encoding='utf-8') as f:
            for riga in fuori:
                f.write('\t'.join(x.replace('\t', ' ') for x in riga) + '\n')


if __name__ == '__main__':
    main()
