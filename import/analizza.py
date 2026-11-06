#!/usr/bin/env python3
"""L'analizzatore etimologico, livello 2: l'analisi morfologica dell'italiano sull'inventario del dizionario stesso.
Per una parola senza etimologia propone una formazione interna all'italiano, solo se tutte le sue parti sono voci del
dizionario: prefisso + parola (impossibile = in- + possibile), parola + suffisso (rapidamente = rapido + -mente),
confisso + confisso (biologia = bio- + -logia), accorciamento (bici ← bicicletta, se le glosse coincidono).

    python3 analizza.py valuta ../dati            # precisione di ogni regola sulle parole che Wiktionary spiega già
    python3 analizza.py proponi ../dati parola…   # le proposte per alcune parole

La valutazione nasconde all'analizzatore l'etimologia di ogni parola del banco e confronta la sua proposta con quella di
Wiktionary: una regola entra nel dizionario solo con una precisione alta. Solo libreria standard.
"""
import gzip, os, sys, unicodedata
from collections import Counter, defaultdict

# Le desinenze e i suffissi che fanno forme flesse, non parole nuove (-avamo, -ato): non servono all'analisi
FLESSIVI = {'-a', '-e', '-i', '-o', '-ai', '-ate', '-ato', '-ava', '-avamo', '-avano', '-avate', '-arono', '-asti', '-aste',
            '-ando', '-endo', '-are', '-ere', '-ire', '-ammo', '-emmo', '-immo'}
VOCALI = 'aeiouàèéìòù'
# le parti del discorso della base che un suffisso chiede (s. sostantivo, agg., v.); gli altri suffissi non hanno vincoli
BASE_DEL_SUFFISSO = {'mente': {'agg.'}, 'zione': {'v.'}, 'azione': {'v.'}, 'izione': {'v.'}, 'tore': {'v.'}, 'trice': {'v.'},
                     'mento': {'v.'}, 'tura': {'v.'}, 'bile': {'v.'}, 'abile': {'v.'}, 'ibile': {'v.'}, 'ità': {'agg.'},
                     'ezza': {'agg.'}, 'ismo': {'agg.', 's.'}, 'ista': {'s.', 'agg.'}, 'oso': {'s.'}, 'evole': {'v.', 's.'},
                     'ante': {'v.'}, 'ente': {'v.'}, 'anza': {'v.'}, 'enza': {'v.'}, 'aggio': {'v.', 's.'}}
# i suffissi comuni dell'italiano: un composto di confissi non finisce con uno di questi (trazione non è tra- + -zione)
COMUNI = {'zione', 'azione', 'izione', 'mento', 'mente', 'tore', 'trice', 'tura', 'ino', 'ina', 'lino', 'lina', 'ello', 'ella',
          'etto', 'etta', 'ista', 'ismo', 'ità', 'oso', 'osa', 'ale', 'ico', 'ica', 'ario', 'aria', 'aio', 'aia', 'iere',
          'iera', 'ata', 'ato', 'uto', 'ante', 'ente', 'anza', 'enza', 'ezza', 'bile', 'evole', 'ese', 'ano', 'ana', 'one'}
DIMINUTIVI = {'ino', 'ina', 'etto', 'etta', 'ello', 'ella', 'otto', 'otta', 'uccio', 'uccia', 'one', 'ona', 'accio', 'accia',
              'astro', 'ucolo', 'icino', 'olino'}
# parole vuote delle glosse inglesi: non dicono il significato
VUOTE = set("""that with from which having being small little large great person people something someone thing make made
used relating pertaining related state quality act action process manner done does into onto than this these those
their them they what when where also very more most such other another kind type form forms part parts""".split())


def categoria(pos):
    """«s.m.», «s.f.», «s.» → «s.»; le altre come sono."""
    return 's.' if pos.startswith('s.') else pos


def parole_della_glossa(g):
    import re
    return {w for w in re.findall(r"[a-z]{4,}", (g or '').lower()) if w not in VUOTE}


def stesso_significato(g1, g2):
    """Le due glosse condividono una parola piena, anche come parte di un'altra (work/worker, possible/impossible) o
    con una radice comune lunga (anthropology/anthropological)."""
    a, b = parole_della_glossa(g1), parole_della_glossa(g2)
    def vicine(x, y):
        if x in y or y in x:
            return True
        n = 0
        while n < min(len(x), len(y)) and x[n] == y[n]:
            n += 1
        return n >= max(6, int(0.75 * min(len(x), len(y))))
    return any(vicine(x, y) for x in a for y in b)


def piano(s):
    return unicodedata.normalize('NFC', s.strip().lower())


def leggi(d, nome):
    with gzip.open(os.path.join(d, f'{nome}.tsv.gz'), 'rt', encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


POS_KAIKKI = {'noun': 's.', 'verb': 'v.', 'adj': 'agg.', 'adv': 'avv.', 'name': 'np'}


class Inventario:
    """Le voci italiane del dizionario (lemma → parti del discorso, glossa) e i suoi affissi."""

    def aggiungi_lemmi(self, glosse_tsv):
        """Tutti i lemmi italiani del dump (glosse.tsv di filtra.py: parola, numero, parte del discorso, glossa…)."""
        for r in open(glosse_tsv, encoding='utf-8'):
            c = (r.rstrip('\n').split('\t') + [''] * 6)[:6]
            lemma = piano(c[0])
            if c[5] == '1' or not lemma or ' ' in lemma or lemma.startswith('-') or lemma.endswith('-'):
                continue
            self.pos[lemma].add(POS_KAIKKI.get(c[2], ''))
            if c[3]:
                self.glossa.setdefault(lemma, c[3])

    def __init__(self, lessemi):
        self.pos, self.glossa = defaultdict(set), {}
        self.prefissi, self.suffissi = set(), set()
        for c in lessemi:
            if c[1] != 'it' or c[4] == 't':
                continue
            lemma = piano(c[2])
            if lemma.endswith('-') and not lemma.startswith('-') and len(lemma) >= 2:
                self.prefissi.add(lemma[:-1])
            elif lemma.startswith('-') and not lemma.endswith('-') and lemma not in FLESSIVI and len(lemma) >= 3:
                self.suffissi.add(lemma[1:])
            elif ' ' not in lemma and '-' not in lemma:
                self.pos[lemma].add(c[6] if c[6] != '\\N' else '')
                if c[7] != '\\N':
                    self.glossa.setdefault(lemma, c[7])

    def c_e(self, lemma, escludi):
        return lemma != escludi and lemma in self.pos

    def categorie(self, lemma):
        return {categoria(x) for x in self.pos.get(lemma, ()) if x}

    def plausibile(self, parola, base, suffisso=None):
        """Una base vera: abbastanza lunga, della categoria giusta, con un significato che la parola contiene."""
        if len(base) < 4:
            return False
        cp, cb = self.categorie(parola), self.categorie(base)
        if suffisso is None or suffisso in DIMINUTIVI:
            if cp and cb and not (cp & cb):               # un prefisso o un diminutivo non cambiano la categoria
                return False
        elif suffisso in BASE_DEL_SUFFISSO and cb and not (cb & BASE_DEL_SUFFISSO[suffisso]):
            return False
        return stesso_significato(self.glossa.get(parola), self.glossa.get(base))


def basi_del_suffisso(radice):
    """Le basi possibili quando si toglie un suffisso: veloce-mente (radice), rapid-a-mente → rapido, lavora-tore →
    lavorare, cas-etta → casa, felic-ità → felice."""
    c = [radice]
    if radice and radice[-1] in VOCALI:
        c += [radice + 're']                                   # lavora- → lavorare, aboli- → abolire
        if radice[-1] == 'a':
            c += [radice[:-1] + 'o']                            # rapida- → rapido
    else:
        c += [radice + v for v in 'oaei'] + [radice + 'ia', radice + 'are', radice + 'ere', radice + 'ire']
    return c


def proponi(parola, inv, escludi=None):
    """Le proposte per una parola: (regola, tipo, etimi, affisso), dalla più sicura alla meno sicura."""
    p = piano(parola)
    escludi = escludi or p
    out = []
    # 1. confisso + confisso: bio-logia, foto-grafia; parti di almeno tre lettere (mi- + -lite non è milite)
    for a in inv.prefissi:
        if p.startswith(a) and len(a) >= 3 and len(p) >= 6:
            resto = p[len(a):]
            if resto in inv.suffissi and len(resto) >= 3 and resto not in COMUNI:
                out.append(('confissi', 'composizione', [a + '-', '-' + resto], None))
    # 2. prefisso + parola: ri-aprire, s-caricare, in- con le sue forme (im-possibile, il-legale, ir-regolare)
    for a in inv.prefissi:
        forme = [a]
        if a == 'in':
            forme += ['im', 'il', 'ir']
        for f in forme:
            if p.startswith(f) and len(p) - len(f) >= 3:
                base = p[len(f):]
                if f in ('il', 'ir') and not base.startswith(f[1]):
                    continue
                if a == 's' and len(base) < 5:
                    continue                                    # s- + ecco non è secco
                if inv.c_e(base, escludi) and inv.plausibile(p, base):
                    out.append(('prefisso', 'derivazione', [base], a + '-'))
    # 3. parola + suffisso: rapida-mente, lavora-tore, cas-etta, felic-ità
    for s in inv.suffissi:
        if p.endswith(s) and len(p) - len(s) >= 3:
            for base in basi_del_suffisso(p[:-len(s)]):
                if inv.c_e(base, escludi) and inv.plausibile(p, base, s):
                    out.append(('suffisso', 'derivazione', [base], '-' + s))
                    break
    # gli accorciamenti (bici ← bicicletta) non si indovinano dalla forma: sul banco erano giusti il 14% delle volte
    return out


def scegli(proposte):
    """Una sola proposta. Prima le analisi che hanno superato il controllo del significato (prefisso, suffisso), poi i
    composti di confissi; a parità la base più lunga (in- + utile, non i- + nutile). Se la base del suffisso contiene
    già il prefisso, il suffisso è il passaggio più esterno: conseguentemente = conseguente + -mente."""
    if not proposte:
        return None
    pref = [x for x in proposte if x[0] == 'prefisso']
    suff = [x for x in proposte if x[0] == 'suffisso']
    for s in sorted(suff, key=lambda x: -len(x[2][0])):
        if any(s[2][0].startswith(p[3].rstrip('-')) for p in pref):
            return s
    # tra prefisso e suffisso vince la base più lunga: antropologico = antropologia + -ico, non antropo- + logico
    lessicali = pref + suff
    if lessicali:
        return max(lessicali, key=lambda x: (len(x[2][0]), x[0] == 'suffisso'))
    return proposte[0]


def banco(d):
    """Le parole italiane che Wiktionary spiega già, con i loro etimi (lemmi) e il tipo del primo passaggio."""
    lessemi = leggi(d, 'lessemi')
    lemma = {c[0]: piano(c[2]) for c in lessemi}
    accolta = {h[1]: h[0] for h in leggi(d, 'ipotesi') if h[3] == 'accolta'}
    etimi, tipo, dotto = defaultdict(set), {}, set()
    for r in leggi(d, 'relazioni'):           # chiave, ipotesi, esito, etimo, tipo, ordine, forma, affisso, confidenza
        if r[2].startswith('enwikt:it:') and accolta.get(r[2]) == r[1]:
            etimi[r[2]].add(lemma.get(r[3], '').strip('-'))
            if r[5] == '1':
                tipo[r[2]] = r[4]
                if r[3].split(':')[1] in ('la', 'la-lat', 'la-med', 'la-new', 'grc'):
                    dotto.add(r[2])          # Wiktionary dà un etimo latino o greco: un prestito dotto o un'eredità
    return lessemi, lemma, etimi, tipo, dotto


def meta(parola):
    """Metà del banco, sempre la stessa per una parola: si sceglie su una, si misura sull'altra."""
    import zlib
    return zlib.crc32(parola.encode('utf-8')) % 2


def affissi_affidabili(conteggi, soglia=0.95, minimo=20):
    """Gli affissi (regola, affisso) con una precisione almeno del 95% su almeno venti casi."""
    return {k for k, (g, n) in conteggi.items() if n >= minimo and g / n >= soglia}


def valuta(d):
    lessemi, lemma, etimi, tipo, dotto = banco(d)
    inv = Inventario(lessemi)
    conti, esempi = defaultdict(Counter), defaultdict(list)
    per_affisso = [defaultdict(lambda: [0, 0]), defaultdict(lambda: [0, 0])]    # due metà del banco
    risultati = []
    for k, gold in etimi.items():
        p = lemma[k]
        if ' ' in p or p.startswith('-') or p.endswith('-'):
            continue
        scelta = scegli(proponi(p, inv))
        formazione = tipo.get(k) in ('derivazione', 'composizione', 'accorciamento', 'retroformazione')
        if not scelta:
            conti['nessuna']['formazione' if formazione else 'altro'] += 1
            continue
        regola, _, etm, _ = scelta
        giusta = all(e.strip('-') in gold for e in etm)
        chiave_aff = (regola, scelta[3] or '+'.join(etm))
        if k not in dotto:
            per_affisso[meta(p)][chiave_aff][0] += giusta
            per_affisso[meta(p)][chiave_aff][1] += 1
            risultati.append((meta(p), chiave_aff, giusta))
        conti[regola]['giuste' if giusta else 'sbagliate'] += 1
        conti[regola]['su formazioni ' + ('giuste' if giusta else 'sbagliate')] += formazione
        if k in dotto:
            conti[regola]['con un etimo latino o greco'] += 1
        else:
            conti[regola]['senza etimo latino o greco ' + ('giuste' if giusta else 'sbagliate')] += 1
        if not giusta and k not in dotto and len(esempi[regola]) < 400:
            esempi[regola].append(f"{p}: {'+'.join(etm)}{'' if not scelta[3] else ' ' + scelta[3]} | Wiktionary: "
                                  f"{', '.join(sorted(gold))} ({tipo.get(k)})")
    print(f'banco: {len(etimi)} parole italiane con un\'etimologia in Wiktionary')
    for regola in ('confissi', 'prefisso', 'suffisso', 'accorciamento'):
        c = conti[regola]
        n = c['giuste'] + c['sbagliate']
        if n:
            nf = c['su formazioni giuste'] + c['su formazioni sbagliate']
            ns = c['senza etimo latino o greco giuste'] + c['senza etimo latino o greco sbagliate']
            print(f'  {regola}: {n} proposte, precisione {100 * c["giuste"] / n:.1f}%'
                  + (f'; dove Wiktionary dà una formazione {100 * c["su formazioni giuste"] / nf:.1f}% su {nf}' if nf else '')
                  + (f'; dove non dà un etimo latino o greco {100 * c["senza etimo latino o greco giuste"] / ns:.1f}% su {ns}' if ns else '')
                  + f' ({c["con un etimo latino o greco"]} parole dotte)')
    print(f'  nessuna proposta: {dict(conti["nessuna"])}')
    # affissi scelti sulla metà 0, misurati sulla metà 1 (e viceversa): la precisione che ci si può aspettare
    for scelta_su, misura_su in ((0, 1), (1, 0)):
        buoni = affissi_affidabili({k: tuple(v) for k, v in per_affisso[scelta_su].items() if k[0] != 'confissi'})
        g = sum(1 for m, k, ok in risultati if m == misura_su and k in buoni and ok)
        n = sum(1 for m, k, ok in risultati if m == misura_su and k in buoni)
        print(f'  affissi affidabili scelti sulla metà {scelta_su}: {len(buoni)}; sull\'altra metà {n} proposte, '
              f'precisione {100 * g / max(n, 1):.1f}%')
    # l'elenco per l'uso: gli affissi affidabili su tutto il banco, con i loro conti
    tutto = defaultdict(lambda: [0, 0])
    for m in per_affisso:
        for k, (g, n) in m.items():
            tutto[k][0] += g
            tutto[k][1] += n
    buoni = sorted(affissi_affidabili({k: tuple(v) for k, v in tutto.items() if k[0] != 'confissi'}), key=lambda k: -tutto[k][1])
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'analisi_affissi.tsv'), 'w', encoding='utf-8') as f:
        f.write('# regola\taffisso\tgiuste\tproposte — scritto da analizza.py valuta: affissi con precisione >= 95% su almeno 20 casi\n')
        for k in buoni:
            f.write(f'{k[0]}\t{k[1]}\t{tutto[k][0]}\t{tutto[k][1]}\n')
    print(f'  analisi_affissi.tsv: {len(buoni)} affissi affidabili, {sum(tutto[k][1] for k in buoni)} proposte sul banco')
    import random
    random.seed(3)
    for regola, e in esempi.items():
        print(f'— errori «{regola}»:', ' · '.join(random.sample(e, min(8, len(e)))))


def affidabili():
    """L'elenco degli affissi affidabili (analisi_affissi.tsv), come insieme di (regola, affisso)."""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'analisi_affissi.tsv')
    return {tuple(r.split('\t')[:2]) for r in open(p, encoding='utf-8') if r.strip() and not r.startswith('#')}


def proposta_sicura(parola, inv, buoni):
    """La proposta per una parola senza etimologia, solo se l'affisso scelto è tra quelli affidabili."""
    s = scegli(proponi(parola, inv))
    return s if s and (s[0], s[3] or '+'.join(s[2])) in buoni else None


def conta(glosse_tsv, d):
    """Quante proposte sicure per i lemmi italiani del dump che non hanno un'etimologia, con un campione."""
    import random
    lessemi = leggi(d, 'lessemi')
    inv = Inventario(lessemi)
    inv.aggiungi_lemmi(glosse_tsv)
    buoni = affidabili()
    con_etimo = {piano(h[1].split(':', 2)[2]) for h in leggi(d, 'ipotesi') if h[1].startswith('enwikt:it:')}
    senza = sorted({piano(r.split('\t')[0]) for r in open(glosse_tsv, encoding='utf-8')} - con_etimo)
    senza = [w for w in senza if w and ' ' not in w and not w.startswith('-') and not w.endswith('-')]
    prop = [(w, proposta_sicura(w, inv, buoni)) for w in senza]
    prop = [(w, s) for w, s in prop if s]
    per = Counter(s[3] or s[0] for _, s in prop)
    print(f'lemmi italiani senza etimologia: {len(senza)}; con una proposta sicura: {len(prop)}; per affisso: {per.most_common(15)}')
    random.seed(11)
    for w, s in random.sample(prop, min(40, len(prop))):
        print(f'  {w} = ' + (f'{s[2][0]} + {s[3]}' if s[0] == 'suffisso' else f'{s[3]} + {s[2][0]}'))


if __name__ == '__main__':
    if sys.argv[1] == 'valuta':
        valuta(sys.argv[2])
    elif sys.argv[1] == 'conta':
        conta(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'proponi':
        inv = Inventario(leggi(sys.argv[2], 'lessemi'))
        for w in sys.argv[3:]:
            print(w, '→', proponi(w, inv))
