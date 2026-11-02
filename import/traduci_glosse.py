# Traduce in italiano le glosse inglesi di Wiktionary delle parole non italiane (etimi), con un modello OPUS/Argos
# per CTranslate2 (inglese → italiano). Le traduzioni sono dichiarate come automatiche nel dizionario.
#   python3 traduci_glosse.py lessemi.tsv modello/ uscita.tsv [--prova N]
import re, sys, time, random
import ctranslate2, sentencepiece as spm

GRAMMATICALI = re.compile(r'\b(plural|singular|genitive|dative|accusative|nominative|vocative|ablative|locative|instrumental|'
                          r'participle|infinitive|inflection|conjugation|declension|form|spelling|alternative|abbreviation|'
                          r'romanization|transliteration|diminutive|comparative|superlative) of\b', re.I)
ETICHETTA = re.compile(r'^\s*\(([^()]*)\)\s*')

def prepara(g):
    """La glossa da tradurre: senza le etichette iniziali tra parentesi; None se è una descrizione grammaticale."""
    g = ' '.join(g.split())
    if not g or GRAMMATICALI.search(g) or len(g) > 90:
        return None
    while ETICHETTA.match(g):
        g = ETICHETTA.sub('', g, count=1)
    g = g.strip(' .;')
    return g or None

PAROLE_VUOTE = {'a', 'an', 'the', 'to', 'of', 'or', 'and', 'in', 'on', 'for', 'with', 'by', 'one', 'something', 'someone'}

def sensi(g):
    """I sensi di una glossa: separati da virgole e punti e virgola fuori dalle parentesi (al massimo cinque).
    Le spiegazioni tra parentesi si tolgono (il modello le traduce male); «asunder» diventa «apart»."""
    while re.search(r'\([^()]*\)', g):
        g = re.sub(r'\s*\([^()]*\)', '', g)
    g = re.sub(r'\basunder\b', 'apart', g, flags=re.I)
    parti, prof, cur = [], 0, ''
    for ch in g:
        prof += ch == '('
        prof -= ch == ')'
        if ch in ',;' and prof == 0:
            parti.append(cur); cur = ''
        else:
            cur += ch
    parti.append(cur)
    return [x.strip() for x in parti if x.strip()][:5]

def norm_en(x):
    x = re.sub(r'[^a-z ]', ' ', x.lower())
    return ' '.join(w for w in x.split() if w not in PAROLE_VUOTE)

# parole che non devono mai comparire in una glossa: il modello rende «asunder» con una volgarità
VIETATE = re.compile(r'\b(cul[oi]|cazz\w*|merd\w*|fig[ao]|fic[ao]|troi\w*|puttan\w*|stronz\w*|coglion\w*|minchi\w*|fott\w*|incul\w*|sborr\w*|vaffa\w*)\b', re.I)
ACCENTI = {'a': 'à', 'e': 'è', 'i': 'ì', 'o': 'ò', 'u': 'ù'}
NOME_PROPRIO = re.compile(r'^an? (male|female) given name\b', re.I)
INFINITO = re.compile(r"^(\w+(are|ere|ire|rre|arsi|ersi|irsi|orsi|arne|erne|irne|arla|erla|irla|arlo|erlo|irlo|arci|erci|irci)|essere|avere|fare|dare|stare|dire|porre)\b", re.I)

def ripulisci(en, it):
    it = ' '.join(it.strip().rstrip('.').split())
    it = re.sub(r"([aeiou])'(?=[\s,;)]|$)", lambda m: ACCENTI[m.group(1)], it)    # «utilita'» → «utilità»
    if en.lower().startswith('to '):
        it = re.sub(r'^(a|per|di|da) ', '', it, flags=re.I)      # «to roar» → «ruggire», non «a ruggire»
    parole = it.split(' ')
    it = ' '.join(w for k, w in enumerate(parole) if k == 0 or w.lower() != parole[k - 1].lower())   # «cane cane» → «cane»
    if en[:1].islower() and it[:1].isupper() and not it[1:2].isupper():
        it = it[:1].lower() + it[1:]
    return it

def traduci(tr, sp, testi, beam=4):
    ris = tr.translate_batch([sp.encode(x + '.', out_type=str) for x in testi], beam_size=beam, max_decoding_length=40)
    return [sp.decode(r.hypotheses[0]) for r in ris]

def main():
    sorgente, modello, uscita = sys.argv[1:4]
    ritorno = sys.argv[sys.argv.index('--ritorno') + 1] if '--ritorno' in sys.argv else modello.replace('en_it', 'it_en')
    prova = int(sys.argv[sys.argv.index('--prova') + 1]) if '--prova' in sys.argv else 0
    chiavi = set(open(sys.argv[sys.argv.index('--chiavi') + 1], encoding='utf-8').read().split('\n')) if '--chiavi' in sys.argv else None
    parte = sys.argv[sys.argv.index('--parte') + 1] if '--parte' in sys.argv else None     # «1/3»: un terzo delle voci
    righe, fisso = [], {}
    for r in open(sorgente, encoding='utf-8'):
        c = r.rstrip('\n').split('\t')
        if len(c) < 8 or c[1] == 'it' or c[7] in ('', '\\N') or (chiavi is not None and c[0] not in chiavi):
            continue
        if parte and int(parte.split('/')[0]) - 1 != sum(map(ord, c[0])) % int(parte.split('/')[1]):
            continue
        en = prepara(c[7].replace('\\t', ' '))
        if en and NOME_PROPRIO.match(en):              # «a male given name, equivalent to …»: una regola, non il modello
            fisso[c[0]] = 'nome proprio ' + ('maschile' if NOME_PROPRIO.match(en).group(1).lower() == 'male' else 'femminile')
            continue
        if en and sensi(en):
            righe.append((c[0], c[7], sensi(en)))
    if prova:
        random.seed(1); righe = random.sample(righe, min(prova, len(righe)))
    # il vocabolario italiano: le forme del lessico di frequenza e i lemmi italiani del dizionario. Una parola che
    # non c'è è un'invenzione del modello («esecorazione»): il senso si scarta
    vocabolario = set()
    if '--vocabolario' in sys.argv:
        import gzip
        for f in sys.argv[sys.argv.index('--vocabolario') + 1].split(','):
            apri = gzip.open if f.endswith('.gz') else open
            for r in apri(f, 'rt', encoding='utf-8'):
                c = r.rstrip('\n').split('\t')
                parola = c[2] if len(c) >= 8 and c[1] == 'it' else c[1] if len(c) >= 3 and c[0] == 'it' else None
                if parola:
                    vocabolario.add(parola.lower())
        print(f'vocabolario italiano: {len(vocabolario)} parole', file=sys.stderr)
    # il dizionario rovesciato, dalle glosse inglesi delle parole italiane del dizionario: «honey» → miele.
    # primi: le parole italiane il cui primo senso è proprio quello; tutti: quelle che lo hanno tra i sensi
    import gzip, os
    rango = {}
    frequenze = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dati', 'frequenze_it.tsv.gz')
    for r in gzip.open(frequenze, 'rt', encoding='utf-8'):
        c = r.split('\t')
        if len(c) >= 3 and c[0] == 'it':
            rango.setdefault(c[1].lower(), int(c[2]))
    primi, tutti = {}, {}
    for r in open(sorgente, encoding='utf-8'):
        c = r.rstrip('\n').split('\t')
        if len(c) < 8 or c[1] != 'it' or c[7] in ('', '\\N') or c[2].lower() not in rango:
            continue
        ss = [norm_en(x) for x in sensi(c[7])]
        for k, x in enumerate(ss):
            if x and ' ' not in x:
                (primi if k == 0 else tutti).setdefault(x, set()).add(c[2].lower())
    for x, v in primi.items():
        tutti.setdefault(x, set()).update(v)
    print(f'dizionario rovesciato: {len(primi)} parole inglesi', file=sys.stderr)

    def coerente(en, it):
        """Il senso tradotto rispetta il dizionario rovesciato?"""
        parole = [w for w in norm_en(en).split()]
        it_l = it.lower()
        if len(parole) == 1:
            w = parole[0]
            if w in primi:
                return it_l in primi[w] or (len(primi[w]) == 1 and next(iter(primi[w])))
            if w in tutti:
                return it_l in tutti[w]
            return True
        for w in parole:                       # nelle frasi: ogni parola con un solo candidato deve esserci
            if w in primi and len(primi[w]) == 1:
                cand = next(iter(primi[w]))
                if cand[:4] not in it_l:
                    return False
        return True
    sp_en = spm.SentencePieceProcessor(model_file=f'{modello}/sentencepiece.model')
    sp_it = spm.SentencePieceProcessor(model_file=f'{ritorno}/sentencepiece.model')
    andata = ctranslate2.Translator(f'{modello}/model', device='cpu', compute_type='int8', inter_threads=1, intra_threads=1)
    indietro = ctranslate2.Translator(f'{ritorno}/model', device='cpu', compute_type='int8', inter_threads=1, intra_threads=1)
    t0 = time.time()
    uniche = sorted({x for _, _, ss in righe for x in ss})
    it_di = {}
    for i in range(0, len(uniche), 64):
        blocco = uniche[i:i + 64]
        for en, it in zip(blocco, traduci(andata, sp_en, blocco)):
            it = ripulisci(en, it)
            if not it or norm_en(it) == norm_en(en):         # ricopiato, non tradotto («bridle» → «Bridle»)
                continue
            if VIETATE.search(it):
                continue
            if vocabolario and any(w not in vocabolario for w in re.findall(r"[a-zàèéìòóù]{3,}", it)):
                continue
            ok = coerente(en, it)
            if not ok:
                continue
            if isinstance(ok, str):
                it = ok                              # una sola parola, un solo candidato: quello («honey» → «miele»)
            # una parola inglese minuscola rimasta nella traduzione: «a type of vetch» → «un tipo di vetch»
            parole_it = set(re.findall(r'\w+', it.lower()))
            if any(w in parole_it for w in re.findall(r'\b[a-z]{4,}\b', en) if w not in PAROLE_VUOTE):
                continue
            it_di[en] = it
        if i % 2560 == 0 and i:
            print(f'  andata {i}/{len(uniche)} ({time.time() - t0:.0f} s)', file=sys.stderr)
    italiane = sorted(set(it_di.values()))
    en_di = {}
    for i in range(0, len(italiane), 64):
        blocco = italiane[i:i + 64]
        for it, en in zip(blocco, traduci(indietro, sp_it, blocco)):
            en_di[it] = norm_en(en)
    scritte = 0
    with open(uscita, 'w', encoding='utf-8') as f:
        for chiave, g in fisso.items():
            f.write(f'{chiave}\t\t{g}\n')
        for chiave, originale, ss in righe:
            ammessi = {norm_en(x) for x in ss}
            verbale = ss[0].lower().startswith('to ')         # «to cry, roar, low»: tutti i sensi sono verbi
            buoni = []
            for x in ss:
                it = it_di.get(x)
                if it and verbale and not INFINITO.match(it):
                    it = None                                 # «low» → «basso», «be aware» → «sii consapevole»: no
                if not it:
                    if x == ss[0]:
                        break
                    continue
                back = en_di.get(it, '')
                contenuto = {w for w in norm_en(x).split() if len(w) >= 4}
                # il ritorno deve ridare questo senso o un altro senso della stessa glossa (o una sua parola piena)
                if back in ammessi or (contenuto and contenuto & set(back.split())):
                    if it.lower() not in (b.lower() for b in buoni):
                        buoni.append(it)
                elif x == ss[0]:
                    break                                  # il senso principale non torna: niente glossa
            if buoni and it_di.get(ss[0]) == buoni[0] if buoni else False:
                f.write(f'{chiave}\t{originale}\t{", ".join(buoni)}\n')
                scritte += 1
            else:
                f.write(f'{chiave}\t{originale}\t\n')   # scartata: registrata, così un nuovo pacchetto non la ritraduce
    print(f'glosse {len(righe)}, sensi unici {len(uniche)}, tradotte e confermate {scritte}, tempo {time.time() - t0:.1f} s', file=sys.stderr)

if __name__ == '__main__':
    main()
