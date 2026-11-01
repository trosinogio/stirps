#!/usr/bin/env python3
"""Lemmi dei dizionari del Perseus Digital Library (CC BY-SA): il Lewis & Short per il latino e il Liddell–Scott–Jones
per il greco antico, dai file TEI del repository PerseusDL/lexica. Una riga per lemma (stg_dizionario):

    chiave, lingua, lemma, omografo, ricostruito (sempre f), traslitterazione, parte del discorso, glossa inglese

come lessemi.tsv del parser di Wiktionary, così servono gli stessi strumenti (la traduzione delle glosse).

La chiave è l'identificativo della voce nel file TEI (perseus:ls:n12345, perseus:lsj:n6789). Il lemma è scritto come
il titolo di Wiktionary (senza quantità; per il latino i al posto di j, come in Wiktionary), così le voci che Wiktionary
ha già si riconoscono: con --escludi lessemi.tsv restano fuori. Il greco dell'LSJ è in Beta Code e diventa Unicode, con
la traslitterazione di Wiktionary (serve all'indirizzo). Restano fuori le voci spurie del Lewis & Short.
Solo libreria standard.

    python3 filtra_perseus.py uscita.tsv [--escludi lessemi.tsv] lat.ls.perseus-eng2.xml grc.lsj.perseus-eng1.xml …
"""
import re, sys, unicodedata, xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from wiktionary import nome_pagina, translit_grc, base_lingua   # gli stessi titoli e la stessa traslitterazione

# ---- Beta Code (TLG) → Unicode ----
LETTERE = dict(zip('abgdezhqiklmncoprstufxywv', 'αβγδεζηθικλμνξοπρστυφχψωϝ'))
SEGNI = {')': '̓', '(': '̔', '/': '́', '\\': '̀', '=': '͂', '+': '̈', '|': 'ͅ'}
QUANTITA = '_^'                               # macron e breve: via, come nei titoli di Wiktionary
ORDINE = {'̓': 0, '̔': 0, '̈': 1, '́': 2, '̀': 2, '͂': 2, 'ͅ': 3}


def da_beta(b):
    """«*)/abrwn» → «Ἄβρων», «a)/atos» → «ἄατος»: lettere, spiriti, accenti, dieresi, iota sottoscritto; niente quantità."""
    lettere, pendenti, maiuscola, i, n = [], [], False, 0, len(b)
    while i < n:
        c = b[i]
        if c == '*':                          # maiuscola: i segni vengono prima della lettera (*)/a = Ἄ)
            maiuscola, i = True, i + 1
            while i < n and (b[i] in SEGNI or b[i] in QUANTITA):
                if b[i] in SEGNI:
                    pendenti.append(SEGNI[b[i]])
                i += 1
            continue
        basso = c.lower()
        if basso in LETTERE:
            lettera = LETTERE[basso]
            if basso == 's' and i + 1 < n and b[i + 1] in '123':
                lettera, i = {'1': 'σ', '2': 'ς', '3': 'ϲ'}[b[i + 1]], i + 1
            if maiuscola:
                lettera, maiuscola = lettera.upper(), False
            lettere.append([lettera, pendenti])
            pendenti, i = [], i + 1
            while i < n and (b[i] in SEGNI or b[i] in QUANTITA):
                if b[i] in SEGNI:
                    lettere[-1][1].append(SEGNI[b[i]])
                i += 1
            continue
        if c in SEGNI and lettere:
            lettere[-1][1].append(SEGNI[c])
        elif c == "'":
            lettere.append(['’', []])
        elif c not in QUANTITA and not c.isdigit():
            lettere.append([c, []])
        i += 1
    testo = []
    for k, (lettera, segni) in enumerate(lettere):
        if lettera == 'σ' and (k + 1 == len(lettere) or not lettere[k + 1][0].isalpha()):
            lettera = 'ς'                     # sigma finale
        testo.append(lettera + ''.join(sorted(set(segni), key=ORDINE.get)))
    return unicodedata.normalize('NFC', ''.join(testo))


GRECO = re.compile(r'^[Ͱ-Ͽἀ-῿’\-]+$')
SPAZI = re.compile(r'\s+')
ABBREVIAZIONE = re.compile(r'^\S{1,8}\.$')    # «init.», «comp.», «Lit.»: non sono glosse
# note grammaticali e di rimando in corsivo: «gen. plur.», «comp.», «v. abacus»
GRAMMATICA = re.compile(r'^(gen|dat|acc|abl|voc|nom|plur|sing|comp|sup|fem|masc|neutr?|part|perf|pres|fut|imperf|inf|subj|'
                        r'act|pass|dep|absol?|init|fin|lit|trop|transf|fig|poet|esp|ante|post|class|ap|ib|id|al|v|cf|sc|'
                        r'i\. ?e|e\. ?g|q\. ?v|sq|sqq)\b\.?', re.I)


def testo(el):
    return SPAZI.sub(' ', ''.join(el.itertext())).strip() if el is not None else ''


def breve(g):
    """La glossa in breve: senza le note grammaticali in coda («good; comp.» → «good»), e al primo punto e virgola
    se è lunga."""
    parti = [p.strip(' .,:') for p in g.split(';')]
    parti = [parti[0]] + [p for p in parti[1:] if p and not GRAMMATICA.match(p) and len(p.split()) > 1]
    g = '; '.join(p for p in parti if p)
    if len(g) > 80:
        g = parti[0]
    return g[:200].rstrip(' .;,:')


def abbreviazioni(g):
    """«doub. dim.», «pron. demonstr.»: solo parole abbreviate, una nota grammaticale."""
    parole = g.split()
    return all(p.endswith('.') and len(p) <= 10 for p in parole)


def glossa_ls(voce):
    """Il primo corsivo che sia una definizione: in bene il primo è una «e» nella nota sull'etimo, poi viene «well».
    Un corsivo attaccato alla parola che lo precede è un pezzo di parola (POSIER<hi>unt</hi> in pono), non una glossa."""
    genitori = {figlio: padre for padre in voce.iter() for figlio in padre}
    for hi in voce.iter('hi'):
        if hi.get('rend') != 'ital':
            continue
        padre = genitori.get(hi)
        prima = ''
        if padre is not None:
            figli = list(padre)
            i = figli.index(hi)
            prima = (figli[i - 1].tail if i else padre.text) or ''
        if prima[-1:].isalnum():
            continue
        g = testo(hi).strip(' ;,:')
        if len(g) < 3 or ABBREVIAZIONE.match(g) or GRAMMATICA.match(g) or abbreviazioni(g):
            continue
        return breve(g)
    return ''


def titolo(t):
    """«Aus Lydien»: un titolo citato, che l'LSJ a volte marca come traduzione (in δαήρ, prima di «husband's brother»)."""
    parole = t.split()
    return len(parole) >= 2 and all(p[:1].isupper() for p in parole)


def glossa_lsj(voce):
    """La prima traduzione del primo senso che ne ha, saltando i titoli citati («God» per θεός, non «against his will»
    di un senso successivo). Senza sensi tradotti, la prima traduzione della voce."""
    for senso in [s for s in voce.iter('sense')] + [voce]:
        tr = [testo(t).strip(' ;,:') for t in senso.iter('tr')]
        tr = [t for t in tr if t]
        if tr:
            return breve(next((t for t in tr if not titolo(t)), tr[0]))
    return ''


def pos_ls(voce, lemma):
    p = testo(voce.find('pos')).lower()
    g = testo(voce.find('gen')).lower()
    if p.startswith('v'):
        return 'v.'
    if 'adj' in p or p == 'p. a.':
        return 'agg.'
    if p.startswith('adv'):
        return 'avv.'
    if p.startswith('interj'):
        return 'inter.'
    if p.startswith('prep'):
        return 'prep.'
    if g or p.startswith('subst'):
        if lemma[:1].isupper():
            return 'np'
        return 's.m.' if g.startswith('m') else 's.f.' if g.startswith('f') else 's.'
    return 'np' if lemma[:1].isupper() else None


def pos_lsj(lemma):
    if lemma[:1].isupper():
        return 'np'
    if lemma.endswith(('ω', 'ομαι', 'μι', 'ῶ', 'οῦμαι', 'ῶμαι')):
        return 'v.'
    return None


def leggi(percorso, voci, conta):
    lsj = '.lsj.' in percorso
    for _, el in ET.iterparse(percorso, events=('end',)):
        if el.tag != 'entryFree':
            continue
        tipo, chiave_dz, ident = el.get('type') or 'main', el.get('key') or '', el.get('id') or ''
        conta[('lsj' if lsj else 'ls', tipo)] += 1
        if tipo == 'spur' or not chiave_dz or not ident:
            el.clear()
            continue
        base = re.sub(r'\d+$', '', chiave_dz).strip()
        if lsj:
            lingua, lemma = 'grc', da_beta(base).strip(' ,.:;')
            if not GRECO.match(lemma or '-'):
                conta['lsj_scartate_scrittura'] += 1
                el.clear()
                continue
            glossa, pos = glossa_lsj(el), pos_lsj(lemma)
        else:
            lingua = 'la'
            lemma = base.replace('j', 'i').replace('J', 'I').replace('æ', 'ae').replace('œ', 'oe')
            lemma = re.sub(r'[^\w\- ]', '', lemma).strip()
            if not lemma:
                el.clear()
                continue
            glossa, pos = glossa_ls(el), pos_ls(el, lemma)
        lemma = nome_pagina(lingua, unicodedata.normalize('NFC', lemma))
        voci.append([f"perseus:{'lsj' if lsj else 'ls'}:{ident}", lingua, lemma, pos, glossa])
        el.clear()


def esc(v):
    return '\\N' if v is None or v == '' else str(v).replace('\\', '\\\\').replace('\t', ' ').replace('\n', ' ')


def gia_presenti(percorso):
    """Lingua e lemma delle voci attestate di lessemi.tsv (l'uscita del parser di Wiktionary)."""
    presenti = set()
    for riga in open(percorso, encoding='utf-8'):
        c = riga.rstrip('\n').split('\t')
        if len(c) > 4 and c[4] != 't':
            presenti.add((base_lingua(c[1]), c[2]))
    return presenti


if __name__ == '__main__':
    args = sys.argv[1:]
    escludi = set()
    if '--escludi' in args:
        i = args.index('--escludi')
        escludi = gia_presenti(args[i + 1])
        del args[i:i + 2]
    uscita, file = args[0], args[1:]
    voci, conta = [], Counter()
    for f in file:
        leggi(f, voci, conta)
    # omografi: numerati per lingua e lemma, nell'ordine del dizionario (liber¹ «libero», liber² «libro»)
    numero = defaultdict(int)
    with open(uscita, 'w', encoding='utf-8') as out:
        for chiave, lingua, lemma, pos, glossa in voci:
            if (lingua, lemma) in escludi:
                conta[f'gia_in_wiktionary_{lingua}'] += 1
                continue
            numero[(lingua, lemma)] += 1
            tr = translit_grc(lemma) if lingua == 'grc' else None
            out.write('\t'.join(esc(x) for x in (chiave, lingua, lemma, numero[(lingua, lemma)], 'f', tr, pos, glossa)) + '\n')
            conta[f'lemmi_{lingua}'] += 1
    conta['lemmi_distinti_la'] = sum(1 for (l, _) in numero if l == 'la')
    conta['lemmi_distinti_grc'] = sum(1 for (l, _) in numero if l == 'grc')
    print(dict(sorted((str(k), v) for k, v in conta.items())), file=sys.stderr)
