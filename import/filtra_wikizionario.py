#!/usr/bin/env python3
"""Glosse italiane dal Wikizionario (it.wiktionary.org), via Kaikki/wiktextract.

Legge il dump «All languages combined» dallo standard input e scrive un TSV:
lingua, parola, parte del discorso, ordine, glossa. Per ogni voce tiene la prima
definizione vera: scarta forme flesse e rimandi, residui d'intestazione, etichette
iniziali come «(botanica)». Solo libreria standard.

    curl -s https://kaikki.org/itwiktionary/All%20languages%20combined/kaikki.org-dictionary-all.jsonl \\
      | python3 filtra_wikizionario.py glosse_it.tsv
"""
import json, re, sys
from collections import Counter

FLESSE = re.compile(
    r'^(plurale|femminile|maschile|singolare|neutro|diminutivo di|accrescitivo di|superlativo|comparativo|'
    r'participio|gerundio|infinito|imperativo|congiuntivo|indicativo|condizionale|'
    r'(prima|seconda|terza) persona|voce (verbale|del verbo)|forma (flessa|alternativa|arcaica|antica|plurale)|'
    r'variante|vedi|v\.|cfr|sinonimo di|abbreviazione di|sigla di|grafia|ortografia|scritto|traslitterazione|'
    r'genitivo|dativo|accusativo|ablativo|vocativo|nominativo|caso|declinazione|coniugazione)\b', re.I)
ETICHETTA = re.compile(r'^\s*\((?:[^()]|\([^()]*\))*\)\s*')
SPAZI = re.compile(r'\s+')
SEGNAPOSTO = re.compile(r'definizione mancante|aggiungila tu', re.I)


def pulisci(gl, parola):
    g = SPAZI.sub(' ', gl or '').strip()
    if not g or 'approfondimento' in g or g.lower().startswith(parola.lower() + ' '):
        return None                          # «casa ( approfondimento) f sing»: residuo d'intestazione
    if SEGNAPOSTO.search(g):
        return None                          # «definizione mancante; se vuoi, aggiungila tu»: la pagina non ha definizione
    while ETICHETTA.match(g):
        g = ETICHETTA.sub('', g, count=1)    # «(botanica) pianta …» → «pianta …»
    g = re.sub(r'\(\s*\)', '', g).strip(' ;:.,')
    if len(g) < 2 or FLESSE.match(g):
        return None
    if len(g) > 140:                         # glossa breve: si taglia a un confine naturale
        corto = g[:140]
        taglio = max(corto.rfind(';'), corto.rfind(','))
        g = (corto[:taglio] if taglio > 60 else corto.rsplit(' ', 1)[0]).strip(' ;:.,') + '…'
    return g


def esc(v):
    return str(v).replace('\\', '\\\\').replace('\t', ' ').replace('\n', ' ').replace('\r', ' ')


ordini, lingue, n, tenute = Counter(), Counter(), 0, 0
out = open(sys.argv[1], 'w', encoding='utf-8')
for riga in sys.stdin:
    n += 1
    try:
        v = json.loads(riga)
    except Exception:
        continue
    parola, lingua, pos = v.get('word'), v.get('lang_code'), v.get('pos') or ''
    if not parola or not lingua:
        continue
    glossa = None
    for s in v.get('senses') or []:
        if s.get('form_of') or s.get('alt_of') or 'form-of' in (s.get('tags') or []):
            continue
        glossa = pulisci((s.get('glosses') or [None])[0], parola)
        if glossa:
            break
    if not glossa:
        continue
    chiave = (lingua, parola, pos)
    ordini[chiave] += 1
    lingue[lingua] += 1
    out.write('\t'.join(esc(x) for x in (lingua, parola, pos, ordini[chiave], glossa)) + '\n')
    tenute += 1
print(f'voci {n}, glosse tenute {tenute}; lingue principali: {lingue.most_common(12)}', file=sys.stderr)
