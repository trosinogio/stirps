#!/usr/bin/env python3
"""Le regole di formazione del greco imparate dai dati, e misurate prima di usarle.

Le voci greche con un'etimologia nota (le relazioni accolte di Wiktionary tra due parole greche e le righe dell'LSJ)
insegnano tre tipi di regole, sulle forme senza accenti né spiriti:
- suffisso: σκοτίζω < σκότος insegna «-ιζω al posto di -οσ» (S, ιζω, οσ);
- prefisso: καταβαίνω < βαίνω insegna «κατα- davanti a una parola» (P, κατα);
- secondo elemento di un composto: λαμπαδηφόρος < λαμπάς + φέρω insegna «-φοροσ è φέρω» (C, φοροσ), anche quando la
  forma cambia, che è quello che le regole scritte a mano non sanno fare.
Anche le regole scritte a mano (analisi_composti.py) entrano nella prova, una per prefisso o suffisso.

Ogni regola si misura dove scatta, sulle voci note dell'80% di addestramento. Una previsione è esatta se la base è un
etimo greco della voce; è della stessa famiglia se la base e l'etimo hanno un antenato comune nel greco (εὔσηπτος =
εὐ- + σηπτός, e σηπτός viene da σήπω, l'etimo dell'LSJ): la voce finisce nella famiglia giusta anche se per un'altra
strada. Restano le regole con almeno SUPPORTO casi, almeno PRECISIONE nella stessa famiglia e almeno ESATTEZZA esatte;
poi si misura il tutto sul 20% tenuto da parte, che le regole non hanno visto.

Le voci greche senza etimologia ricevono la previsione della regola migliore, in righe con opera «analisi» (certezza 2,
mai nelle storie): le righe greche di analisi_composti.py nel file degli etimi sono sostituite da queste.

    python3 apprendi_greco.py etimi.tsv lessemi.tsv dizionari.tsv ipotesi.tsv relazioni.tsv [--solo-rapporto]

I file possono essere compressi (.gz), tranne gli etimi se si scrive. Il rapporto va sullo standard error.
"""
import gzip, sys, zlib
from collections import Counter, defaultdict

from analisi_composti import analizza, comune, nudo

SUPPORTO, PRECISIONE, ESATTEZZA = 5, 0.85, 0.5
VOCALI_DI_UNIONE = 'οιαυ'
# le finali con cui un tema diventa una parola, per il primo elemento di un composto (μοσχ- → μόσχος)
FINALI = ('οσ', 'ον', 'η', 'α', 'ησ', 'ασ', 'ισ', 'υσ', 'ευσ', 'ω', 'εω', 'αω', 'οω', 'ων', 'ηρ', 'μα', 'ια', 'ιον')


def righe(percorso):
    apri = gzip.open if percorso.endswith('.gz') else open
    with apri(percorso, 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def lcp(a, b):
    i = 0
    while i < min(len(a), len(b)) and a[i] == b[i]:
        i += 1
    return i


def punto_di_unione(n, a, b):
    """Dove comincia il secondo elemento: vicino alla fine del prefisso comune con il primo, sulla lettera iniziale del
    secondo (φιλ-ο-σοφοσ, μοσχο-μαγειροσ, λαμπαδη-φοροσ)."""
    l = lcp(n, a)
    if l < 3:
        return None
    for d in (0, -1, 1, -2, 2, 3):
        k = l + d
        if 3 <= k < len(n) and n[k] == b[0]:
            return k
    return None


def regole_della_coppia(n, etimi):
    """Le regole che una voce (n, senza accenti) e i suoi etimi greci (senza accenti, in ordine) insegnano."""
    if len(etimi) == 1:
        b = etimi[0]
        if n.endswith(b) and len(b) >= 4 and 1 <= len(n) - len(b) <= 7:
            return [('P', n[:-len(b)])]
        l = lcp(n, b)
        if l >= 3 and 1 <= len(n) - l <= 7 and len(b) - l <= 5:
            return [('S', n[l:], b[l:])]
    elif len(etimi) == 2:
        k = punto_di_unione(n, *etimi)
        if k is not None and len(n) - k >= 3:
            return [('C', n[k:], etimi[1])]
    return []


class Modello:
    def __init__(self, lessico, temi):
        self.lessico, self.temi = lessico, temi      # forma senza accenti → lemmi; tema senza finale → lemmi
        self.S, self.P, self.C = defaultdict(set), set(), {}

    def unico(self, forma, escluso):
        c = self.lessico.get(forma, set()) - {escluso}
        return next(iter(c)) if len(c) == 1 else None

    def primo_elemento(self, testa, escluso):
        trovati = set()
        for t in {testa, testa[:-1] if testa[-1:] in VOCALI_DI_UNIONE else testa}:
            if len(t) >= 3:
                trovati |= self.temi.get(t, set()) - {escluso}
        return next(iter(trovati)) if len(trovati) == 1 else None

    def scatti(self, n, lemma):
        """Le previsioni di ogni regola appresa che scatta su una voce: [(regola, (etimo,) o (primo, secondo))]."""
        out = []
        for i in range(1, min(8, len(n) - 2)):
            for b in self.S.get(n[-i:], ()):
                base = self.unico(n[:-i] + b, lemma)
                if base:
                    out.append((('S', n[-i:], b), (base,)))
        for i in range(1, min(8, len(n) - 3)):
            if ('P', n[:i]) in self.P:
                base = self.unico(n[i:], lemma)
                if base:
                    out.append((('P', n[:i]), (base,)))
        for k in range(3, len(n) - 2):
            if n[k:] in self.C:
                secondo, forma = self.C[n[k:]]
                primo = self.primo_elemento(n[:k], lemma)
                if primo and primo != secondo:
                    out.append((('C', n[k:], forma), (primo, secondo)))
        return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    solo_rapporto = '--solo-rapporto' in sys.argv
    etimi_p, lessemi_p, dizionari_p, ipotesi_p, relazioni_p = args[:5]
    chiavi = {}                                           # chiave → (lingua, lemma, pos, ricostruito)
    for c in righe(lessemi_p) + righe(dizionari_p):
        if len(c) > 6:
            chiavi[c[0]] = (c[1], c[2], c[6], c[4])
    greche = {k: v for k, v in chiavi.items() if v[0] == 'grc' and v[3] != 't' and comune(v[1], v[2])}
    lessico, temi = defaultdict(set), defaultdict(set)
    for lingua, lemma, pos, _ in greche.values():
        n = nudo(lemma)
        lessico[n].add(lemma)
        for f in sorted(FINALI, key=len, reverse=True):
            if n.endswith(f) and len(n) - len(f) >= 3:
                temi[n[:-len(f)]].add(lemma)
                break
    # l'oro: gli etimi greci delle voci greche, dalle ipotesi accolte di Wiktionary e dall'LSJ
    accolte = {c[0] for c in righe(ipotesi_p) if len(c) > 3 and c[3] == 'accolta'}
    oro, ordine_oro, con_etimo = defaultdict(set), defaultdict(dict), set()
    for c in righe(relazioni_p):
        if len(c) < 6 or c[1] not in accolte or c[2] not in chiavi or chiavi[c[2]][0] != 'grc':
            continue
        lemma = chiavi[c[2]][1]
        con_etimo.add(lemma)
        if c[3] in chiavi and chiavi[c[3]][0] == 'grc' and c[4] in ('derivazione', 'composizione', 'generico'):
            oro[lemma].add(chiavi[c[3]][1])
            ordine_oro[lemma][int(c[5]) if c[5].isdigit() else 1] = chiavi[c[3]][1]
    etimi = righe(etimi_p)
    for c in etimi:
        if len(c) > 8 and c[8] == 'LSJ' and c[1] == 'grc' and c[4] == 'grc':
            con_etimo.add(c[2])
            oro[c[2]].add(c[5])
            ordine_oro[c[2]][int(c[3]) if c[3].isdigit() else 1] = c[5]

    memo = {}

    def antenati(l, prof=3):
        """La parola e i suoi antenati greci fino a tre passi (σηπτός → σήπω)."""
        if (l, prof) not in memo:
            s = {l}
            if prof:
                for e in oro.get(l, ()):
                    s |= antenati(e, prof - 1)
            memo[(l, prof)] = s
        return memo[(l, prof)]

    def esito(prev, l):
        """(esatta, stessa famiglia): ogni elemento previsto è un etimo, o ha un antenato comune con un etimo."""
        esatta = set(prev) <= oro[l]
        fam = bool(oro[l]) and all(any(antenati(p) & antenati(e) for e in oro[l]) for p in prev)
        return esatta, esatta or fam

    note = sorted(l for l in con_etimo if comune(l, None) and not l.startswith('-') and not l.endswith('-'))
    prova = {l for l in note if zlib.crc32(l.encode()) % 5 == 0}
    addestra = [l for l in note if l not in prova]

    # 1. le regole dalle coppie di addestramento
    m = Modello(lessico, temi)
    for l in addestra:
        ordinati = [ordine_oro[l][o] for o in sorted(ordine_oro[l])]
        for r in regole_della_coppia(nudo(l), [nudo(x) for x in ordinati]):
            if r[0] == 'S':
                m.S[r[1]].add(r[2])
            elif r[0] == 'P':
                m.P.add(r)
            else:
                m.C.setdefault(r[1], (ordinati[1], r[2]))
    # le regole scritte a mano su tutte le voci greche (anche quelle con un'etimologia, per misurarle)
    a_mano = defaultdict(list)
    for r in analizza([(k, v[0], v[1], v[2]) for k, v in greche.items()], set())[0]:
        a_mano[r[2]].append(r)

    def scatti(l):
        out = m.scatti(nudo(l), l)
        rr = a_mano.get(l)
        if rr:
            tipo = ('mano', 'composto') if len(rr) == 2 else ('mano', rr[0][7])
            out.append((tipo, tuple(r[5] for r in rr)))
        return out

    # 2. la precisione di ogni regola dove scatta, sulle voci di addestramento
    scatta, esatte, famiglia = Counter(), Counter(), Counter()
    for l in addestra:
        for r, prev in scatti(l):
            e, f = esito(prev, l)
            scatta[r] += 1
            esatte[r] += e
            famiglia[r] += f
    prec = {r: famiglia[r] / scatta[r] for r in scatta
            if scatta[r] >= SUPPORTO and famiglia[r] / scatta[r] >= PRECISIONE and esatte[r] / scatta[r] >= ESATTEZZA}

    def prevedi(l):
        cand = [c for c in scatti(l) if c[0] in prec]
        if not cand:
            return None
        meglio = max(prec[c[0]] for c in cand)
        migliori = {c[1] for c in cand if prec[c[0]] == meglio}
        return next(c for c in cand if prec[c[0]] == meglio) if len(migliori) == 1 else None

    # 3. la prova sul 20% tenuto da parte, e le regole a mano senza scelta sulle stesse voci, per confronto
    conta = Counter()
    sbagli = []
    for l in sorted(prova):
        rr = a_mano.get(l)
        if rr:
            e, f = esito(tuple(r[5] for r in rr), l)
            conta['mano'] += 1
            conta['mano_esatte'] += e
            conta['mano_famiglia'] += f
        p = prevedi(l)
        if not p:
            continue
        e, f = esito(p[1], l)
        fonte = 'mano' if p[0][0] == 'mano' else 'appresa'
        conta['previsioni'] += 1
        conta['esatte'] += e
        conta['famiglia'] += f
        conta[fonte] += 0
        conta['da_' + fonte] += 1
        if not f and len(sbagli) < 10:
            sbagli.append(f'{l}: {" + ".join(p[1])} ({p[0][0]} {p[0][1]}), invece {", ".join(sorted(oro[l])) or "nessun etimo greco"}')
    pct = lambda a, b: f'{a / max(1, b):.0%}'
    scelte = Counter(r[0] for r in prec)
    print(f'greco, regole apprese: {len(m.S)} finali, {len(m.P)} prefissi, {len(m.C)} secondi elementi, '
          f'{sum(1 for r in scatta if r[0] == "mano")} regole a mano; scelte: {dict(scelte)} '
          f'(almeno {SUPPORTO} casi, {PRECISIONE:.0%} nella famiglia, {ESATTEZZA:.0%} esatte)', file=sys.stderr)
    print(f'  prova su {len(prova)} voci note tenute da parte: {conta["previsioni"]} previsioni '
          f'({conta["da_appresa"]} dalle regole apprese, {conta["da_mano"]} da quelle a mano), '
          f'esatte {pct(conta["esatte"], conta["previsioni"])}, nella famiglia giusta {pct(conta["famiglia"], conta["previsioni"])}; '
          f'tutte le regole a mano, senza scelta: {conta["mano"]} previsioni, esatte {pct(conta["mano_esatte"], conta["mano"])}, '
          f'nella famiglia giusta {pct(conta["mano_famiglia"], conta["mano"])}', file=sys.stderr)
    for s in sbagli:
        print('    sbaglio: ' + s, file=sys.stderr)
    if solo_rapporto:
        return
    # 4. le voci greche senza etimologia: la previsione migliore, al posto delle righe greche di analisi_composti.py
    coperte = {(c[1], c[2]) for c in etimi if len(c) > 8 and c[8] != 'analisi'}
    nuove, conta = [], Counter()
    for k, (lingua, lemma, pos, _) in sorted(greche.items()):
        if lemma in con_etimo or (lingua, lemma) in coperte:
            continue
        p = prevedi(lemma)
        if not p:
            continue
        r, prev = p
        conta['a mano' if r[0] == 'mano' else 'apprese'] += 1
        if len(prev) == 2:
            nuove.append(('analisi:' + k, 'grc', lemma, 1, 'grc', prev[0], 'composizione', None, 'analisi'))
            nuove.append(('analisi:' + k, 'grc', lemma, 2, 'grc', prev[1], 'composizione', None, 'analisi'))
        else:
            # l'affisso con gli accenti della voce: -ησις, non -ησισ (nudo() toglie solo segni, e ς diventa σ)
            affisso = r[1] if r[0] == 'mano' else lemma[:len(r[1])] + '-' if r[0] == 'P' else '-' + lemma[-len(r[1]):]
            nuove.append(('analisi:' + k, 'grc', lemma, 1, 'grc', prev[0], 'derivazione', affisso, 'analisi'))
    prima = sum(1 for c in etimi if len(c) > 8 and c[8] == 'analisi' and c[1] == 'grc' and c[3] == '1')
    with open(etimi_p, 'w', encoding='utf-8') as out:
        for c in etimi:
            if not (len(c) > 8 and c[8] == 'analisi' and c[1] == 'grc'):
                out.write('\t'.join(c) + '\n')
        for r in nuove:
            out.write('\t'.join('\\N' if x is None or x == '' else str(x) for x in r) + '\n')
    print(f'  voci greche analizzate: {sum(conta.values())} (erano {prima} con le sole regole a mano): {dict(conta)}',
          file=sys.stderr)


if __name__ == '__main__':
    main()
