# Filtra il dump di Kaikki: lemmi con etimologia (JSONL) e glosse di tutti i lemmi (TSV).
import json, os, re, sys
from collections import Counter
LINGUA = os.environ.get('LINGUA', 'it')
UTILI = {'inh', 'inh+', 'bor', 'bor+', 'lbor', 'slbor', 'ubor', 'obor', 'der', 'der+', 'uder', 'cal', 'calque', 'sl', 'psm',
         'bf', 'back-form', 'clipping', 'ellipsis', 'af', 'affix', 'suffix', 'prefix', 'confix', 'compound', 'blend',
         'named-after', 'onom', 'onomatopoeic', 'unk', 'unc', 'root', 'doublet', 'dbt', 'it-deverbal', 'etydate', 'deverbal', 'radice'}
MENZIONI = {'m', 'l', 'm+', 'mention', 'link', 'l-self'}
# abbreviazioni dei modelli classici, con gli stessi argomenti
ALIAS = {'suf': 'suffix', 'pre': 'prefix', 'com': 'compound', 'com+': 'compound', 'con': 'confix', 'univ': 'af',
         'univerbation': 'af', 'back-formation': 'bf', 'learned borrowing': 'lbor', 'semi-learned borrowing': 'slbor',
         'borrowed': 'bor', 'inherited': 'inh', 'derived': 'der',
         # deverbale dalla prima persona del presente (it-deverbal fpp): stessi argomenti di it-deverbal; uno
         # pseudoprestito (footing dall'inglese) ha gli argomenti di der: lingua, lingua d'origine, termine
         'it-deverbal fpp': 'it-deverbal', 'pseudo-loan': 'der'}
# i modelli che portano un etimo (gli altri utili sono radici, date, doppioni, origini ignote…)
CON_ETIMO = {'inh', 'inh+', 'bor', 'bor+', 'lbor', 'slbor', 'ubor', 'obor', 'der', 'der+', 'uder', 'cal', 'calque', 'sl',
             'psm', 'bf', 'back-form', 'clipping', 'ellipsis', 'af', 'affix', 'suffix', 'prefix', 'confix', 'compound',
             'blend', 'it-deverbal', 'deverbal', 'radice'}
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
    parti = [scomponi(v)[0] for k, v in sorted(a.items()) if k.isdigit() and int(k) >= 2 and v and v.strip()]
    parti = [p for p in parti if p]
    if n == 'suffix':
        # la base è il secondo argomento: {{suffix|grc||τής}} (κριτής) ha solo il suffisso
        base = scomponi(a.get('2') or '')[0]
        return bool(base) and not base.startswith('-')
    if n in ('af', 'affix', 'prefix', 'confix', 'compound', 'blend'):
        return len(parti) >= 2 or any(p and not p.startswith('-') and not p.endswith('-') for p in parti)
    if n in ('bf', 'back-form', 'clipping', 'ellipsis', 'it-deverbal', 'deverbal'):
        return bool(parti)
    # {{inh|grc|grk-pro||*pʰōnā́}}: una forma ricostruita senza pagina sta nel quarto argomento, e il parser la legge
    return bool(scomponi(a.get('3') or '')[0].strip('*- ')) or scomponi(a.get('4') or '')[0].startswith('*')


# I modificatori di una chiave nell'albero di {{ety}} («der<unc><ine-pro:…>»): gli altri gruppi sono termini
MOD_CHIAVE = {'unc', 'unk', 'text', 'q', 'qq', 'ref', 'conj', 'nocap', 'notext'}


def gruppi_angolari(s):
    '''I gruppi tra parentesi angolari del primo livello di una stringa, anche se ne contengono altri, e il testo
    fuori: «grk-pro:<alt:*pʰōnā́><ety:der<ine-pro:*bʰeh₂-<id:speak>>>» → ('grk-pro:', ['alt:*pʰōnā́', 'ety:der<…>']).'''
    fuori, gruppi, prof, inizio = [], [], 0, 0
    for i, c in enumerate(s or ''):
        if c == '<':
            if prof == 0:
                inizio = i
            prof += 1
        elif c == '>' and prof:
            prof -= 1
            if prof == 0:
                gruppi.append(s[inizio + 1:i])
        elif prof == 0:
            fuori.append(c)
    return ''.join(fuori).strip(), gruppi


def scomponi(x):
    '''Un termine con i suoi modificatori: ('grk-pro:', {'alt': '*pʰōnā́', 'ety': 'der<ine-pro:*bʰeh₂-<id:speak>>'}).'''
    testo, gruppi = gruppi_angolari(x)
    mod = {}
    for g in gruppi:
        k, _, v = g.partition(':')
        mod.setdefault(k.strip(), v.strip())
    return testo, mod


def albero_ety(s):
    '''L'etimologia annidata di un termine: «der<ine-pro:*bʰeh₂-<id:speak>>» → ('der', ['ine-pro:*bʰeh₂-<id:speak>']);
    «af<*bʰil-><*-os<id:athematic>>» → ('af', ['*bʰil-', '*-os<id:athematic>']). I gruppi che sono modificatori della
    chiave («der<unc>») non sono termini.'''
    chiave = re.split(r'[<\s]', (s or '').lstrip(':'), maxsplit=1)[0]
    _, gruppi = gruppi_angolari(s)
    return chiave, [g for g in gruppi if g.partition(':')[0].strip() not in MOD_CHIAVE]


def prima_forma(t):
    '''La prima di più forme scritte insieme: «*iowos, *iowez-» → «*iowos», «*h₂ér-ti-s ~ *h₂r̥-téy-s» → «*h₂ér-ti-s».'''
    return re.split(r'\s*[~,;/`]\s*|\s+(?:or|and)\s+', (t or '').strip(), maxsplit=1)[0].strip()


def termine_ety(x, lingua):
    '''(lingua, termine, modificatori) di un termine di {{ety}}. Se il termine manca vale la forma ricostruita in
    <alt:> (una forma senza pagina: «grk-pro:<alt:*pʰōnā́>») o, per un tema («<alt:κρῐ-><ety:from<κρῑ́νω>>»), la
    parola da cui il tema viene.'''
    testo, mod = scomponi(x)
    m = re.match(r'^([a-z]{2,3}(?:-[a-z]{2,4})*):(.*)$', testo)
    lt, termine = (m.group(1), m.group(2).strip()) if m else (lingua, testo)
    if not termine.strip('*- '):
        alt = prima_forma(mod.get('alt', ''))
        if alt.startswith('*') and alt.strip('*- ') and '<' not in alt:
            return lt, alt, {k: v for k, v in mod.items() if k != 'alt'}
        chiave, figli = albero_ety(mod.get('ety', ''))
        if chiave in ('from', 'der', 'inh') and len(figli) == 1:
            return termine_ety(figli[0], lt)
    return lt, termine, mod


def radici_ety(t, lingua):
    '''Le radici ricostruite che un {{ety}}/{{etymon}} dichiara nel suo albero: φωνή < *pʰōnā́ < *bʰeh₂- «parlare»
    ({{etymon|grc|:inh|grk-pro:<alt:*pʰōnā́><ety:der<ine-pro:*bʰeh₂-<id:speak>>>}}). Valgono come {{root}}: (lingua,
    radice, identificativo). Conta la radice più profonda di ogni ramo (una variante come *dʰyeh₂- che viene da
    *dʰeyh₂- non è la radice); un ramo o una radice segnati come incerti (<unc>) non dichiarano niente, e nemmeno
    :influence, :cog e le chiavi che non danno un etimo.'''
    trovate = []

    def visita(x, lingua_x, prof=0):
        """True se sotto questo termine, o in questo termine, c'è una radice dichiarata."""
        if prof > 12:
            return False
        lt, termine, mod = termine_ety(x, lingua_x)
        sotto = False
        if mod.get('ety'):
            chiave, figli = albero_ety(mod['ety'])
            if chiave in ETY_CHIAVI and '<unc' not in mod['ety'].split('<', 1)[0] + '<' + '<'.join(
                    g for g in gruppi_angolari(mod['ety'])[1] if g.partition(':')[0].strip() in MOD_CHIAVE):
                for f in figli:
                    sotto = visita(f, lt, prof + 1) or sotto
        ident = mod.get('id') if mod.get('id') and '<' not in mod['id'] else None
        radice = termine.startswith('*') and termine.endswith('-') and '-' not in termine.strip('*-') \
            and bool(termine.strip('*-')) and not termine.startswith('*-') and lt.endswith('-pro')
        if radice and not sotto and 'unc' not in mod and 'unk' not in mod:
            if (lt, termine, ident) not in trovate:
                trovate.append((lt, termine, ident))
            return True
        return sotto or radice

    a = t.get('args') or {}
    chiave, incerta = 'from', False
    for _, x in sorted((int(k), v) for k, v in a.items() if k.isdigit() and int(k) >= 2 and v and v.strip()):
        x = x.strip()
        if x.startswith(':'):
            chiave = re.split(r'[<\s]', x[1:], maxsplit=1)[0]
            incerta = '<unc' in x or '<unk' in x
        elif chiave in ETY_CHIAVI and not incerta:
            visita(x, (a.get('1') or lingua).strip())
    return trovate


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
            parti = []
            for x in termini:
                if scomponi(x)[0].strip('*- ') and not re.search(r'<[^<>]*<', x):
                    parti.append(x)         # il caso semplice resta com'è: «fābula<id:discourse>»
                    continue
                # «<alt:κρῐ-><ety:from<κρῑ́νω>>» (κριτής): il tema non è una voce, vale la parola da cui viene
                lt, termine, mod = termine_ety(x, lv)
                if termine.strip('*- ') or termine.startswith('-') or termine.endswith('-'):
                    parti.append((termine if lt == lv else f'{lt}:{termine}')
                                 + (f"<id:{mod['id']}>" if mod.get('id') and '<' not in mod['id'] else ''))
            if not any(scomponi(x)[0].strip('*- ') for x in parti):
                continue
            parti = [preverbo(x, lv) if i < len(parti) - 1 else x for i, x in enumerate(parti)]
            return {'name': nome, 'args': {'1': lv, **{str(i): x for i, x in enumerate(parti, 2)}}, 'expansion': ''}
        lt, termine, mod = termine_ety(termini[0], lv)
        if not termine.strip('*- ') or '<' in termine or '>' in termine or re.search(r'\s(?:and|or|of|to|the)\s|^(?:and|or|of)\s', termine):
            continue                        # «itc-pro:» senza parola, o una frase al posto del termine: nessun etimo
        if nome in ('bf', 'clipping', 'ellipsis'):
            return {'name': nome, 'args': {'1': lv, '2': termine if lt == lv else f'{lt}:{termine}'}, 'expansion': ''}
        args = {'1': lv, '2': lt, '3': termine}
        for k, dove in (('alt', '4'), ('t', 't'), ('id', 'id')):
            if mod.get(k) and '<' not in mod[k]:
                args[dove] = mod[k]
        return {'name': nome, 'args': args, 'expansion': ''}
    return None
def porta_identificativi(classici, tpl, lingua):
    """ὄψις: «{{etymon|grc|:af|grc:ὄψ<id:eye>|grc:-σῐς}}» accanto a «{{af|grc|ὄψ|-σῐς|t1=eye}}». Il modello classico dà
    l'etimo, ma solo {{etymon}} dice quale degli omografi (ὄψ «voce» o ὄψ² «occhio», che si dà id=eye): l'identificativo
    passa al termine uguale del modello classico, che non ne ha uno (idN per gli affissi, id per gli altri)."""
    ident = {}
    for t in tpl:
        if t.get('name') not in ('ety', 'etymon'):
            continue
        for k, x in (t.get('args') or {}).items():
            if not k.isdigit() or int(k) < 2 or not x or x.strip().startswith(':'):
                continue
            lt, termine, mod = termine_ety(x.strip(), (t['args'].get('1') or lingua).strip())
            if mod.get('id') and '<' not in mod['id'] and termine.strip('*- '):
                ident.setdefault((lt, termine.strip()), mod['id'].strip())
    if not ident:
        return 0
    portati = 0
    for t in classici:
        n, a = t.get('name'), t.get('args')
        if not a or n not in CON_ETIMO:
            continue
        lv = (a.get('1') or lingua).strip()
        if n in ('af', 'affix', 'prefix', 'suffix', 'confix', 'compound', 'blend'):
            for j in range(1, 12):
                x = (a.get(str(j + 1)) or '').strip()
                if not x or a.get(f'id{j}') or '<id:' in x:
                    continue
                testo = scomponi(x)[0]
                m = re.match(r'^([a-z]{2,3}(?:-[a-z]{2,4})*):(.*)$', testo)
                lt, termine = (m.group(1), m.group(2).strip()) if m else (lv, testo.strip())
                if ident.get((lt, termine)):
                    a[f'id{j}'] = ident[(lt, termine)]
                    portati += 1
        elif not a.get('id'):
            lt, termine = (a.get('2') or '').strip(), scomponi(a.get('3') or '')[0].strip()
            if ident.get((lt, termine)):
                a['id'] = ident[(lt, termine)]
                portati += 1
    return portati


# Le radici semitiche: la parola araba, ebraica o maltese dichiara la sua radice triconsonantica ({{etymon|ar|:root|ك ت ب}},
# {{ar-root|ك ت ب}}, il riquadro {{ar-rootbox}}, {{he-root}}, {{mt-root}}). Quando la pagina non dà un altro etimo, la parola
# viene dalla sua radice, che è la cima della famiglia (كِتَاب, مَكْتَب, كَتَبَ sotto ك ت ب): senza, il 16 novembre 2026,
# 191 mila voci arabe restavano senza etimologia.
MODELLI_RADICE = {'ar-root': 'ar', 'ar-rootbox': 'ar', 'he-root': 'he', 'he-rootbox': 'he', 'mt-root': 'mt', 'mt-rootbox': 'mt'}


def radice_semitica(tpl, lingua):
    """La radice che la voce dichiara, come modello «radice» (una derivazione): None se non ne dichiara una."""
    for t in tpl:
        n, a = t.get('name'), t.get('args') or {}
        if n in ('ety', 'etymon'):
            vals = [v.strip() for k, v in sorted(((int(k), v) for k, v in a.items() if k.isdigit() and int(k) >= 2 and v and v.strip()))]
            for i, x in enumerate(vals):
                if x.split('<')[0] == ':root' and i + 1 < len(vals) and not vals[i + 1].startswith(':'):
                    r = vals[i + 1].split('<')[0].strip()
                    if r:
                        return {'name': 'radice', 'args': {'1': lingua, '2': (a.get('1') or lingua).strip(), '3': r}, 'expansion': ''}
        elif n in MODELLI_RADICE:
            r = (a.get('1') or '').strip()
            if r and MODELLI_RADICE[n] == lingua:
                return {'name': 'radice', 'args': {'1': lingua, '2': lingua, '3': r}, 'expansion': ''}
    return None


DA_TESTO = re.compile(r'^\s*(from|derived from|deverbal from|back-formation from)\b', re.I)
# Le etimologie scritte solo a parole, senza modelli («Deverbal of domandare», «Past participle of trovare»,
# «From Latin dominus», «From divertire +‎ -ente»): i nomi delle lingue che si leggono nel testo
LINGUE_TESTO = {'Latin': 'la', 'Late Latin': 'la', 'Medieval Latin': 'la', 'New Latin': 'la', 'Vulgar Latin': 'la-vul',
                'Ancient Greek': 'grc', 'Byzantine Greek': 'gkm', 'French': 'fr', 'Old French': 'fro', 'Middle French': 'frm',
                'English': 'en', 'Middle English': 'enm', 'Old English': 'ang', 'Spanish': 'es', 'Portuguese': 'pt',
                'Catalan': 'ca', 'Occitan': 'oc', 'Old Occitan': 'pro', 'German': 'de', 'Arabic': 'ar', 'Persian': 'fa',
                'Turkish': 'tr', 'Hebrew': 'he', 'Russian': 'ru', 'Neapolitan': 'nap', 'Sicilian': 'scn', 'Venetan': 'vec',
                'Lombard': 'lmo', 'Old Italian': 'roa-oit', 'Italian': 'it', 'Japanese': 'ja', 'Dutch': 'nl'}
_PAROLA = r"(?P<termine>[^\W\d_][\w'’-]*)"
TESTO_DA = re.compile(r'^(?:(?:Borrowed|Learned borrowing|Inherited|Derived) )?[Ff]rom (?:(?P<lingua>'
                      + '|'.join(sorted(map(re.escape, LINGUE_TESTO), key=len, reverse=True))
                      + r') )?(?:the (?:verb|noun|adjective|adverb) )?' + _PAROLA + r'(?P<resto>.*)$')
TESTO_DI = re.compile(r'^(?:Deverbal|Back-formation|Diminutive|Augmentative|Pejorative|Endearing form|Univerbation|'
                      r'(?:Past|Present) participle) (?:of|from) (?:the (?:verb|noun|adjective) )?' + _PAROLA + r'\s*$')
PIU = re.compile(r'^\s*\+\u200e?\s*(-?[^\W\d_][\w\'’-]*-?)')
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
                   r'|(?:to-|bare\s+)infinitive\b|construct\s+(?:state|form)\s+of\b'   # ebraico: «to-infinitive of הִכְעִיס»
                   r'|(?:comparative|superlative)(?:\s+degree)?\s+of\b'
                   r'|(?:simple\s+)?past\s+tense\b|simple\s+past\b'                # inglese: «simple past tense and past participle of»
                   r'|compound\s+of\b)', re.I)       # italiano, forme con pronomi attaccati: «compound of the infinitive dire with ve and la»

TESTA_FORMA = re.compile(r'\b(?:first|second|third)-person\b|\binflection of\b', re.I)

# Le voci che non sono parole: sigle e abbreviazioni (NASA, BBC, SPQR), simboli, caratteri, segni d'interpunzione.
# Le sigle diventate parole minuscole (laser, radar) restano.
NON_PAROLE = {'abbrev', 'symbol', 'character', 'punct'}


# I discendenti che la pagina dichiara (sezione «Descendants»): l'albero ramo per ramo, dalla radice o dalla parola
# antica alle lingue di oggi. Kaikki li dà in due forme: una riga per discendente con la profondità e i modelli
# ({{desc|la|aqua|bor=1}}), oppure nodi annidati con lingua, parola ed etichette.
MODELLI_DISCENDENTI = {'desc', 'descendant', 'desctree', 'descendants tree'}
SEGNI_DISCENDENTI = (('bor', 'borrowed'), ('lbor', 'learned'), ('slb', 'semi-learned'), ('der', 'derived'),
                     ('clq', 'calque'), ('unc', 'uncertain'), ('inh', 'inherited'))


def discendenti(v):
    """(profondità, lingua, parola, segni) per ogni discendente dichiarato; la profondità parte da 1."""
    def nodi(lista, prof):
        for d in lista or []:
            if not isinstance(d, dict):
                continue
            if d.get('lang_code') or d.get('word'):
                et = ' '.join(d.get('tags') or []) + ' ' + ' '.join(d.get('raw_tags') or [])
                segni = [s for s, parola in SEGNI_DISCENDENTI if parola in et]
                # un nodo senza parola (solo il nome di una lingua o di un ramo) si scrive lo stesso, vuoto: tiene il
                # posto nell'albero, altrimenti i suoi figli passerebbero al nodo che lo precede (ποτέ sotto *hwaz)
                yield prof, d.get('lang_code') or '', d.get('word') or '', segni
                yield from nodi(d.get('descendants'), prof + 1)
                continue
            p = d.get('depth') or prof
            if not any(t.get('name') in MODELLI_DISCENDENTI for t in d.get('templates') or []):
                yield p, '', '', []
            for t in d.get('templates') or []:
                if t.get('name') not in MODELLI_DISCENDENTI:
                    continue
                a = t.get('args') or {}
                segni = [s for s, _ in SEGNI_DISCENDENTI if a.get(s) and a.get(s) not in ('0', 'no')]
                i = 2
                while str(i) in a:
                    if a[str(i)].strip() not in ('', '-'):
                        yield p, a.get('1', ''), a[str(i)].strip(), segni
                    i += 1
                if i == 2 or all(a[str(j)].strip() in ('', '-') for j in range(2, i)):
                    yield p, a.get('1', ''), '', segni
    return nodi(v.get('descendants'), 1)


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
                # la varietà: tags se wiktextract la riconosce, raw_tags se no («Ecclesiastical»)
                ipa.append([s['ipa'], ','.join((s.get('tags') or []) + (s.get('raw_tags') or []))])
        elif not audio and (s.get('audio') or s.get('ogg_url') or s.get('mp3_url')):
            audio = s.get('audio') or (s.get('ogg_url') or s.get('mp3_url')).rsplit('/', 1)[-1]
    sill = next(('‧'.join(h['parts']) for h in (v.get('hyphenations') or []) if isinstance(h, dict) and h.get('parts')), None) \
        or next((h for h in (v.get('hyphenation') or []) if isinstance(h, str) and h), None)
    d = {k: x for k, x in (('i', ipa), ('s', sill), ('a', audio)) if x}
    return d or None


# le etichette d'uso dei sensi che la scheda mostra (le altre etichette di Wiktionary sono grammaticali o tecniche)
USO = {'archaic', 'obsolete', 'dated', 'rare', 'figuratively', 'metaphorically', 'colloquial', 'informal', 'slang',
       'vulgar', 'derogatory', 'pejorative', 'offensive', 'poetic', 'literary', 'formal', 'humorous', 'euphemistic',
       'dialectal', 'regional', 'historical', 'transitive', 'intransitive', 'reflexive', 'pronominal', 'uncountable',
       'countable', 'idiomatic', 'ironic', 'childish', 'nonstandard', 'proscribed', 'Late-Latin', 'Medieval-Latin',
       'Ecclesiastical-Latin', 'New-Latin', 'Classical-Latin', 'Epic', 'Attic', 'Ionic', 'Doric', 'Koine', 'Byzantine'}


def dati_scheda(v):
    '''I dati della scheda da Wiktionary (CC BY-SA): la riga delle forme del modello di intestazione («carō f (genitive
    carnis); third declension») e fino a otto accezioni, ciascuna con le etichette d'uso e l'ambito. None se non c'è nulla.'''
    out = []
    for s in v.get('senses') or []:
        g = s.get('glosses') or []
        if not g or s.get('form_of') or 'form-of' in (s.get('tags') or []):
            continue
        etichette = [t for t in (s.get('tags') or []) if t in USO] + list(s.get('topics') or [])[:2]
        out.append([g[-1].replace('\t', ' ').replace('\n', ' ')[:200], ','.join(etichette)])   # un sottosenso: il più preciso
        if len(out) == 8:
            break
    testa = ((v.get('head_templates') or [{}])[0].get('expansion') or '').replace('\t', ' ').replace('\n', ' ').strip()[:160]
    d = {k: x for k, x in (('t', testa if testa and testa != v.get('word') else None), ('s', out)) if x}
    return d or None


def ricostruzioni_alternative(v):
    '''Le coppie (variante, principale, fonte) di una pagina ricostruita: un senso «alternative reconstruction of *X»
    (alt_of: questa forma è la variante di X) e le «Alternative reconstructions» della pagina (forms con il tag
    alternative: sono varianti di questa forma). Senza l'asterisco, come il titolo della voce in Kaikki.'''
    parola = (v.get('word') or '').lstrip('*')
    if not parola:
        return []
    coppie = []
    for s in v.get('senses') or []:
        for a in s.get('alt_of') or []:
            w = (a.get('word') or '').lstrip('*').strip()
            if w and w != parola and PAROLA_RICOSTRUITA.match(w):
                coppie.append((parola, w, 'alt_of'))
    for f in v.get('forms') or []:
        w = (f.get('form') or '').lstrip('*').strip()
        if 'alternative' in (f.get('tags') or []) and w and w != parola and PAROLA_RICOSTRUITA.match(w):
            coppie.append((w, parola, 'alternative'))
    return list(dict.fromkeys(coppie))


PAROLA_RICOSTRUITA = re.compile(r'^[^\s,;()]+$')      # una forma sola, non «*gʰebʰ- (Kortlandt)» né un elenco


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
    # le pagine arabe delle forme verbali non hanno glossa: il senso è vuoto (no-gloss) e la testa dice la forma
    # («أُنَّا (form I) … # first-person …»); erano 200 mila «verbi» arabi
    if not con_glossa and sensi and all('no-gloss' in (s.get('tags') or []) for s in sensi):
        testa = ' '.join((h.get('expansion') or '') for h in v.get('head_templates') or [])
        if TESTA_FORMA.search(testa):
            return True
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
        # forme con pronomi attaccati: il lemma è l'infinito, o quello della forma spiegata tra virgole
        # («compound of the infinitive dire with ve and la» → dire; «compound of dando, the gerund of dare, with la» → dare)
        c = re.match(r'compound\s+of\s+(?:the\s+infinitive\s+([^\s(),;:]+)|[^,]+,\s+the\s+[^,]*?\bof\s+([^\s(),;:]+))', g, re.I)
        if c:
            return c.group(1) or c.group(2), ['compound']
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
    menzioni = [t for t in tpl if t.get('name') in MENZIONI and (t.get('args') or {}).get('2')]
    # «From earlier 'l, a reduced form of lo» (il): la forma più antica non è una voce, l'etimo è la parola di cui è
    # una riduzione
    rid = re.match(r"From earlier\s+[^,]+,\s+an?\s+(?:reduced|shortened|apocopic|apocopated|contracted|syncopated|variant)"
                   r"\s+form\s+of\s+([^\s.,;]+)", testo)
    m = next((t for t in menzioni if rid and rid.group(1) in (t.get('expansion'), t['args']['2'])), None)
    if m is None and rid:
        # Kaikki non sempre conserva i modelli di menzione (il ha solo {{cog|scn|lu}}): la parola si legge dal testo
        return [{'n': 'der', 'a': {'1': v.get('lang_code'), '2': v.get('lang_code'), '3': rid.group(1)}, 'e': rid.group(1)}]
    if m is None:
        m = menzioni[0] if menzioni else None
        if m is None or (m.get('expansion') or m['args']['2']) not in frase:
            return []
    a = m['args']
    return [{'n': 'der', 'a': {'1': v.get('lang_code'), '2': a['1'], '3': a['2'].split('#')[0], **({'t': a['4']} if a.get('4') else {})},
             'e': m.get('expansion', '')}]


# Le lingue in cui una variante senza etimologia si lega al suo lemma: quelle che entrano intere (INTERE), dove la
# voce c'è già. Altrove ogni grafia alternativa diventerebbe una voce nuova «con etimologia» (in inglese decine di migliaia)
VARIANTI_LEGATE = set(filter(None, os.environ.get('VARIANTI_LEGATE', 'la,grc').split(',')))
# «Epic form of πρός (prós)», «Lyric, Aeolic, and Laconian form of ὄνομᾰ», «Alternative spelling of X»
VARIANTE_DI = re.compile(r'^(?:[A-Z][\w-]*,? (?:(?:and|or) )?)+(?:form|spelling|variant) of ([^\s(,;:]+)')


def variante_di(v):
    '''Una voce senza etimologia che è la variante di un'altra parola della sua lingua (ὄνυμα, «Lyric, Aeolic, and
    Laconian form of ὄνομᾰ»; προτί, «Epic form of πρός»): un passaggio di tipo variante verso quella parola, così la
    variante e ciò che ne discende stanno nella famiglia della parola. Solo se tutti i sensi rimandano alla stessa
    parola, con alt_of di Kaikki o con la glossa; non per le forme flesse né per le pagine ricostruite (lì le
    ricostruzioni alternative hanno la loro strada, VARIANTI).'''
    sensi = v.get('senses') or []
    if v.get('lang_code') not in VARIANTI_LEGATE or not sensi or marcata(v) \
            or (v.get('original_title') or '').startswith('Reconstruction:'):
        return []
    bersagli = set()
    for s in sensi:
        w = next((a.get('word') for a in s.get('alt_of') or [] if a.get('word')), None)
        if not w:
            m = VARIANTE_DI.match((s.get('glosses') or [''])[0])
            w = m.group(1) if m else None
        if not w:
            return []
        bersagli.add(w.strip())
    w = bersagli.pop() if len(bersagli) == 1 else ''
    if not w or w == v.get('word') or not PAROLA_RICOSTRUITA.match(w):
        return []
    return [{'n': 'variante', 'a': {'1': v.get('lang_code'), '2': w}, 'e': ''}]


def base_dalla_menzione(v, lingua):
    '''«{{m|en|lie}} {{suffix|en||ing}}» (lying), «From {{m|it|vedova}} (or {{m|it|vedovo}}) {{suf|it||aggio}}»
    (vedovaggio): il suffisso è scritto senza la base, e la base è la parola menzionata prima. Senza questo il suffisso
    restava solo (e prima ancora diventava una parola: lying < «ing»). Vale la prima menzione che non è un affisso tra i
    modelli che precedono il suffisso; se non c'è, niente.'''
    tpl = v.get('etymology_templates') or []
    for i, t in enumerate(tpl):
        a = t.get('args') or {}
        if ALIAS.get(t.get('name'), t.get('name')) != 'suffix' or scomponi(a.get('2') or '')[0] or not scomponi(a.get('3') or '')[0]:
            continue
        for m in tpl[:i]:
            ma = m.get('args') or {}
            base = scomponi(ma.get('2') or '')[0]
            if m.get('name') in MENZIONI and base and not base.startswith('-') and not base.endswith('-') and PAROLA_RICOSTRUITA.match(base):
                lm = (ma.get('1') or lingua).strip()
                return {'name': 'af', 'args': {'1': lingua, '2': base if lm == lingua else f'{lm}:{base}',
                                               '3': '-' + scomponi(a['3'])[0].lstrip('-')}, 'expansion': ''}
        return None
    return None


def testo_come_der(v):
    """Un'etimologia scritta solo a parole, senza nessun modello: la prima frase, se è semplice. «From Latin dominus»
    (der dal latino), «From domandare» o «Deverbal of domandare» (der dalla stessa lingua), «Past participle of trovare»,
    «From divertire +‎ -ente» (af). Niente se la frase confronta, dubita o parla di influssi: «From X, influenced by Y»
    tiene X, ma «Possibly from X» o «Compare X» no."""
    # i modelli che non danno un etimo (affini, qualificatori, citazioni) non fermano la lettura del testo: il ha solo
    # {{cog|scn|lu}}; quelli che lo danno sì
    if any(t.get('name') in UTILI or t.get('name') in MENZIONI or t.get('name') in ('ety', 'etymon')
           for t in v.get('etymology_templates') or []):
        return []
    testo = (v.get('etymology_text') or '').strip()
    frase = re.split(r'[.;:(]|, (?:from|and|or|but|influenced|perhaps|possibly|probably)\b', testo, maxsplit=1)[0].strip(' ,')
    if not frase or re.search(r'\b(?:compare|cognate|uncertain|unknown|possibly|probably|perhaps|influenc|cf)\b', frase, re.I):
        return []
    lingua_voce = v.get('lang_code') or LINGUA
    m = TESTO_DI.match(frase)
    if m:
        return [{'n': 'der', 'a': {'1': lingua_voce, '2': lingua_voce, '3': m.group('termine')}, 'e': ''}]
    m = TESTO_DA.match(frase)
    if not m:
        return []
    resto, parti = m.group('resto'), [m.group('termine')]
    while True:
        p = PIU.match(resto)
        if not p:
            break
        parti.append(p.group(1))
        resto = resto[p.end():]
    if resto.strip(' ,'):
        return []                         # altro testo dopo l'etimo: la frase non è semplice
    lingua = LINGUE_TESTO.get(m.group('lingua') or '', lingua_voce)
    if len(parti) > 1:
        if lingua != lingua_voce:
            return []
        return [{'n': 'af', 'a': {'1': lingua_voce, **{str(i): x for i, x in enumerate(parti, 2)}}, 'e': ''}]
    return [{'n': 'der', 'a': {'1': lingua_voce, '2': lingua, '3': parti[0]}, 'e': ''}]


PAROLA_SOLA = re.compile(r"[^\W\d_][\w'’-]*")


def modello_di_ripiego(v):
    """I modelli italiani che dicono l'etimo con una forma loro, quando la voce non ne ha un altro: il composto di verbo e
    oggetto ({{it-verb-obj|girare|Sole}}: girasole = girare + sole), «From l'aquila» ({{from|it|l'aquila}}), la
    contrazione di parole singole ({{contraction|it|ci|è}}: c'è), non di una frase (vaffanculo)."""
    netto = lambda x: re.sub(r'<[^<>]*>', '', x or '').strip()
    for t in v.get('etymology_templates') or []:
        n, a = t.get('name'), t.get('args') or {}
        if n == 'it-verb-obj' and a.get('1') and a.get('2'):
            return [{'n': 'af', 'a': {'1': 'it', '2': netto(a['1']), '3': netto(a['2'])}, 'e': t.get('expansion', '')}]
        if n == 'from' and PAROLA_SOLA.fullmatch(netto(a.get('2'))):
            lv = a.get('1') or LINGUA
            return [{'n': 'der', 'a': {'1': lv, '2': lv, '3': netto(a['2'])}, 'e': t.get('expansion', '')}]
        if n == 'contraction':
            lv = a.get('1') or LINGUA
            parti = [netto(x) for k, x in sorted(a.items()) if k.isdigit() and int(k) >= 2 and x]
            if parti and all(PAROLA_SOLA.fullmatch(p) for p in parti):
                if len(parti) == 1:
                    return [{'n': 'der', 'a': {'1': lv, '2': lv, '3': parti[0]}, 'e': t.get('expansion', '')}]
                return [{'n': 'af', 'a': {'1': lv, **{str(i): p for i, p in enumerate(parti, 2)}}, 'e': t.get('expansion', '')}]
    return []


def surf_come_af(v):
    """{{surf}} (l'analisi di superficie: «By surface analysis, divertire +‎ -ente») vale come af solo se la voce non
    ha nessun altro etimo."""
    t = next((t for t in v.get('etymology_templates') or [] if t.get('name') in ('surf', 'surface analysis')), None)
    if not t:
        return []
    a = t.get('args') or {}
    parti = {k: x for k, x in a.items() if k.isdigit() and int(k) >= 2 and x}
    if len(parti) < 2 or v.get('word') in parti.values():          # de = «la» + «de»: un'analisi di sé stessa no
        return []
    return [{'n': 'af', 'a': {'1': a.get('1') or LINGUA, **parti}, 'e': t.get('expansion', '')}]


# ---- le forme per l'analisi di un testo (ANALISI): tutte, non solo le pagine che sono soltanto forme ----
# forme.tsv lega le forme citate nelle catene e resta com'è; forme_analisi.tsv serve solo a forme_frequenti.py
RIDUZIONE = re.compile(r'\b(?:apocopic|apocopated|elided|elision|contraction|contracted|apheretic|aphetic|syncopated|truncated)'
                       r'\b[^;:()]*?\bof\s+([^,;:()]+)', re.I)
FUORI_TAVOLA = {'table-tags', 'inflection-template', 'class', 'romanization', 'canonical', 'auxiliary'}
# le parole inglesi che una glossa mette dopo «of» («contraction of the plural article gli»): non sono lemmi italiani
INGLESI = {'the', 'of', 'form', 'forms', 'plural', 'singular', 'masculine', 'feminine', 'article', 'definite',
           'indefinite', 'and', 'or', 'word', 'words', 'literally', 'preposition', 'pronoun', 'with', 'before'}


def lemmi_puliti(testo):
    """I lemmi di un rimando: «avere,havere<l:obsolete>» → avere, havere; «[[in]] [[il]]» e «da + la» → in, il; da, la.
    L'apostrofo resta: l' è una parola."""
    testo = re.sub(r'<[^>]*>', '', testo or '').replace('[[', ' ').replace(']]', ' ')
    parti = [x.strip('“”".').split('#')[0] for x in re.split(r'[,+/]|\s+', testo)]
    return [x for x in parti if x and x.lower() not in INGLESI]


# i sensi che l'analisi di un testo di oggi non legge (forme_per_analisi)
MARGINALI = {'archaic', 'obsolete', 'poetic', 'literary', 'dated', 'nonstandard', 'rare', 'dialectal', 'misspelling',
             'uncommon', 'historical', 'proscribed'}


def forme_per_analisi(v):
    """Le righe (forma, lemma, fonte) di una voce: i sensi «form of» anche se la pagina ha altri sensi (giorni:
    «plural of giorno» e «days»), le riduzioni (dalla: «contraction of da + la»; l': «elided form of lo»), e la
    tavola delle forme del lemma (avere: ho, hai, ha, hanno…)."""
    w = v.get('word') or ''
    righe = []
    for s in v.get('senses') or []:
        # un senso arcaico, poetico o non standard non è la lettura di un testo di oggi: su non è suo, ne non è in
        if set(s.get('tags') or []) & MARGINALI:
            continue
        for fo in s.get('form_of') or []:
            righe += [(w, l, 'forma') for l in lemmi_puliti(fo.get('word'))]
        g = (s.get('glosses') or [''])[0]
        m = RIDUZIONE.search(g)
        if m and not s.get('form_of'):
            righe += [(w, l, 'riduzione') for l in lemmi_puliti(m.group(1))]
    # le tavole delle forme (avere: ho, hai; suo: sua, suoi, sue), ma non quelle degli articoli, che elencano gli altri
    # articoli (la: il) e facevano di il una forma di la, né quelle dei pronomi (lo: la, li, le), per la stessa ragione;
    # niente maiuscole (il numerale I di primo non è la forma i)
    if not forma_flessa(v) and v.get('pos') not in ('article', 'pron'):
        for f in v.get('forms') or []:
            forma, et = f.get('form') or '', set(f.get('tags') or [])
            if (et and not et & FUORI_TAVOLA and forma and forma != w and ' ' not in forma and not forma.startswith('-')
                    and forma == forma.lower()):
                righe.append((forma, w, 'tavola'))
    return [r for r in righe if r[0] and r[1] and r[0] != r[1]]


if __name__ == '__main__':
    n = tenuti = flesse = senza = promosse = flesse_dalla_glossa = dalla_ety = non_parole = dal_testo = radici_dalla_ety = varianti_legate = basi_dalla_menzione = dalle_radici = 0
    esempi_testo = 0
    out = open(sys.argv[1], 'w', encoding='utf-8')
    glosse = open(sys.argv[2], 'w', encoding='utf-8')
    forme = open(os.environ['FORME'], 'w', encoding='utf-8') if os.environ.get('FORME') else None
    analisi_f = open(os.environ['ANALISI'], 'w', encoding='utf-8') if os.environ.get('ANALISI') else None
    righe_analisi = Counter()
    # VARIANTI: le ricostruzioni alternative della stessa forma (*gʰeh₁bʰ- e *gʰebʰ-), una riga «variante, principale»
    varianti_f = open(os.environ['VARIANTI'], 'w', encoding='utf-8') if os.environ.get('VARIANTI') else None
    varianti, esempi_varianti = Counter(), 0
    # SENZA: per ogni lemma senza etimologia utile, la causa (diagnosi: perché zoo non ha una catena)
    senza_f = open(os.environ['SENZA'], 'w', encoding='utf-8') if os.environ.get('SENZA') else None
    cause, modelli_ignoti = Counter(), Counter()
    # DISCENDENTI: l'albero dei discendenti dichiarati da ogni pagina, una riga per nodo: parola, numero
    # dell'etimologia, se è ricostruita, profondità, lingua e parola del discendente, segni (bor, der, unc…)
    discendenti_f = open(os.environ['DISCENDENTI'], 'w', encoding='utf-8') if os.environ.get('DISCENDENTI') else None
    # RADICI_CORRISPONDENTI: le radici di un'altra lingua che la pagina di una radice dichiara («ש־ל־ם: … Cognate with
    # Arabic root س ل م», {{ar-root}} nell'etimologia di una radice ebraica): lingua, radice, altra lingua, sua radice
    corrispondenti_f = open(os.environ['RADICI_CORRISPONDENTI'], 'w', encoding='utf-8') if os.environ.get('RADICI_CORRISPONDENTI') else None
    corrispondenti = 0
    # MEMBRI_RADICE: parola e radice che la pagina dichiara, anche quando ha un etimo storico (كَلْب: *kalb- e ك ل ب)
    membri_f = open(os.environ['MEMBRI_RADICE'], 'w', encoding='utf-8') if os.environ.get('MEMBRI_RADICE') else None
    righe_discendenti = pagine_discendenti = 0
    # DIAGNOSI_MODELLI=ety,etymon: alcuni esempi grezzi di quei modelli nel registro, per imparare a leggerli
    diagnosi = set(filter(None, os.environ.get('DIAGNOSI_MODELLI', '').split(',')))
    esempi_diagnosi = Counter()
    # DIAGNOSI_PAROLE=audientia,acquiesco: i modelli grezzi di quelle parole, per capire perché non si leggono
    parole_diagnosi = set(filter(None, os.environ.get('DIAGNOSI_PAROLE', '').split(',')))
    # DIAGNOSI_POS=ar:root,ar:verb: quante voci di quella parte del discorso, e le prime 10, grezze
    pos_diagnosi = {x.split(':', 1)[1] for x in os.environ.get('DIAGNOSI_POS', '').split(',') if x.startswith(LINGUA + ':')}
    conti_pos, esempi_pos = Counter(), Counter()
    for riga in sys.stdin:
        n += 1
        try: v = json.loads(riga)
        except Exception: continue
        if v.get('lang_code') != LINGUA: continue
        tpl = v.get('etymology_templates') or []
        sensi = v.get('senses') or []
        if v.get('pos') in pos_diagnosi:
            conti_pos[v['pos']] += 1
            if esempi_pos[v['pos']] < 10:
                esempi_pos[v['pos']] += 1
                print('  pos ' + json.dumps({'parola': v.get('word'), 'pos': v.get('pos'), 'titolo': v.get('original_title'),
                                             'testa': ((v.get('head_templates') or [{}])[0].get('expansion') or '')[:80],
                                             'modelli': [t.get('name') for t in tpl], 'testo': (v.get('etymology_text') or '')[:200],
                                             'sensi': [((s.get('glosses') or [''])[0][:80], s.get('tags'), bool(s.get('form_of'))) for s in sensi][:3]},
                                            ensure_ascii=False)[:1500], file=sys.stderr)
        if v.get('word') in parole_diagnosi:
            print('  parola ' + json.dumps({'parola': v.get('word'), 'pos': v.get('pos'), 'modelli': tpl,
                                             'testo': (v.get('etymology_text') or '')[:300],
                                             'sensi': [(s.get('glosses') or [''])[0][:60] for s in sensi][:3],
                                             'discendenti': list(discendenti(v))[:12]}, ensure_ascii=False)[:2500],
                  file=sys.stderr)
        for t in tpl:
            if t.get('name') in diagnosi and esempi_diagnosi[t['name']] < 10:
                esempi_diagnosi[t['name']] += 1
                print('  esempio ' + json.dumps({'parola': v.get('word'), 'modello': t, 'testo': (v.get('etymology_text') or '')[:300],
                                                  'altri': [x.get('name') for x in tpl]}, ensure_ascii=False), file=sys.stderr)
        if non_parola(v):
            non_parole += 1
            continue
        if membri_f and v.get('pos') != 'root' and not forma_flessa(v):
            rs = radice_semitica(tpl, LINGUA)
            if rs:
                membri_f.write(f"{v['word']}\t{v.get('etymology_number') or 1}\t{rs['args']['3']}\n")
        if corrispondenti_f and v.get('pos') == 'root':
            for t in tpl:
                altra = MODELLI_RADICE.get(t.get('name'))
                r = ((t.get('args') or {}).get('1') or '').strip()
                if altra and altra != LINGUA and r:
                    corrispondenti_f.write(f"{v['word']}\t{altra}\t{r}\n")
                    corrispondenti += 1
        if discendenti_f and v.get('descendants'):
            ric = '1' if (v.get('original_title') or '').startswith('Reconstruction:') else ''
            scritte = 0
            for prof, ld, pd, segni in discendenti(v):
                pd = pd.replace('\t', ' ').replace('\n', ' ')
                discendenti_f.write(f"{v['word']}\t{v.get('etymology_number') or 1}\t{ric}\t{prof}\t{ld}\t{pd}\t{','.join(segni)}\n")
                scritte += 1
            righe_discendenti += scritte
            pagine_discendenti += 1
            if pagine_discendenti <= 2:
                print('  discendenti, esempio grezzo: ' + json.dumps({'parola': v.get('word'), 'd': v['descendants'][:4]},
                                                                      ensure_ascii=False)[:1200] + f' → {scritte} righe', file=sys.stderr)
        if varianti_f and (v.get('original_title') or '').startswith('Reconstruction:'):
            for variante, principale, fonte in ricostruzioni_alternative(v):
                varianti_f.write(f'{variante}\t{principale}\n')
                varianti[fonte] += 1
                if esempi_varianti < 10:
                    esempi_varianti += 1
                    print(f'  variante ({fonte}): *{variante} → *{principale}', file=sys.stderr)
        if analisi_f:
            for forma, lemma, fonte in forme_per_analisi(v):
                analisi_f.write(f'{forma}\t{lemma}\t{fonte}\n')
                righe_analisi[fonte] += 1
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
                                 json.dumps(pronuncia(v), ensure_ascii=False) if pronuncia(v) else '',
                                 # ottava colonna: la riga delle forme e le accezioni, in JSON
                                 json.dumps(dati_scheda(v), ensure_ascii=False) if dati_scheda(v) else '')) + '\n')
        tpl = [{**t, 'name': ALIAS.get(t.get('name'), t.get('name'))} for t in tpl]
        classici = [t for t in tpl if t.get('name') in UTILI]
        if not any(porta_etimo(t) for t in classici):
            # solo per le voci che non hanno già un etimo nei modelli classici: quelle che leggiamo bene non cambiano
            conv = next((c for c in (da_ety(t, LINGUA) for t in tpl if t.get('name') in ('ety', 'etymon')) if c), None)
            if conv:
                classici = [conv] + classici
                dalla_ety += 1
            elif (conv := radice_semitica(tpl, LINGUA)):
                classici = [conv] + classici
                dalle_radici += 1
            else:
                conv = base_dalla_menzione(v, LINGUA)
                if conv:
                    classici = [conv] + classici
                    basi_dalla_menzione += 1
                    if basi_dalla_menzione <= 12:
                        print(f"  base dalla menzione: {v.get('word')} = {conv['args']['2']} + {conv['args']['3']}", file=sys.stderr)
        else:
            porta_identificativi(classici, tpl, LINGUA)
        if not any(t.get('name') == 'root' for t in classici):
            dichiarate = [r for t in tpl if t.get('name') in ('ety', 'etymon') for r in radici_ety(t, LINGUA)]
            for lr, radice, ident in dict.fromkeys(dichiarate):
                classici.append({'name': 'root', 'args': {'1': LINGUA, '2': lr, '3': radice, **({'id': ident} if ident else {})},
                                 'expansion': ''})
            radici_dalla_ety += bool(dichiarate)
        tpl = [{'n': t['name'], 'a': t.get('args', {}), 'e': t.get('expansion', '')} for t in classici]
        if not tpl:
            tpl = menzione_come_der(v)
            promosse += bool(tpl)
        if not tpl:
            tpl = surf_come_af(v) or modello_di_ripiego(v) or testo_come_der(v)
            dal_testo += bool(tpl)
            if tpl and esempi_testo < 25:
                esempi_testo += 1
                print('  dal testo: ' + json.dumps({'parola': v.get('word'), 'testo': (v.get('etymology_text') or '')[:160],
                                                    'modello': tpl[0]}, ensure_ascii=False), file=sys.stderr)
        if not tpl:
            tpl = variante_di(v)
            varianti_legate += bool(tpl)
            if tpl and varianti_legate <= 12:
                print(f"  variante: {v.get('word')} → {tpl[0]['a']['2']} ({((v.get('senses') or [{}])[0].get('glosses') or [''])[0][:60]})", file=sys.stderr)
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
                              'se': dati_scheda(v),
                              'rec': (v.get('original_title') or '').startswith('Reconstruction:')}, ensure_ascii=False) + '\n')
        tenuti += 1
    if pos_diagnosi:
        print(f'  pos, conti in {LINGUA}: {dict(conti_pos)}', file=sys.stderr)
    if corrispondenti:
        print(f'  radici corrispondenti dichiarate dalle radici: {corrispondenti}', file=sys.stderr)
    print(f'righe {n}, lemmi con etimologia {tenuti} (dal solo testo {promosse}, dal testo senza modelli o da surf, it-verb-obj, from, contraction {dal_testo}, da {{{{ety}}}} {dalla_ety}; con una radice dichiarata da {{{{ety}}}} {radici_dalla_ety}; varianti senza etimologia legate al lemma {varianti_legate}; basi lette dalla menzione prima del suffisso {basi_dalla_menzione}; dalla radice semitica {dalle_radici}), forme flesse {flesse} '
          f'(riconosciute dalla sola glossa: {flesse_dalla_glossa}), '
          f'lemmi senza etimologia utile {senza}, sigle e simboli esclusi {non_parole}', file=sys.stderr)
    if discendenti_f:
        print(f'  discendenti dichiarati: {pagine_discendenti} pagine, {righe_discendenti} righe', file=sys.stderr)
    if varianti_f:
        print(f'  ricostruzioni alternative: {dict(varianti)}', file=sys.stderr)
    if analisi_f:
        print(f"  forme per l'analisi: {dict(righe_analisi)}", file=sys.stderr)
    if senza:
        print(f'  senza etimologia utile, per causa: {dict(cause)}; modelli non letti più frequenti: '
              f'{modelli_ignoti.most_common(25)}', file=sys.stderr)
