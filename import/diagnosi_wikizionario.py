#!/usr/bin/env python3
"""Diagnosi: quanti lemmi italiani senza etimologia utile in Wiktionary inglese (senza_etimologia.tsv, scritto da
filtra.py con SENZA=…) hanno un'etimologia nel Wikizionario (it.wiktionary.org). Legge dallo standard input il dump
del Wikizionario di Kaikki; stampa i conti per causa e qualche esempio. Solo libreria standard.

    curl -s https://kaikki.org/itwiktionary/All%20languages%20combined/kaikki.org-dictionary-all.jsonl \\
      | python3 diagnosi_wikizionario.py dati/it/senza_etimologia.tsv
"""
import json, random, sys
from collections import Counter, defaultdict

senza = {}
for r in open(sys.argv[1], encoding='utf-8'):
    c = r.rstrip('\n').split('\t') + ['', '', '', '', '']
    senza.setdefault(c[0], c[2])
etimologie, campi = defaultdict(set), Counter()
for riga in sys.stdin:
    try:
        v = json.loads(riga)
    except Exception:
        continue
    if v.get('lang_code') != 'it' or v.get('word') not in senza:
        continue
    testi = v.get('etymology_texts') or ([v['etymology_text']] if v.get('etymology_text') else [])
    for t in testi:
        t = ' '.join(str(t).split())
        if len(t) > 3:
            etimologie[v['word']].add(t[:240])
    campi.update(k for k in v if k.startswith('etymology'))
per_causa = Counter(senza.values())
trovate = Counter(senza[w] for w in etimologie)
print(f'lemmi italiani senza etimologia utile in Wiktionary inglese: {len(senza)}, per causa {dict(per_causa)}')
print(f'di questi, con un\'etimologia nel Wikizionario: {len(etimologie)}, per causa {dict(trovate)}; campi visti: {dict(campi)}')
random.seed(7)
for w in random.sample(sorted(etimologie), min(20, len(etimologie))):
    print(f'  {w} [{senza[w]}]: {sorted(etimologie[w])[0]}')
for w in ('zoo', 'radio', 'foto', 'bici', 'tram', 'computer'):
    if w in senza:
        print(f'  {w}: {senza[w]} | Wikizionario: {sorted(etimologie.get(w) or ["—"])[0]}')
