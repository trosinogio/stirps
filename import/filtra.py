# Filtra il dump di Kaikki: lemmi con etimologia (JSONL) e glosse di tutti i lemmi (TSV).
import json, os, sys
LINGUA = os.environ.get('LINGUA', 'it')
UTILI = {'inh', 'inh+', 'bor', 'bor+', 'lbor', 'slbor', 'ubor', 'obor', 'der', 'der+', 'uder', 'cal', 'calque', 'sl', 'psm',
         'bf', 'back-form', 'clipping', 'ellipsis', 'af', 'affix', 'suffix', 'prefix', 'confix', 'compound', 'blend',
         'named-after', 'onom', 'onomatopoeic', 'unk', 'unc', 'root', 'doublet', 'dbt', 'it-deverbal', 'etydate'}
n = tenuti = flesse = senza = 0
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
    if any(t.get('name') == 'nonlemma' for t in tpl) or (sensi and all(s.get('form_of') or 'form-of' in (s.get('tags') or []) for s in sensi)):
        flesse += 1
        if forme:   # forma flessa → lemma (titoli di pagina), per le catene che citano noctem invece di nox
            for s_ in sensi:
                for fo in (s_.get('form_of') or [])[:1]:
                    if fo.get('word'):
                        forme.write(f"{v['word']}\t{fo['word']}\t{','.join(s_.get('tags') or [])}\n")
                        break
                break
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
    if not tpl: senza += 1; continue
    heads = [{'n': h.get('name'), 'a': h.get('args', {})} for h in (v.get('head_templates') or [])[:1]]
    testa = ((v.get('head_templates') or [{}])[0].get('expansion') or '')
    canonica = next((f['form'] for f in (v.get('forms') or []) if 'canonical' in (f.get('tags') or [])), None) or testa.split(' (')[0].split(' ')[0] or None
    out.write(json.dumps({'w': v['word'], 'p': v.get('pos'), 'en': v.get('etymology_number'), 't': v.get('etymology_text', ''),
                          'tpl': tpl, 'g': g, 'h': heads, 'c': canonica,
                          'rec': (v.get('original_title') or '').startswith('Reconstruction:')}, ensure_ascii=False) + '\n')
    tenuti += 1
print(f'righe {n}, lemmi con etimologia {tenuti}, forme flesse {flesse}, lemmi senza etimologia utile {senza}', file=sys.stderr)
