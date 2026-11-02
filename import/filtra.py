# Filtra il dump di Kaikki: lemmi con etimologia (JSONL) e glosse di tutti i lemmi (TSV).
import json, os, re, sys
LINGUA = os.environ.get('LINGUA', 'it')
UTILI = {'inh', 'inh+', 'bor', 'bor+', 'lbor', 'slbor', 'ubor', 'obor', 'der', 'der+', 'uder', 'cal', 'calque', 'sl', 'psm',
         'bf', 'back-form', 'clipping', 'ellipsis', 'af', 'affix', 'suffix', 'prefix', 'confix', 'compound', 'blend',
         'named-after', 'onom', 'onomatopoeic', 'unk', 'unc', 'root', 'doublet', 'dbt', 'it-deverbal', 'etydate'}
MENZIONI = {'m', 'l', 'm+', 'mention', 'link', 'l-self'}
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
                   r'|(?:comparative|superlative)(?:\s+degree)?\s+of\b)', re.I)


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
    n = tenuti = flesse = senza = promosse = flesse_dalla_glossa = 0
    out = open(sys.argv[1], 'w', encoding='utf-8')
    glosse = open(sys.argv[2], 'w', encoding='utf-8')
    forme = open(os.environ['FORME'], 'w', encoding='utf-8') if os.environ.get('FORME') else None
    for riga in sys.stdin:
        n += 1
        try: v = json.loads(riga)
        except Exception: continue
        if v.get('lang_code') != LINGUA: continue
        tpl = v.get('etymology_templates') or []
        sensi = v.get('senses') or []
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
                                 '1' if (v.get('original_title') or '').startswith('Reconstruction:') else '')) + '\n')
        tpl = [{'n': t['name'], 'a': t.get('args', {}), 'e': t.get('expansion', '')} for t in tpl if t.get('name') in UTILI]
        if not tpl:
            tpl = menzione_come_der(v)
            promosse += bool(tpl)
        if not tpl: senza += 1; continue
        heads = [{'n': h.get('name'), 'a': h.get('args', {})} for h in (v.get('head_templates') or [])[:1]]
        testa = ((v.get('head_templates') or [{}])[0].get('expansion') or '')
        canonica = next((f['form'] for f in (v.get('forms') or []) if 'canonical' in (f.get('tags') or [])), None) or testa.split(' (')[0].split(' ')[0] or None
        out.write(json.dumps({'w': v['word'], 'p': v.get('pos'), 'en': v.get('etymology_number'), 't': v.get('etymology_text', ''),
                              'tpl': tpl, 'g': g, 'h': heads, 'c': canonica,
                              'rec': (v.get('original_title') or '').startswith('Reconstruction:')}, ensure_ascii=False) + '\n')
        tenuti += 1
    print(f'righe {n}, lemmi con etimologia {tenuti} (dal solo testo {promosse}), forme flesse {flesse} '
          f'(riconosciute dalla sola glossa: {flesse_dalla_glossa}), '
          f'lemmi senza etimologia utile {senza}', file=sys.stderr)
