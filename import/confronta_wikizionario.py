#!/usr/bin/env python3
"""I due Wiktionary a confronto (regola di Giovanni, 7 novembre 2026): per ogni parola italiana che ha un'etimologia sia
in Wiktionary inglese sia nel Wikizionario, le righe del Wikizionario (etimi_wikizionario.py) diventano

- «Wikizionario-concorda»: l'etimo del Wikizionario sta nella catena di Wiktionary (anche più in alto, o in un'altra forma
  di citazione: ascendĕre e ascendo, pontem e pons, papam e papa). La voce cita anche il Wikizionario;
- «Wikizionario-discorda»: il Wikizionario dà un'origine che la catena non ha (destinatario: dal francese destinataire,
  per Wiktionary dal latino destinatarius). Entra come ipotesi alternativa, certezza 2, e la voce va nella lista di lavoro;
- niente, se le due etimologie sono due analisi italiane diverse ma entrambe possibili (policentrico = poli- + centro, o
  poli- + centrico; erudito da erudire o dal latino eruditus): non è un disaccordo sull'origine.

Le righe delle parole senza etimologia in Wiktionary restano come sono («Wikizionario»: valgono dove non c'è altro); le
righe «vedi» delle parole che un'etimologia ce l'hanno vanno via. Due Wiktionary non sono fonti indipendenti: l'accordo
non rende «verificata» un'ipotesi.

    python3 confronta_wikizionario.py etimi.tsv lessemi.tsv ipotesi.tsv relazioni.tsv [lingua fonte]

Per il francese, con le righe del Wiktionnaire (etimi_wiktionnaire.py): «fr Wiktionnaire»; per default «it Wikizionario».
Riscrive etimi.tsv (non compresso); gli altri possono essere compressi. Il rapporto va sullo standard error.
"""
import gzip, sys, unicodedata
from collections import Counter, defaultdict

PROFONDITA = 6


def righe(percorso):
    apri = gzip.open if percorso.endswith('.gz') else open
    with apri(percorso, 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def norma(w):
    """Senza segni diacritici, in minuscolo, senza asterisco e trattini; ϕ è φ, j è i, ς è σ."""
    w = unicodedata.normalize('NFKD', (w or '').lower().replace('ϕ', 'φ').replace('ϑ', 'θ'))
    w = ''.join(c for c in w if not unicodedata.combining(c)).replace('ς', 'σ').replace('j', 'i')
    return w.strip('*-')


def famiglia_lingua(c):
    """latino, greco, francese… con le loro varietà: la-vul e la-med sono latino, fro e frm francese."""
    c = (c or '').split('-')[0]
    return {'fro': 'fr', 'frm': 'fr', 'gkm': 'grc', 'el': 'grc', 'enm': 'en', 'ang': 'en', 'osp': 'es'}.get(c, c)


def forme(lingua, w):
    """Le forme di citazione possibili: per il latino l'infinito anche come prima persona (ascendere → ascendo) e
    l'accusativo anche senza la -m (papam → papa)."""
    n = norma(w)
    s = {n}
    if famiglia_lingua(lingua) == 'la':
        for fin, pp in (('are', ('o',)), ('ere', ('o', 'eo', 'io')), ('ire', ('io',)), ('ari', ('or',)), ('eri', ('eor', 'or')),
                        ('iri', ('ior',)), ('i', ('or',))):
            if n.endswith(fin):
                s |= {n[:-len(fin)] + p for p in pp}
        if n.endswith('m'):
            s.add(n[:-1])
    return s


def simili(a, b):
    """Due forme della stessa parola: una comincia con l'altra (papa, papam), o hanno in comune almeno quattro lettere e
    tutto tranne le ultime tre (ponte e pontem, laubia e laubiia; non casa e caso, non destinataire e destino)."""
    if min(len(a), len(b)) <= 4:
        return a.startswith(b) or b.startswith(a)
    if abs(len(a) - len(b)) <= 1 and distanza_uno(a, b):
        return True                              # una lettera di differenza: cycnus e cygnus
    l = 0
    while l < min(len(a), len(b)) and a[l] == b[l]:
        l += 1
    return l >= max(4, min(len(a), len(b)) - 3)


def distanza_uno(a, b):
    """Le due forme differiscono al più per una lettera (sostituita, aggiunta o tolta)."""
    if len(a) > len(b):
        a, b = b, a
    i = 0
    while i < len(a) and a[i] == b[i]:
        i += 1
    return a[i + (len(a) == len(b)):] == b[i + 1:]


def classifica(elementi, catena, formazione_italiana=False, propria='it'):
    """elementi: [(lingua, etimo)] del Wikizionario; catena: {(famiglia di lingua, forma normalizzata)} di Wiktionary.
    'concorda', 'discorda' o 'analisi': due analisi italiane diverse, o una formazione italiana per Wiktionary
    (ottaedro = otta- + -edro, formazione_italiana) e un prestito dotto per il Wikizionario (ὀκτάεδρος). propria è la
    lingua della parola (it; fr per il Wiktionnaire, dove l'antico francese conta come francese)."""
    def trovato(lingua, e):
        fl = famiglia_lingua(lingua)
        candidati = [f for (l2, f) in catena if l2 == fl or propria in (l2, fl)]
        return any(f in forme(lingua, e) or any(simili(x, f) for x in forme(lingua, e)) for f in candidati)
    if all(trovato(l, e) for l, e in elementi):
        return 'concorda'
    if all(famiglia_lingua(l) == propria for l, e in elementi):
        return 'analisi'
    if formazione_italiana and all(famiglia_lingua(l) in ('la', 'grc') for l, e in elementi):
        return 'analisi'
    return 'discorda'


def main():
    etimi_p, lessemi_p, ipotesi_p, relazioni_p = sys.argv[1:5]
    propria, fonte = (sys.argv[5], sys.argv[6]) if len(sys.argv) > 6 else ('it', 'Wikizionario')
    lessemi = {c[0]: (c[1], c[2]) for c in righe(lessemi_p) if len(c) > 2}
    italiane = defaultdict(list)                 # le voci della lingua della parola, per lemma
    for k, (lingua, lemma) in lessemi.items():
        if lingua == propria:
            italiane[lemma].append(k)
    accolte = {c[0]: c[1] for c in righe(ipotesi_p) if len(c) > 3 and c[3] == 'accolta'}
    etimi_di = defaultdict(list)                 # esito → [(etimo, affisso, forma citata)] delle ipotesi accolte
    for c in righe(relazioni_p):
        if len(c) > 7 and c[1] in accolte:
            etimi_di[c[2]].append((c[3], c[6], c[7]))

    def catena(k):
        """Gli etimi di Wiktionary fino a PROFONDITA passi, con gli affissi e le forme citate."""
        out, fronte, visti = set(), [k], {k}
        for _ in range(PROFONDITA):
            nuovi = []
            for x in fronte:
                for e, affisso, forma in etimi_di.get(x, ()):
                    if e not in lessemi:
                        continue
                    fl = famiglia_lingua(lessemi[e][0])
                    for a in (affisso or '').split():
                        if a != '\\N':
                            out.add((famiglia_lingua(lessemi[x][0]), norma(a)))
                    if forma and forma != '\\N':
                        out.add((fl, norma(forma)))
                    if e not in visti:
                        visti.add(e)
                        out.add((fl, norma(lessemi[e][1])))
                        nuovi.append(e)
            fronte = nuovi
        return out

    tutte = righe(etimi_p)
    per_parola = defaultdict(list)
    for c in tutte:
        if len(c) > 8 and c[8] in (fonte, fonte + '-vedi') and c[1] == propria:   # il Wiktionnaire ha voci francesi e greche
            per_parola[c[0]].append(c)
    esito, conta, esempi = {}, Counter(), defaultdict(list)
    for chiave, rr in per_parola.items():
        voci = italiane.get(rr[0][2], [])
        if len(voci) != 1 or voci[0] not in etimi_di:
            conta['senza etimologia in Wiktionary'] += 1
            continue
        if rr[0][8] == fonte + '-vedi':
            esito[chiave] = None                 # un rimando non è un'etimologia da confrontare
            conta['rimandi tolti'] += 1
            continue
        primi = [lessemi[e][0] for e, _, _ in etimi_di[voci[0]] if e in lessemi]
        verdetto = classifica([(c[4], c[5]) for c in rr], catena(voci[0]),
                              formazione_italiana=bool(primi) and all(famiglia_lingua(l) == propria for l in primi),
                              propria=propria)
        conta[verdetto] += 1
        esito[chiave] = {'concorda': fonte + '-concorda', 'discorda': fonte + '-discorda'}.get(verdetto)
        if len(esempi[verdetto]) < 15:
            esempi[verdetto].append(f"{rr[0][2]}: {' + '.join(c[4] + ':' + c[5] for c in rr)}")
    with open(etimi_p, 'w', encoding='utf-8') as out:
        for c in tutte:
            if len(c) > 8 and c[0] in esito:
                if esito[c[0]] is None:
                    continue
                c = c[:8] + [esito[c[0]]] + c[9:]
            out.write('\t'.join(c) + '\n')
    confrontabili = conta['concorda'] + conta['discorda'] + conta['analisi']
    print(f"{fonte} e Wiktionary: {conta['concorda']} concordano ({conta['concorda'] / max(1, confrontabili):.0%}), "
          f"{conta['discorda']} discordano sull'origine ({conta['discorda'] / max(1, confrontabili):.0%}), "
          f"{conta['analisi']} analisi diverse nella lingua della parola; {conta['senza etimologia in Wiktionary']} parole senza etimologia "
          f"in Wiktionary, {conta['rimandi tolti']} rimandi tolti", file=sys.stderr)
    for v in ('discorda', 'analisi'):
        print(f'  {v}: ' + '; '.join(esempi[v]), file=sys.stderr)


if __name__ == '__main__':
    main()
