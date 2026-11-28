#!/usr/bin/env python3
"""Stima dei lemmi di una lingua che il dizionario non ha (richiesta di Giovanni del 22 novembre 2026, per l'inglese:
«aeration è senza etimologia, è chiaro che derivi dal latino aer»). Dai file del filtro della lingua (glosse.tsv: tutti i
lemmi; lemmi.jsonl: quelli con un'etimologia) e dal pacchetto, conta i lemmi comuni (niente nomi propri, locuzioni,
cifre) che mancano, in tre gruppi:
- con un'etimologia il cui primo etimo è già una voce del dizionario (abolitionist < abolition);
- senza etimologia, ma derivati trasparenti di una voce della lingua che c'è già, o che entra con il gruppo di sopra
  (aeration < aerate): le regole di
  suffisso e di prefisso di apprendi_derivati.py, imparate dalle coppie parola–base che le pagine dichiarano
  ({{af|en|aerate|-ion}}) e misurate sul 20% tenuto da parte (la base prevista è quella dichiarata);
- gli altri: con un etimo fuori dal dizionario, o senza niente.
Per ogni gruppo lo spazio stimato e un campione da guardare.

    python3 stima_derivati.py lingua dati/<lingua>/glosse.tsv dati/<lingua>/lemmi.jsonl lessemi.tsv.gz [frequenze.tsv.gz]
        [--scrivi derivati.tsv] [--scrivi-etimi etimi.tsv]

Il rapporto va sullo standard output. Con --scrivi, i derivati trasparenti (parola, base, affisso) per l'import
(importa.sh, DERIVATI=en): il parser fa entrare la parola (--derivati) e l'etimologia è un'analisi della forma. Con
--scrivi-etimi, le voci con un etimo nel dizionario (parola, etimo): il parser le fa entrare (--in-famiglia) con la
loro etimologia. In tutti e due gli elenchi niente varianti («alternative form of», VARIANTI).
"""
import gzip, json, random, sys, zlib
from collections import Counter, defaultdict

from apprendi_derivati import MAX_SUFFISSO, MIN_RADICE, nudo, parola, regole_della_coppia

# byte per voce nel database (stima_import.py): voce, ipotesi, un passaggio, la famiglia, la glossa italiana
BYTE_VOCE = 510 + 425 + 355 + 100 + 340
SUPPORTO, ESATTEZZA = 10, 0.85
# le glosse delle grafie e delle forme di un'altra parola: non sono voci nuove da far entrare
VARIANTI = ('alternative form of', 'alternative spelling of', 'misspelling of', 'obsolete form of', 'obsolete spelling of',
            'archaic form of', 'archaic spelling of', 'nonstandard spelling of', 'nonstandard form of', 'dated form of',
            'dated spelling of', 'eye dialect spelling of', 'pronunciation spelling of', 'synonym of', 'abbreviation of')


def apri(p):
    return gzip.open(p, 'rt', encoding='utf-8') if p.endswith('.gz') else open(p, encoding='utf-8')


def main():
    scrivi = sys.argv[sys.argv.index('--scrivi') + 1] if '--scrivi' in sys.argv else None
    scrivi_etimi = sys.argv[sys.argv.index('--scrivi-etimi') + 1] if '--scrivi-etimi' in sys.argv else None
    a = [x for i, x in enumerate(sys.argv) if not x.startswith('--') and sys.argv[i - 1] not in ('--scrivi', '--scrivi-etimi')]
    lingua, glosse_p, lemmi_p, lessemi_p = a[1:5]
    freq = set()
    if len(a) > 5:
        with apri(a[5]) as f:
            # dati/frequenze_<lingua>.tsv.gz: lingua, forma, rango, conteggio, fonte
            freq = {c[1].lower() for c in (r.split('\t') for r in f) if len(c) > 1}
    # le voci del dizionario: per la lingua, i lemmi; per tutte, (lingua, lemma)
    nel = set()
    della_lingua = set()
    with apri(lessemi_p) as f:
        for r in f:
            c = r.split('\t')
            if len(c) > 4 and c[4] == 'f':
                nel.add((c[1], c[2]))
                if c[1] == lingua:
                    della_lingua.add(c[2])
    # tutti i lemmi della lingua (glosse.tsv), una volta per lemma
    lemmi = {}
    with apri(glosse_p) as f:
        for r in f:
            c = r.rstrip('\n').split('\t')
            if len(c) > 5 and c[5] != '1' and parola(c[0]) and not c[3].lower().startswith(VARIANTI):
                lemmi.setdefault(c[0], (c[2], c[3]))
    # le etimologie: il primo etimo, e le coppie parola–base della lingua per imparare le regole
    primo, coppie = {}, {}
    with apri(lemmi_p) as f:
        for r in f:
            v = json.loads(r)
            w = v.get('w', '')
            for t in v.get('tpl') or []:
                n, a = t.get('n'), t.get('a') or {}
                if n in ('af', 'affix', 'suffix', 'prefix', 'compound'):
                    parti = [(a.get(str(i)) or '').strip() for i in range(2, 6)]
                    basi = [p for p in parti if p and not p.startswith('-') and not p.endswith('-')]
                    if len(basi) == 1 and parola(basi[0]):
                        coppie.setdefault(w, basi[0])
                        primo.setdefault(w, (lingua, basi[0]))
                    break
                if n in ('inh', 'bor', 'der', 'lbor', 'slbor', 'ubor', 'obor', 'bor+', 'inh+', 'der+', 'cal', 'calque'):
                    if a.get('2') and a.get('3'):
                        primo.setdefault(w, (a['2'].strip(), a['3'].strip().lstrip('*')))
                    break
    # le regole, dalle coppie dell'80% di addestramento; misurate sul 20%
    addestra = [w for w in coppie if zlib.crc32(w.encode()) % 5]
    prova = [w for w in coppie if not zlib.crc32(w.encode()) % 5]
    tutti = set(lemmi) | della_lingua
    cand = Counter(r for w in addestra for r in regole_della_coppia(w, coppie[w]))
    regole = {r for r, n in cand.items() if n >= SUPPORTO}
    per_nudo = defaultdict(list)
    for x in tutti:
        per_nudo[nudo(x)].append(x)

    def indice(ammesse):
        idx = defaultdict(list)
        for r in ammesse:
            idx[(r[0], r[1])].append(r)
        return idx

    def scatti(w, idx):
        n = nudo(w)
        out = []
        for i in range(1, min(MAX_SUFFISSO, len(n) - MIN_RADICE) + 1):
            for r in idx.get(('S', n[-i:]), []) + idx.get(('P', n[:i]), []):
                b = n[:-i] + r[2] if r[0] == 'S' else n[i:]
                if len(b) >= MIN_RADICE + 1 and 2 * len(b) >= len(n) and len(per_nudo.get(b, ())) == 1 and per_nudo[b][0] != w:
                    out.append((r, per_nudo[b][0]))
        return out
    idx_regole = indice(regole)
    misura = defaultdict(Counter)
    for w in addestra:
        for r, b in scatti(w, idx_regole):
            misura[r]['scatta'] += 1
            misura[r]['esatta'] += nudo(b) == nudo(coppie[w])
    buone = {r: m['esatta'] / m['scatta'] for r, m in misura.items() if m['scatta'] >= SUPPORTO and m['esatta'] >= ESATTEZZA * m['scatta']}

    idx_buone = indice(buone)

    def prevedi_regola(w):
        ss = [(buone[r], len(r[1]), b, r) for r, b in scatti(w, idx_buone)]
        return max(ss)[2:] if ss else (None, None)

    def prevedi(w):
        return prevedi_regola(w)[0]
    esatte = previste = 0
    for w in prova:
        b = prevedi(w)
        if b:
            previste += 1
            esatte += nudo(b) == nudo(coppie[w])
    print(f'{lingua}: {len(lemmi)} lemmi comuni nel filtro, {len(della_lingua)} voci nel dizionario; coppie parola–base dichiarate '
          f'{len(coppie)}; regole {len(buone)} (almeno {SUPPORTO} casi, {ESATTEZZA:.0%} esatte); prova sul 20% tenuto da parte: '
          f'{esatte} esatte su {previste} ({esatte / max(1, previste):.0%})')
    mancano = [w for w in lemmi if w not in della_lingua]
    gruppi = defaultdict(list)
    # prima le voci con un etimo nel dizionario: entrano con la loro etimologia, e possono fare da base a un derivato
    # (aeration < aerate, e aerate < latino aerātus); un livello solo, non a catena
    entrano = {w for w in mancano if primo.get(w) and (primo[w] in nel or (primo[w][0] == lingua and primo[w][1] in della_lingua))}
    for w in mancano:
        p = primo.get(w)
        if w in entrano:
            gruppi['con un etimo nel dizionario'].append((w, f'{p[0]}:{p[1]}'))
        elif w not in primo:
            b = prevedi(w)
            if b and (b in della_lingua or b in entrano):
                gruppi['senza etimologia, derivato trasparente di una voce che c\'è'].append((w, b))
            else:
                gruppi['senza etimologia, nient\'altro'].append((w, None))
        else:
            gruppi['con un etimo fuori dal dizionario'].append((w, f'{primo[w][0]}:{primo[w][1]}'))
    print(f'lemmi comuni che il dizionario non ha: {len(mancano)}')
    rnd = random.Random(22)
    for nome, vv in sorted(gruppi.items(), key=lambda x: -len(x[1])):
        comuni = sum(1 for w, _ in vv if w.lower() in freq) if freq else None
        print(f'  {nome}: {len(vv)} voci, circa {len(vv) * BYTE_VOCE / 1048576:.0f} MB'
              + (f'; nel lessico comune {comuni}' if comuni is not None else ''))
        print('    ' + '; '.join(f'{w} < {b}' if b else w for w, b in rnd.sample(vv, min(15, len(vv)))))
    if scrivi:
        with open(scrivi, 'w', encoding='utf-8') as out:
            for w, b in sorted(gruppi['senza etimologia, derivato trasparente di una voce che c\'è']):
                r = prevedi_regola(w)[1]
                affisso = '-' + w[len(w) - len(r[1]):] if r[0] == 'S' else w[:len(r[1])] + '-'
                out.write(f'{w}\t{b}\t{affisso}\n')
        print(f'scritti {len(gruppi["senza etimologia, derivato trasparente di una voce che c\'è"])} derivati in {scrivi}')
    if scrivi_etimi:
        with open(scrivi_etimi, 'w', encoding='utf-8') as out:
            for w, e in sorted(gruppi['con un etimo nel dizionario']):
                out.write(f'{w}\t{e}\n')
        print(f'scritte {len(gruppi["con un etimo nel dizionario"])} voci con un etimo nel dizionario in {scrivi_etimi}')


if __name__ == '__main__':
    main()
