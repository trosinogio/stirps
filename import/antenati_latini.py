#!/usr/bin/env python3
"""Il modello delle forme: l'antenato latino di una parola italiana, imparato dalle coppie note e misurato prima di usarlo.

Le coppie italiano–latino accolte (eredità, prestiti dotti, passaggi generici) insegnano due cose:
- le corrispondenze delle finali, per categoria: verme < vermis insegna «-e al posto di -is», torre < tollo
  «-ere al posto di -o» per i verbi, nazione < natio «-zione al posto di -tio»;
- i cambiamenti del tema, carattere per carattere: dattero < dactylus insegna c→t e y→e, giudicativo < iudicativus
  l'aggiunta di g, con la loro frequenza.
Per una parola italiana il modello prova tutti i lemmi latini che conosciamo (non solo quelli simili a occhio): li
filtra per iniziale e per trigrammi in comune, poi li ordina per il costo della trasformazione (finale più tema, in
logaritmi delle frequenze). La fiducia di una proposta è lo scarto tra il primo candidato e il secondo.

Prima di usarlo si misura (come apprendi_greco.py): il modello impara sull'80% delle coppie e si prova sul 20% tenuto
da parte, chiedendo l'etimo di ogni parola a tutto il lessico latino. Il rapporto dà quante volte l'etimo vero è il
primo, e la precisione per soglia di fiducia: si propone solo sopra la soglia che sul campione tenuto da parte tiene
almeno l'85% di esatte. Le proposte vanno alla redazione (lista di lavoro), mai al pubblico: le parole senza etimologia
sono spesso derivate italiane o forme che il latino non ha, e il campione delle note è più facile.

    python3 antenati_latini.py coppie.tsv latino.tsv italiano.tsv [senza.tsv proposte.tsv]

coppie.tsv: id_it, lemma_it, pos_it, id_la, lemma_la, pos_la, tipo, glossa_it, glossa_la (le relazioni accolte);
latino.tsv: id, lemma, pos, glossa, provenienza, nome_proprio; italiano.tsv: lemma, ha un'etimologia (t/f);
senza.tsv: id, lemma, pos, glossa, rango di frequenza.
Il rapporto va sullo standard error.
"""
import math, random, sys, unicodedata, zlib
from collections import Counter, defaultdict

PRECISIONE = 0.85          # la soglia di esatte sul campione tenuto da parte
MAX_FINALE = 5             # caratteri al massimo di una finale
CANDIDATI = 100            # quanti lemmi per parola passano al costo pieno, dopo il filtro dei trigrammi
LUNGHEZZA = (0.55, 1.8)    # rapporto di lunghezza latino/italiano ammesso


def wilson(k, n, z=1.96):
    """Il limite inferiore dell'intervallo di Wilson al 95%: la precisione che si può garantire su n casi."""
    if not n: return 0.0
    p = k / n
    return (p + z * z / (2 * n) - z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))) / (1 + z * z / n)


def una_lettera(a, b):
    if abs(len(a) - len(b)) > 1 or a == b: return False
    return sum(1 for x, y in allinea(a, b) if x != y) == 1


def norm(s):
    s = unicodedata.normalize('NFD', s.lower())
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return s.replace('j', 'i').replace('æ', 'ae').replace('œ', 'oe').replace('-', '').replace(' ', '')


def classe(pos):
    p = (pos or '').lower()
    if p.startswith('v'): return 'v'
    if p.startswith('agg') or p.startswith('adj'): return 'a'
    if p.startswith('s') or p.startswith('n'): return 's'
    return '?'


def righe(percorso):
    with open(percorso, encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def allinea(a, b):
    """Allineamento di Levenshtein da a (latino) a b (italiano): lista di (x, y), con '' per inserzione o cancellazione."""
    n, m = len(a), len(b)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1): d[i][0] = i
    for j in range(m + 1): d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] != b[j - 1]))
    i, j, ops = n, m, []
    while i or j:
        if i and j and d[i][j] == d[i - 1][j - 1] + (a[i - 1] != b[j - 1]):
            ops.append((a[i - 1], b[j - 1])); i -= 1; j -= 1
        elif i and d[i][j] == d[i - 1][j] + 1:
            ops.append((a[i - 1], '')); i -= 1
        else:
            ops.append(('', b[j - 1])); j -= 1
    return ops[::-1]


def dividi(la, it):
    """Tema e finale di una coppia: la finale comincia dopo l'ultima corsa di almeno due caratteri uguali."""
    ops = allinea(la, it)
    k = len(ops)
    corsa = 0
    while k > 0:
        x, y = ops[k - 1]
        if x and x == y:
            corsa += 1
            if corsa >= 2: k += 1; break
        else:
            corsa = 0
        k -= 1
    if k <= 0: k = 0
    k = min(len(ops), max(0, k))
    # k è l'indice della prima operazione della finale (dopo la corsa)
    fin = ops[k:]
    fl = ''.join(x for x, _ in fin)
    fi = ''.join(y for _, y in fin)
    if len(fl) > MAX_FINALE or len(fi) > MAX_FINALE:
        return None
    return la[:len(la) - len(fl)], fl, it[:len(it) - len(fi)], fi


class Modello:
    def __init__(self, coppie):
        self.finali = defaultdict(Counter)   # (classe, finale italiana) -> Counter(finale latina)
        self.op = Counter(); self.da = Counter()
        self.iniziali = defaultdict(Counter)  # prime due lettere italiane -> Counter(prima lettera latina)
        for it, la, cl in coppie:
            self.iniziali[comune(it, ITALIANO_COMUNE)[:2]][comune(la, LATINO_COMUNE)[:1]] += 1
            parti = dividi(la, it)
            if not parti: continue
            tl, fl, ti, fi = parti
            self.finali[(cl, fi)][fl] += 1
            self.finali[('*', fi)][fl] += 1
            for x, y in allinea(tl, ti):
                self.op[(x, y)] += 1; self.da[x] += 1
        self.v = len({y for _, y in self.op}) + 1

    def costo_op(self, x, y):
        return -math.log((self.op[(x, y)] + 0.1) / (self.da[x] + 0.1 * self.v))

    def costo_tema(self, tl, ti):
        """Distanza pesata dal tema latino al tema italiano, con i costi imparati."""
        n, m = len(tl), len(ti)
        prec = [0.0] * (m + 1)
        for j in range(1, m + 1): prec[j] = prec[j - 1] + self.costo_op('', ti[j - 1])
        for i in range(1, n + 1):
            cur = [prec[0] + self.costo_op(tl[i - 1], '')] + [0.0] * m
            for j in range(1, m + 1):
                cur[j] = min(prec[j] + self.costo_op(tl[i - 1], ''), cur[j - 1] + self.costo_op('', ti[j - 1]),
                             prec[j - 1] + self.costo_op(tl[i - 1], ti[j - 1]))
            prec = cur
        return prec[m]

    def costo(self, it, la, cl):
        meglio = None
        for k in range(0, min(MAX_FINALE, len(it) - 1) + 1):
            fi = it[len(it) - k:]
            for chiave in ((cl, fi), ('*', fi)):
                c = self.finali.get(chiave)
                if not c: continue
                tot = sum(c.values())
                for fl, n in c.items():
                    if n < 2 or not la.endswith(fl) or len(la) - len(fl) < 1: continue
                    cf = -math.log(n / tot) + (0.0 if chiave[0] == cl else 0.5)
                    ct = self.costo_tema(la[:len(la) - len(fl)], it[:len(it) - k])
                    tot_c = cf + ct
                    if meglio is None or tot_c < meglio: meglio = tot_c
                break
        return meglio


# solo per cercare i candidati (il costo resta quello imparato): le due lingue ridotte a una forma comune, così che
# ottuso trovi obtusus e siepe saepes anche con pochi trigrammi uguali nella forma piena
LATINO_COMUNE = (('ph', 'f'), ('th', 't'), ('ch', 'c'), ('rh', 'r'), ('y', 'i'), ('ae', 'e'), ('oe', 'e'), ('au', 'o'),
                 ('h', ''), ('x', 'ss'), ('ct', 'tt'), ('pt', 'tt'), ('bt', 'tt'), ('mn', 'nn'), ('ns', 's'), ('k', 'c'))
ITALIANO_COMUNE = (('gli', 'li'), ('gn', 'n'), ('ch', 'c'), ('gh', 'g'), ('zz', 'tt'), ('z', 't'), ('h', ''))


def comune(s, regole):
    for a, b in regole: s = s.replace(a, b)
    out = []
    for c in s:
        if not out or out[-1] != c: out.append(c)
    return ''.join(out)


def trigrammi(s):
    s = f'#{s}#'
    return {s[i:i + 3] for i in range(len(s) - 2)}


PAROLE_VUOTE = set('the a an of to in on at by for with from or and as be is are was it its one who which that this '
                   'not no used form forms alternative obsolete also esp especially something someone person thing '
                   'make made act state quality having being'.split())


def senso(glossa):
    """Le parole piene di una glossa inglese, troncate a cinque lettere: snow e snows sono la stessa."""
    t = ''.join(c if c.isalpha() else ' ' for c in glossa.lower()).split()
    return {w[:5] for w in t if len(w) >= 3 and w not in PAROLE_VUOTE}


# le voci che il modello non prova: forme di altre parole, e derivati italiani la cui base è nel dizionario (rovinato
# da rovinare, condanna da condannare, divertente da divertire): lì l'analisi più economica è italiana, non latina
FORME = ('contraction', 'apocop', 'elided', 'elision', 'form of', 'participle', 'plural of', 'letter', 'abbreviation',
         'initialism', 'clipping', 'misspelling', 'synonym of')
DERIVATI = (('ato', 'are'), ('ata', 'are'), ('ati', 'are'), ('ate', 'are'), ('ito', 'ire'), ('ita', 'ire'),
            ('uto', 'ere'), ('uta', 'ere'), ('ente', 'ere'), ('ente', 'ire'), ('ante', 'are'), ('abile', 'are'),
            ('ibile', 'ere'), ('ibile', 'ire'), ('atile', 'are'), ('amento', 'are'), ('imento', 'ire'),
            ('azione', 'are'), ('izione', 'ire'), ('atore', 'are'), ('itore', 'ire'), ('atrice', 'are'),
            ('anza', 'are'), ('enza', 'ere'), ('enza', 'ire'), ('a', 'are'), ('o', 'are'), ('e', 'are'))
# i suffissi italiani che fanno una parola da un'altra parola (assistenziale da assistenza, gambale da gamba,
# problematizzare da problematico): la base è il tema più una di queste finali
SUFFISSI = ('izzazione', 'izzare', 'istico', 'istica', 'ismo', 'ista', 'iale', 'ale', 'ali', 'ico', 'ica', 'oso', 'osa',
            'ino', 'ina', 'etto', 'etta', 'ello', 'ella', 'ezza', 'ità', 'ario', 'aria', 'iere', 'iera', 'eria', 'ese',
            'iano', 'iana', 'ume', 'ata', 'one', 'ona', 'accio', 'uccio')
FINALI_BASE = ('', 'o', 'a', 'e', 'i', 'are', 'ere', 'ire')


def esclusa(lemma, glossa, italiani):
    """Perché una voce italiana non si prova (None se si prova)."""
    if lemma[:1].isupper(): return 'maiuscola'
    if not glossa.strip(): return 'senza glossa'
    g = glossa.lower()
    if any(f in g for f in FORME): return 'forma di un\'altra parola'
    l = lemma.lower()
    for fin, base in DERIVATI:
        if l.endswith(fin) and len(l) - len(fin) >= 3 and l[:len(l) - len(fin)] + base in italiani:
            return 'derivato italiano'
    for fin in SUFFISSI:
        tema = l[:len(l) - len(fin)]
        if l.endswith(fin) and len(tema) >= 3 and any(tema + f in italiani for f in FINALI_BASE):
            return 'derivato italiano'
    return None


COMPATIBILI = {('s', 'a'), ('a', 's'), ('s', 's'), ('a', 'a'), ('v', 'v')}


class Lessico:
    def __init__(self, latino):
        self.voci = []   # (id, lemma, forma normale, classe, senso, perseus)
        self.per_iniziale = defaultdict(list)
        for r in latino:
            if r[5] == 't': continue          # i nomi propri non sono antenati di parole comuni
            f = norm(r[1])
            if len(f) < 2: continue
            k = len(self.voci)
            self.voci.append((r[0], r[1], f, classe(r[2]), senso(r[3]), r[4] == 'perseus'))
            g = comune(f, LATINO_COMUNE)
            self.per_iniziale[g[:1]].append((k, trigrammi(g)))

    def candidati(self, mod, it):
        g = comune(it, ITALIANO_COMUNE)
        t = trigrammi(g)
        iniz = mod.iniziali.get(g[:2]) or Counter({g[:1]: 1})
        lettere = {l for l, n in iniz.items() if n >= 2} | {g[:1]}
        scelti = []
        for l in lettere:
            for k, tl in self.per_iniziale.get(l, ()):
                f = self.voci[k][2]
                if not LUNGHEZZA[0] <= len(f) / len(it) <= LUNGHEZZA[1]: continue
                c = len(t & tl)
                if c >= 2: scelti.append((c / len(t | tl), k))
        scelti.sort(reverse=True)
        return [k for _, k in scelti[:CANDIDATI]]


def prevedi(mod, lex, it_lemma, cl, glossa=''):
    """I tre lemmi latini più probabili: costo della forma, più la categoria, il senso delle glosse e la fonte."""
    if it_lemma.startswith('-') or it_lemma.endswith('-') or ' ' in it_lemma: return []
    it = norm(it_lemma)
    if len(it) < 3: return []
    s_it = senso(glossa)
    risultati = []
    for k in lex.candidati(mod, it):
        _, _, f, cl_la, s_la, perseus = lex.voci[k]
        c = mod.costo(it, f, cl)
        if c is None: continue
        if cl != '?' and cl_la != '?' and (cl, cl_la) not in COMPATIBILI: c += 3.0
        if s_it and s_la:
            c += -2.5 if s_it & s_la else 1.0
        if perseus: c += 0.5
        risultati.append((c, k))
    risultati.sort()
    return risultati[:3]


def main():
    coppie_raw = righe(sys.argv[1]); latino = righe(sys.argv[2])
    lex = Lessico(latino)
    italiani = {r[0].lower() for r in righe(sys.argv[3])}
    forma_di = {v[0]: v[2] for v in lex.voci}
    # una parola italiana con più etimi latini: ognuno è giusto
    per_it = defaultdict(set); info = {}; primo = {}
    for r in coppie_raw:
        if r[2] == 'np' or (r[4][:1].isupper()): continue
        per_it[r[0]].add(r[3]); info[r[0]] = (r[1], classe(r[2]), r[7]); primo.setdefault(r[0], r[4])
    ids = sorted(per_it)
    prova = {i for i in ids if zlib.crc32(i.encode()) % 5 == 0}
    addestra = [(norm(info[i][0]), norm(primo[i]), info[i][1]) for i in ids if i not in prova]
    mod = Modello(addestra)
    print(f'coppie: {len(ids)} parole italiane, {len(addestra)} per imparare, {len(prova)} tenute da parte; '
          f'{sum(len(c) for c in mod.finali.values())} finali, {len(mod.op)} operazioni sul tema', file=sys.stderr)
    # prova sul 20% tenuto da parte: esatta se il primo è un etimo accolto, o lo stesso lemma in un'altra voce
    # (lo stesso lemma da Wiktionary e dal Perseus); «variante» se differisce dall'etimo solo nella finale
    esiti = []; trovati = 0; fuori_prova = Counter()
    for i in sorted(prova):
        lemma, cl, gl = info[i]
        perche = esclusa(lemma, gl, italiani - {lemma.lower()})
        if perche: fuori_prova[perche] += 1; continue
        veri = {forma_di.get(x) for x in per_it[i]} - {None}
        if any(lex.voci[k][2] in veri for k in lex.candidati(mod, norm(lemma))): trovati += 1
        p = prevedi(mod, lex, lemma, cl, gl)
        if not p: esiti.append((None, 'no', lemma, '')); continue
        fiducia = (p[1][0] - p[0][0]) if len(p) > 1 else 5.0
        relativo = p[0][0] / len(norm(lemma))
        v = lex.voci[p[0][1]]
        if v[0] in per_it[i] or v[2] in veri: e = 'esatta'
        elif any(len(x) > 4 and una_lettera(v[2], x) for x in veri): e = 'variante'
        else: e = 'errata'
        esiti.append((fiducia, e, lemma, v[1], relativo))
    n = len(esiti); c = Counter(e[1] for e in esiti)
    print(f'tenute da parte: {n}; l\'etimo vero è tra i candidati in {trovati} ({trovati / n:.1%}); al primo posto '
          f'{c["esatta"]} ({c["esatta"] / n:.1%}), una variante dell\'etimo {c["variante"]}, senza candidati {c["no"]}; '
          f'non provate: ' + ', '.join(f'{k} {v}' for k, v in fuori_prova.most_common()), file=sys.stderr)
    con = sorted((e for e in esiti if e[0] is not None), key=lambda e: -e[0])
    soglia = None
    for s in (0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0):
        sopra = [e for e in con if e[0] >= s]
        if not sopra: continue
        k = sum(1 for e in sopra if e[1] == 'esatta')
        var = sum(1 for e in sopra if e[1] == 'variante') / len(sopra)
        print(f'  fiducia ≥ {s}: {len(sopra)} proposte ({len(sopra) / n:.0%} delle parole), esatte {k / len(sopra):.1%} '
              f'(almeno {wilson(k, len(sopra)):.1%}), varianti {var:.1%}', file=sys.stderr)
        if soglia is None and wilson(k, len(sopra)) >= PRECISIONE: soglia = s
    # il costo assoluto per lettera del primo candidato, tra le proposte sopra la soglia di fiducia
    if soglia is not None:
        sopra = [e for e in con if e[0] >= soglia]
        for t in (0.6, 0.8, 1.0, 1.2, 1.5, 2.0):
            q = [e for e in sopra if e[4] <= t]
            if q:
                k = sum(1 for e in q if e[1] == 'esatta')
                print(f'  e costo per lettera ≤ {t}: {len(q)} proposte, esatte {k / len(q):.1%} (almeno {wilson(k, len(q)):.1%})',
                      file=sys.stderr)
    errori = [e for e in con if e[1] == 'errata' and (soglia is None or e[0] >= soglia)]
    random.Random(1).shuffle(errori)
    print('  errori sopra la soglia: ' + '; '.join(f'{e[2]} → {e[3]}' for e in errori[:20]), file=sys.stderr)
    print(f'soglia scelta: {soglia}', file=sys.stderr)
    if len(sys.argv) > 5 and soglia is not None:
        mod = Modello([(norm(info[i][0]), norm(primo[i]), info[i][1]) for i in ids])
        fuori = []; scartate = Counter()
        for r in righe(sys.argv[4]):
            perche = esclusa(r[1], r[3], italiani - {r[1].lower()})
            if perche: scartate[perche] += 1; continue
            p = prevedi(mod, lex, r[1], classe(r[2]), r[3])
            if not p: continue
            fiducia = (p[1][0] - p[0][0]) if len(p) > 1 else 5.0
            if fiducia >= soglia:
                v = lex.voci[p[0][1]]
                fuori.append(f'{r[0]}\t{r[1]}\t{v[0]}\t{v[1]}\t{fiducia:.2f}\t{r[4]}\t{p[0][0] / len(norm(r[1])):.2f}\n')
        with open(sys.argv[5], 'w', encoding='utf-8') as f:
            f.writelines(fuori)
        print(f'proposte per le parole senza etimologia: {len(fuori)}; non provate: '
              + ', '.join(f'{k} {v}' for k, v in scartate.most_common()), file=sys.stderr)


if __name__ == '__main__':
    main()
