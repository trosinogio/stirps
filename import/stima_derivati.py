#!/usr/bin/env python3
"""Stima dei lemmi di una lingua che il dizionario non ha (richiesta di Giovanni del 22 novembre 2026, per l'inglese:
«aeration è senza etimologia, è chiaro che derivi dal latino aer»). Dai file del filtro della lingua (glosse.tsv: tutti i
lemmi; lemmi.jsonl: quelli con un'etimologia) e dal pacchetto, conta i lemmi comuni (niente nomi propri, locuzioni,
cifre) che mancano, in tre gruppi:
- con un'etimologia il cui primo etimo è già una voce del dizionario (abolitionist < abolition), e i derivati
  dichiarati di una di queste (aeration = aerate + -ion, aerate < latino aerātus), un livello solo;
- senza etimologia, ma derivati trasparenti di una voce della lingua che c'è già, o che entra con il gruppo di sopra
  (aeration < aerate): le regole di
  suffisso e di prefisso di apprendi_derivati.py, imparate dalle coppie parola–base che le pagine dichiarano
  ({{af|en|aerate|-ion}}), con le soglie di apprendi_derivati.py (almeno SUPPORTO casi, PRECISIONE nella famiglia,
  ESATTEZZA esatte) e misurate sul 20% tenuto da parte: la lingua passa con SOGLIA_LINGUA nella famiglia su almeno
  MINIMO_PROVA prove. La famiglia qui è la catena delle coppie dichiarate (activate < active), ed è esatta anche la base
  che è un passaggio intermedio verso quella dichiarata: Wiktionary scrive activation = active + -ation, la regola dà
  activate < active (il 28 novembre 2026 «-ation al posto di -ate» era esatta solo nel 21%, e aeration restava fuori);
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

from apprendi_derivati import (ESATTEZZA, MAX_SUFFISSO, MIN_RADICE, MINIMO_PROVA, PRECISIONE, SOGLIA_LINGUA, SUPPORTO, nudo,
                                parola, regole_della_coppia)

# byte per voce nel database (stima_import.py): voce, ipotesi, un passaggio, la famiglia, la glossa italiana
BYTE_VOCE = 510 + 425 + 355 + 100 + 340
# le glosse delle grafie e delle forme di un'altra parola: non sono voci nuove da far entrare
VARIANTI = ('alternative form of', 'alternative spelling of', 'misspelling of', 'obsolete form of', 'obsolete spelling of',
            'archaic form of', 'archaic spelling of', 'nonstandard spelling of', 'nonstandard form of', 'dated form of',
            'dated spelling of', 'eye dialect spelling of', 'pronunciation spelling of', 'synonym of', 'abbreviation of')


def apri(p):
    return gzip.open(p, 'rt', encoding='utf-8') if p.endswith('.gz') else open(p, encoding='utf-8')


def main():
    scrivi = sys.argv[sys.argv.index('--scrivi') + 1] if '--scrivi' in sys.argv else None
    scrivi_etimi = sys.argv[sys.argv.index('--scrivi-etimi') + 1] if '--scrivi-etimi' in sys.argv else None
    a = [x for i, x in enumerate(sys.argv) if not x.startswith('--') and sys.argv[i - 1] not in ('--scrivi', '--scrivi-etimi', '--mostra')]
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

    def cima(x):
        visti = set()
        while x in coppie and x not in visti:
            visti.add(x)
            x = coppie[x]
        return nudo(x)

    def giudica(b, c):
        # (esatta, nella famiglia): la base dichiarata, o un passaggio intermedio verso di essa; la stessa cima
        esatta = nudo(b) == nudo(c) or nudo(coppie.get(b, '')) == nudo(c)
        return esatta, esatta or cima(b) == cima(c)

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
    sbagli = defaultdict(list)
    for w in addestra:
        for r, b in scatti(w, idx_regole):
            es, fam = giudica(b, coppie[w])
            misura[r]['scatta'] += 1
            misura[r]['esatta'] += es
            misura[r]['famiglia'] += fam
            if not fam:
                sbagli[r].append(f'{w}: {b}, dichiarata {coppie[w]}')
    buone = {r: m['famiglia'] / m['scatta'] for r, m in misura.items()
             if m['scatta'] >= SUPPORTO and m['famiglia'] >= PRECISIONE * m['scatta'] and m['esatta'] >= ESATTEZZA * m['scatta']}

    idx_buone = indice(buone)

    def prevedi_regola(w):
        ss = [(buone[r], len(r[1]), b, r) for r, b in scatti(w, idx_buone)]
        return max(ss)[2:] if ss else (None, None)

    def prevedi(w):
        return prevedi_regola(w)[0]
    esatte = famiglia = previste = 0
    for w in prova:
        b = prevedi(w)
        if b:
            es, fam = giudica(b, coppie[w])
            previste += 1
            esatte += es
            famiglia += fam
    passa = previste >= MINIMO_PROVA and famiglia >= SOGLIA_LINGUA * previste
    print(f'{lingua}: {len(lemmi)} lemmi comuni nel filtro, {len(della_lingua)} voci nel dizionario; coppie parola–base dichiarate '
          f'{len(coppie)}; regole {len(buone)} (almeno {SUPPORTO} casi, {PRECISIONE:.0%} nella famiglia, {ESATTEZZA:.0%} esatte); '
          f'prova sul 20% tenuto da parte: su {previste}, nella famiglia {famiglia} ({famiglia / max(1, previste):.0%}), '
          f'esatte {esatte} ({esatte / max(1, previste):.0%}) → ' + ('passa' if passa else f'non passa: nessun derivato'))
    mancano = [w for w in lemmi if w not in della_lingua]
    gruppi = defaultdict(list)
    # prima le voci con un etimo nel dizionario: entrano con la loro etimologia, e possono fare da base a un derivato
    # (aeration < aerate, e aerate < latino aerātus); un livello solo, non a catena
    entrano = {w for w in mancano if primo.get(w) and (primo[w] in nel or (primo[w][0] == lingua and primo[w][1] in della_lingua))}
    # e i derivati dichiarati di una di queste (aeration = aerate + -ion): anche loro un livello solo
    dichiarati = {w for w in mancano if w not in entrano and coppie.get(w) in entrano}
    for w in mancano:
        p = primo.get(w)
        if w in entrano:
            gruppi['con un etimo nel dizionario'].append((w, f'{p[0]}:{p[1]}'))
        elif w in dichiarati:
            gruppi['con un etimo che entra con il gruppo di sopra'].append((w, f'{p[0]}:{p[1]}'))
        elif w not in primo:
            b = prevedi(w)
            if passa and b and (b in della_lingua or b in entrano):
                gruppi['senza etimologia, derivato trasparente di una voce che c\'è'].append((w, b))
            else:
                gruppi['senza etimologia, nient\'altro'].append((w, None))
        else:
            gruppi['con un etimo fuori dal dizionario'].append((w, f'{primo[w][0]}:{primo[w][1]}'))
    print(f'lemmi comuni che il dizionario non ha: {len(mancano)}')
    # --mostra aeration,…: perché una parola entra o no (regole che scattano, con la loro misura sull'addestramento)
    for w in (sys.argv[sys.argv.index('--mostra') + 1].split(',') if '--mostra' in sys.argv else []):
        print(f'  [mostra] {w}: tra i lemmi {w in lemmi}, nel dizionario {w in della_lingua}, primo etimo {primo.get(w)}, '
              f'coppia {coppie.get(w)}, entra con un etimo {w in entrano}, derivato dichiarato {w in dichiarati}')
        for r, b in scatti(w, idx_regole):
            m = misura.get(r, {})
            print(f'    regola {r} → {b} (nel dizionario {b in della_lingua}, entra {b in entrano}, omografi '
                  f'{per_nudo.get(nudo(b))}): scatta {m.get("scatta", 0)}, esatte {m.get("esatta", 0)}, nella famiglia '
                  f'{m.get("famiglia", 0)}, buona {r in buone}; fuori dalla famiglia: {"; ".join(sbagli[r][:8])}')
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
            voci = gruppi['con un etimo nel dizionario'] + gruppi['con un etimo che entra con il gruppo di sopra']
            for w, e in sorted(voci):
                out.write(f'{w}\t{e}\n')
        print(f'scritte {len(voci)} voci con un etimo nel dizionario o che entra in {scrivi_etimi}')


if __name__ == '__main__':
    main()
