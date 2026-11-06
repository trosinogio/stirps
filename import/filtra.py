# Filtra il dump di Kaikki: lemmi con etimologia (JSONL) e glosse di tutti i lemmi (TSV).
import json, os, re, sys
from collections import Counter
LINGUA = os.environ.get('LINGUA', 'it')
UTILI = {'inh', 'inh+', 'bor', 'bor+', 'lbor', 'slbor', 'ubor', 'obor', 'der', 'der+', 'uder', 'cal', 'calque', 'sl', 'psm',
         'bf', 'back-form', 'clipping', 'ellipsis', 'af', 'affix', 'suffix', 'prefix', 'confix', 'compound', 'blend',
         'named-after', 'onom', 'onomatopoeic', 'unk', 'unc', 'root', 'doublet', 'dbt', 'it-deverbal', 'etydate'}
MENZIONI = {'m', 'l', 'm+', 'mention', 'link', 'l-self'}
# abbreviazioni dei modelli classici, con gli stessi argomenti
ALIAS = {'suf': 'suffix', 'pre': 'prefix', 'com': 'compound', 'com+': 'compound', 'con': 'confix', 'univ': 'af',
         'univerbation': 'af', 'back-formation': 'bf', 'learned borrowing': 'lbor', 'semi-learned borrowing': 'slbor',
         'borrowed': 'bor', 'inherited': 'inh', 'derived': 'der'}
# i modelli che portano un etimo (gli altri utili sono radici, date, doppioni, origini ignote…)
CON_ETIMO = {'inh', 'inh+', 'bor', 'bor+', 'lbor', 'slbor', 'ubor', 'obor', 'der', 'der+', 'uder', 'cal', 'calque', 'sl',
             'psm', 'bf', 'back-form', 'clipping', 'ellipsis', 'af', 'affix', 'suffix', 'prefix', 'confix', 'compound',
             'blend', 'it-deverbal'}
# {{ety}} e {{etymon}}, il sistema nuovo di Wiktionary (21.527 voci latine a novembre 2026): argomento 1 la lingua della
# voce, poi parole chiave con i due punti (:inh, :bor, :af…) seguite dai loro termini, «lingua:termine<id:…><alt:…><t:…>»
# o solo «termine» se è della stessa lingua; senza parola chiave vale :from. Dicono solo il primo livello: gli etimi
# hanno le loro voci. Si convertono nel modello classico equivalente, e il parser resta com'è.
ETY_CHIAVI = {'inh': 'inh', 'bor': 'bor', 'ubor': 'ubor', 'obor': 'obor', 'lbor': 'lbor', 'slbor': 'slbor', 'der': 'der',
              'from': 'der', 'calque': 'cal', 'cal': 'cal', 'sl': 'sl', 'psm': 'psm', 'bf': 'bf', 'back-formation': 'bf',
              'clipping': 'clipping', 'ellipsis': 'ellipsis', 'af': 'af', 'afeq': 'af', 'affix': 'af', 'compound': 'af',
              'com': 'af', 'univ': 'af', 'univerbation': 'af', 'blend': 'blend'}


# I preverbi latini e greci: in {{ety|la|:af|ad<id:to>|quiēscō}} il preverbo è scritto come parola, ma il composto
# va con il verbo (acquiēscō < quiēscō), come nel modello classico {{af|la|ad-|quiēscō}}
PREVERBI = {'la': {'a', 'ab', 'abs', 'ad', 'ante', 'circum', 'com', 'con', 'cum', 'contra', 'de', 'di', 'dis', 'e', 'ex',
                   'extra', 'in', 'inter', 'intro', 'ob', 'per', 'post', 'prae', 'praeter', 'pro', 're', 'red', 'retro',
                   'se', 'sub', 'subter', 'super', 'supra', 'trans'},
            'grc': {'αμφι', 'ανα', 'αντι', 'απο', 'δια', 'εισ', 'εκ', 'εξ', 'εν', 'επι', 'κατα', 'μετα', 'παρα', 'περι',
                    'προ', 'προσ', 'συν', 'συμ', 'ξυν', 'υπερ', 'υπο'}}


def _piano(s):
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFD', s) if not unicodedata.combining(c)).lower().replace('ς', 'σ')


def preverbo(termine, lingua):
    '''«ad<id:to>» in un composto latino → «ad-»: un preverbo davanti al verbo è un prefisso.'''
    base = re.sub(r'<[^<>]*>', '', termine).strip()
    m = re.match(r'^([a-z]{2,3}(?:-[a-z]{2,4})*):(.+)$', base)
    lt, parola = (m.group(1), m.group(2)) if m else (lingua, base)
    lt = 'la' if lt.startswith('la') else 'grc' if lt.startswith('grc') else lt
    if parola.endswith('-') or _piano(parola) not in PREVERBI.get(lt, ()):
        return termine
    return termine.replace(parola, parola + '-', 1)


def porta_etimo(t):
    '''Un modello classico che dà davvero un etimo: {{suffix|la|-ia}} senza la base (audientia, fabella) non lo dà, e
    allora vale {{ety}}, se c'è.'''
    n, a = t.get('name'), t.get('args') or {}
    if n not in CON_ETIMO:
        return False
    parti = [re.sub(r'<[^<>]*>', '', v).strip() for k, v in sorted(a.items()) if k.isdigit() and int(k) >= 2 and v and v.strip()]
    if n in ('af', 'affix', 'suffix', 'prefix', 'confix', 'compound', 'blend'):
        return len(parti) >= 2 or any(p and not p.startswith('-') and not p.endswith('-') for p in parti)
    if n in ('bf', 'back-form', 'clipping', 'ellipsis', 'it-deverbal'):
        return bool(parti)
    return bool(re.sub(r'<[^<>]*>', '', a.get('3') or '').strip('*- '))


def da_ety(t, lingua):
    '''Un {{ety}}/{{etymon}} come modello classico: {{ety|la|:af|fābula<id:discourse>|-lus<alt:-la>}} → {{af|la|…}},
    {{ety|it|:inh|la:aquila}} → {{inh|it|la|aquila}}. :influence, :cog e le chiavi che non danno un etimo non contano.
    None se non c'è un etimo.'''
    a = t.get('args') or {}
    lv = (a.get('1') or lingua).strip()
    gruppi, chiave, termini = [], 'from', []
    for _, x in sorted((int(k), v) for k, v in a.items() if k.isdigit() and int(k) >= 2 and v and v.strip()):
        x = x.strip()
        if x.startswith(':'):
            if termini:
                gruppi.append((chiave, termini))
                termini = []
            chiave = re.split(r'[<\s]', x[1:], maxsplit=1)[0]
        else:
            termini.append(x)
    if termini:
        gruppi.append((chiave, termini))
    for chiave, termini in gruppi:
        nome = ETY_CHIAVI.get(chiave)
        if not nome:
            continue
        if nome in ('af', 'blend'):
            termini = [preverbo(x, lv) if i < len(termini) - 1 else x for i, x in enumerate(termini)]
            return {'name': nome, 'args': {'1': lv, **{str(i): x for i, x in enumerate(termini, 2)}}, 'expansion': ''}
        x = termini[0]
        mod = dict(re.findall(r'<(\w+):([^<>]*)>', x))
        termine = re.sub(r'<[^<>]*>', '', x).strip()
        m = re.match(r'^([a-z]{2,3}(?:-[a-z]{2,4})*):(.*)$', termine)
        lt, termine = (m.group(1), m.group(2).strip()) if m else (lv, termine)
        if not termine.strip('*- '):
            continue                        # «itc-pro:» senza parola: nessun etimo
        if nome in ('bf', 'clipping', 'ellipsis'):
            return {'name': nome, 'args': {'1': lv, '2': termine if lt == lv else f'{lt}:{termine}'}, 'expansion': ''}
        args = {'1': lv, '2': lt, '3': termine}
        for k, dove in (('alt', '4'), ('t', 't'), ('id', 'id')):
            if mod.get(k):
                args[dove] = mod[k]
        return {'name': nome, 'args': args, 'expansion': ''}
    return None
DA_TESTO = re.compile(r'^\s*(from|derived from|deverbal from|back-formation from)\b', re.I)
# Le glosse che descrivono una forma flessa: «second-person plural present passive indicative/imperative of contemperō»,
# «genitive singular of nox», «superlative degree of piccolo», «past participle of fare». Servono quando Wiktionary non
# marca il senso come forma (form_of, tag form-of): succede a qualche migliaio di voci latine e greche. Le varianti
# («alternative form of», «Epic form of») non sono forme flesse e non corrispondono.
FORMA = re.compile(r'^(?:\([^)]*\)\s*)*(?:'
                   r'(?:first|second|third)-person\b'
                   r'|(?:nominative|genitive|dative|accusative|ablative|vocative|locative|instrumental|masculine|feminine|neuter)\b'
                   r'(?:[ /-][a-z]+)*?\s+(?:singular|plural|dual)\b'
                   r'|(?:plural|singular|dual|inflection|gerund|supine)\s+of\b'
                   r'|(?:(?:present|perfect|future|past|aorist|imperfect)\s+)?(?:(?:active|passive|middle|mediopassive)\s+)?'
                   r'(?:infinitive|participle)\s+of\b'
                   r'|(?:comparative|superlative)(?:\s+degree)?\s+of\b'
                   r'|(?:simple\s+)?past\s+tense\b|simple\s+past\b)', re.I)      # inglese: «simple past tense and past participle of»

# Le voci che non sono parole: sigle e abbreviazioni (NASA, BBC, SPQR), simboli, caratteri, segni d'interpunzione.
# Le sigle diventate parole minuscole (laser, radar) restano.
NON_PAROLE = {'abbrev', 'symbol', 'character', 'punct'}


def non_parola(v):
    w = v.get('word') or ''
    return v.get('pos') in NON_PAROLE or (w.isupper() and sum(c.isalpha() for c in w) > 1)


def pronuncia(v):
    '''La pronuncia della voce, da Wiktionary (CC BY-SA): fino a quattro trascrizioni IPA con la loro varietà
    («Classical-Latin», «Received-Pronunciation»), la sillabazione e un file audio di Wikimedia Commons. None se
    Wiktionary non ne dà.'''
    ipa, audio = [], None
    for s in v.get('sounds') or []:
        if s.get('ipa'):
            if len(ipa) < 4 and s['ipa'] not in (x[0] for x in ipa):
                ipa.append([s['ipa'], ','.join(s.get('tags') or [])])
        elif not audio and (s.get('audio') or s.get('ogg_url') or s.get('mp3_url')):
            audio = s.get('audio') or (s.get('ogg_url') or s.get('mp3_url')).rsplit('/', 1)[-1]
    sill = next(('‧'.join(h['parts']) for h in (v.get('hyphenations') or []) if isinstance(h, dict) and h.get('parts')), None) \
        or next((h for h in (v.get('hyphenation') or []) if isinstance(h, str) and h), None)
    d = {k: x for k, x in (('i', ipa), ('s', sill), ('a', audio)) if x}
    return d or None


def marcata(v):
    '''Forma flessa marcata da Wiktionary: il modello nonlemma, o tutti i sensi con form_of o il tag form-of.'''
    if any(t.get('name') == 'nonlemma' for t in v.get('etymology_templates') or []):
        return True
    sensi = v.get('senses') or []
    return bool(sensi) and all(s.get('form_of') or 'form-of' in (s.get('tags') or []) for s in sensi)


def forma_flessa(v):
    '''Una voce che è soltanto una forma flessa di un altro lemma (amamus, noctem, vicinissimo) non è una voce del
    dizionario. Lo è se ogni senso con una glossa è una forma: marcato da Wiktionary (form_of, tag form-of) o
    riconoscibile dalla glossa (FORMA). Basta un senso che non sia una forma perché la voce resti un lemma.'''
    if marcata(v):
        return True
    sensi = v.get('senses') or []
    con_glossa = [s for s in sensi if s.get('glosses')]
    return bool(con_glossa) and all(s.get('form_of') or 'form-of' in (s.get('tags') or []) or FORMA.match(s['glosses'][0])
                                    for s in con_glossa)


def lemma_della_forma(v):
    '''Il lemma di una forma flessa e le etichette della forma, per forme.tsv: da form_of, o dalla glossa quando
    Wiktionary non marca il senso («second-person plural … of contemperō» → contemperō). None se non si trova.'''
    for s in v.get('senses') or []:
        for fo in (s.get('form_of') or [])[:1]:
            if fo.get('word'):
                return fo['word'], s.get('tags') or []
    for s in v.get('senses') or []:
        g = (s.get('glosses') or [''])[0]
        m = FORMA.match(g) and re.search(r'\bof\s+([^\s(),;:]+)', g)
        if m:
            return m.group(1), [x for x in re.split(r'[\s/]+', g[:m.start()].lower()) if x]
    return None


def menzione_come_der(v):
    """Un'etimologia scritta solo nel testo, con i modelli di menzione: «From the verb {{m|it|segare}}». Se il testo
    comincia con «From» (o «Derived from», «Deverbal from», «Back-formation from») e la voce non ha modelli etimologici,
    la prima menzione diventa un der: un legame indeterminato, o una derivazione, mai un'eredità. Solo se la menzione sta
    nella prima frase, quella del «From», e la frase non parla di composti (+), influenze o confronti: in «From dividere,
    influenced by French devise» devise non è l'etimo."""
    tpl = v.get('etymology_templates') or []
    testo = v.get('etymology_text') or ''
    if any(t.get('name') in UTILI for t in tpl) or not DA_TESTO.match(testo):
        return []
    frase = re.split(r'[.,;:(]', testo, maxsplit=1)[0]
    if re.search(r'\+|influenc|compare|\bcf\b', frase, re.I):
        return []
    m = next((t for t in tpl if t.get('name') in MENZIONI and (t.get('args') or {}).get('2')), None)
    if m is None or (m.get('expansion') or m['args']['2']) not in frase:
        return []
    a = m['args']
    return [{'n': 'der', 'a': {'1': v.get('lang_code'), '2': a['1'], '3': a['2'], **({'t': a['4']} if a.get('4') else {})},
             'e': m.get('expansion', '')}]


if __name__ == '__main__':
    n = tenuti = flesse = senza = promosse = flesse_dalla_glossa = dalla_ety = non_parole = 0
    out = open(sys.argv[1], 'w', encoding='utf-8')
    glosse = open(sys.argv[2], 'w', encoding='utf-8')
    forme = open(os.environ['FORME'], 'w', encoding='utf-8') if os.environ.get('FORME') else None
    # SENZA: per ogni lemma senza etimologia utile, la causa (diagnosi: perché zoo non ha una catena)
    senza_f = open(os.environ['SENZA'], 'w', encoding='utf-8') if os.environ.get('SENZA') else None
    cause, modelli_ignoti = Counter(), Counter()
    # DIAGNOSI_MODELLI=ety,etymon: alcuni esempi grezzi di quei modelli nel registro, per imparare a leggerli
    diagnosi = set(filter(None, os.environ.get('DIAGNOSI_MODELLI', '').split(',')))
    esempi_diagnosi = Counter()
    # DIAGNOSI_PAROLE=audientia,acquiesco: i modelli grezzi di quelle parole, per capire perché non si leggono
    parole_diagnosi = set(filter(None, os.environ.get('DIAGNOSI_PAROLE', '').split(',')))
    for riga in sys.stdin:
        n += 1
        try: v = json.loads(riga)
        except Exception: continue
        if v.get('lang_code') != LINGUA: continue
        tpl = v.get('etymology_templates') or []
        sensi = v.get('senses') or []
        if v.get('word') in parole_diagnosi:
            print('  parola ' + json.dumps({'parola': v.get('word'), 'pos': v.get('pos'), 'modelli': tpl,
                                             'testo': (v.get('etymology_text') or '')[:300],
                                             'sensi': [(s.get('glosses') or [''])[0][:60] for s in sensi][:3]}, ensure_ascii=False)[:1500],
                  file=sys.stderr)
        for t in tpl:
            if t.get('name') in diagnosi and esempi_diagnosi[t['name']] < 10:
                esempi_diagnosi[t['name']] += 1
                print('  esempio ' + json.dumps({'parola': v.get('word'), 'modello': t, 'testo': (v.get('etymology_text') or '')[:300],
                                                  'altri': [x.get('name') for x in tpl]}, ensure_ascii=False), file=sys.stderr)
        if non_parola(v):
            non_parole += 1
            continue
        if forma_flessa(v):
            flesse += 1
            flesse_dalla_glossa += not marcata(v)
            # una forma flessa non è una voce, nemmeno con un'etimologia sua: va solo in forme.tsv, che lega al lemma la
            # forma citata in una catena (noctem → nox; battipanni < battere, forma citata «batti»)
            lf = lemma_della_forma(v)
            if forme and lf:
                forme.write(f"{v['word']}\t{lf[0]}\t{','.join(lf[1])}\n")
            continue
        g = [s['glosses'][0] for s in sensi if s.get('glosses')][:2]
        # tutti i lemmi, con le forme che distinguono gli omografi: canonica, infinito, genitivo (fundō: fundere o fundāre)
        testa = ((v.get('head_templates') or [{}])[0].get('expansion') or '')
        distintive = [next((f['form'] for f in (v.get('forms') or []) if 'canonical' in (f.get('tags') or [])), None) or testa.split(' (')[0].split(' ')[0]]
        for f in (v.get('forms') or []):
            et = set(f.get('tags') or [])
            if ({'infinitive', 'present', 'active'} <= et or {'genitive', 'singular'} <= et) and len(distintive) < 4:
                distintive.append(f.get('form', ''))
        # sesta colonna: 1 per le forme ricostruite (pagine Reconstruction:), che non sono parole attestate
        glosse.write('\t'.join((v['word'], str(v.get('etymology_number') or 1), v.get('pos') or '',
                                 (g[0] if g else '').replace('\t', ' ').replace('\n', ' ')[:200],
                                 ','.join(x.replace(',', ' ') for x in distintive if x),
                                 '1' if (v.get('original_title') or '').startswith('Reconstruction:') else '',
                                 # settima colonna: la pronuncia, in JSON (IPA con la varietà, sillabazione, audio)
                                 json.dumps(pronuncia(v), ensure_ascii=False) if pronuncia(v) else '')) + '\n')
        tpl = [{**t, 'name': ALIAS.get(t.get('name'), t.get('name'))} for t in tpl]
        classici = [t for t in tpl if t.get('name') in UTILI]
        if not any(porta_etimo(t) for t in classici):
            # solo per le voci che non hanno già un etimo nei modelli classici: quelle che leggiamo bene non cambiano
            conv = next((c for c in (da_ety(t, LINGUA) for t in tpl if t.get('name') in ('ety', 'etymon')) if c), None)
            if conv:
                classici = [conv] + classici
                dalla_ety += 1
        tpl = [{'n': t['name'], 'a': t.get('args', {}), 'e': t.get('expansion', '')} for t in classici]
        if not tpl:
            tpl = menzione_come_der(v)
            promosse += bool(tpl)
        if not tpl:
            senza += 1
            nomi = sorted({t.get('name') or '' for t in (v.get('etymology_templates') or [])} - {''})
            causa = 'modelli non letti' if nomi else 'solo testo' if (v.get('etymology_text') or '').strip() else 'nessuna etimologia'
            cause[causa] += 1
            modelli_ignoti.update(nomi)
            if senza_f:
                senza_f.write(f"{v['word']}\t{v.get('pos') or ''}\t{causa}\t{','.join(nomi)}\t"
                              f"{(v.get('etymology_text') or '').replace(chr(9), ' ').replace(chr(10), ' ')[:200]}\n")
            continue
        heads = [{'n': h.get('name'), 'a': h.get('args', {})} for h in (v.get('head_templates') or [])[:1]]
        testa = ((v.get('head_templates') or [{}])[0].get('expansion') or '')
        canonica = next((f['form'] for f in (v.get('forms') or []) if 'canonical' in (f.get('tags') or [])), None) or testa.split(' (')[0].split(' ')[0] or None
        out.write(json.dumps({'w': v['word'], 'p': v.get('pos'), 'en': v.get('etymology_number'), 't': v.get('etymology_text', ''),
                              'tpl': tpl, 'g': g, 'h': heads, 'c': canonica,
                              # la traslitterazione della voce (дом → dom), per la ricerca in caratteri latini
                              'r': next((f['form'] for f in (v.get('forms') or []) if 'romanization' in (f.get('tags') or [])), None),
                              'pr': pronuncia(v),
                              'rec': (v.get('original_title') or '').startswith('Reconstruction:')}, ensure_ascii=False) + '\n')
        tenuti += 1
    print(f'righe {n}, lemmi con etimologia {tenuti} (dal solo testo {promosse}, da {{{{ety}}}} {dalla_ety}), forme flesse {flesse} '
          f'(riconosciute dalla sola glossa: {flesse_dalla_glossa}), '
          f'lemmi senza etimologia utile {senza}, sigle e simboli esclusi {non_parole}', file=sys.stderr)
    if senza:
        print(f'  senza etimologia utile, per causa: {dict(cause)}; modelli non letti più frequenti: '
              f'{modelli_ignoti.most_common(25)}', file=sys.stderr)
