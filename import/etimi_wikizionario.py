#!/usr/bin/env python3
"""Le etimologie del Wikizionario (it.wiktionary.org) per le voci italiane: legge dallo standard input il dump di Kaikki
(«All languages combined») e scrive righe nel formato di filtra_perseus.py --etimi, con opera «Wikizionario»:

    chiave, lingua, lemma, ordine, lingua dell'etimo, etimo, tipo, affisso, opera

Il Wikizionario scrive l'etimologia a parole, con frasi brevi e regolari, e si leggono solo quelle:
- «dal latino avarus», «dal greco ζῷον ossia "animale"», «dal francese antico …»: l'etimo nella sua lingua;
- «da osso», «deriva da supponente», «participio passato di …», «diminutivo di …»: una parola italiana;
- «composto da ago e puntura», «da urina e coltura»: un composto di due parole italiane;
- «vedi amminoacido», «vedi bicicletta»: un rimando, che vale come legame indeterminato con certezza 2.
Mai «Etimologia mancante», mai una frase che dubita («forse», «probabilmente», «etimologia incerta»). Le righe valgono solo
per le voci che il dizionario ha già senza un'etimologia, e solo se l'etimo è una voce del dizionario
(importa_etimi_dizionari()).

    curl -s …/itwiktionary/All%20languages%20combined/kaikki.org-dictionary-all.jsonl | python3 etimi_wikizionario.py etimi.tsv
"""
import json, re, sys, unicodedata
from collections import Counter

LINGUE = {'latino': 'la', 'latino tardo': 'la', 'latino medievale': 'la', 'latino classico': 'la', 'latino scientifico': 'la',
          'latino ecclesiastico': 'la', 'tardo latino': 'la', 'greco': 'grc', 'greco antico': 'grc', 'greco classico': 'grc',
          'greco bizantino': 'gkm', 'greco moderno': 'el', 'francese': 'fr', 'francese antico': 'fro', 'antico francese': 'fro',
          'provenzale': 'pro', 'provenzale antico': 'pro', 'occitano': 'oc', 'spagnolo': 'es', 'portoghese': 'pt', 'catalano': 'ca',
          'inglese': 'en', 'tedesco': 'de', 'olandese': 'nl', 'arabo': 'ar', 'persiano': 'fa', 'turco': 'tr', 'ebraico': 'he',
          'longobardo': 'lng', 'gotico': 'got', 'francone': 'frk', 'napoletano': 'nap', 'siciliano': 'scn', 'veneziano': 'vec',
          'veneto': 'vec', 'genovese': 'lij', 'ligure': 'lij', 'lombardo': 'lmo', 'milanese': 'lmo', 'piemontese': 'pms',
          'sardo': 'sc', 'russo': 'ru', 'giapponese': 'ja', 'sanscrito': 'sa'}
_LINGUA = '|'.join(sorted(map(re.escape, LINGUE), key=len, reverse=True))
_PAROLA = r"([^\W\d_][\w'’-]*)"
DALLA_LINGUA = re.compile(r"^(?:dal|dallo|dalla|dall['’]|deriva dal|deriva dallo|deriva dall['’])\s*(" + _LINGUA + r")\s+" + _PAROLA, re.I)
COMPOSTO = re.compile(r"^(?:composto|composta|parola composta|formato)?\s*(?:da|di)\s+" + _PAROLA + r"\s+e\s+" + _PAROLA + r"\s*$", re.I)
DA_PAROLA = re.compile(r"^(?:deriva(?:to|ta)?\s+da|da|participio (?:passato|presente) di|gerundio di|diminutivo di|"
                       r"accrescitivo di|vezzeggiativo di|peggiorativo di|alterato di|deverbale di|denominale di|"
                       r"femminile di|aferesi di|abbreviazione di|accorciamento di)\s+" + _PAROLA + r"\s*$", re.I)
VEDI = re.compile(r"^vedi\s+" + _PAROLA + r"\s*$", re.I)
DUBBIO = re.compile(r"\b(?:forse|probabilmente|incert|dubbi|ignot|oscur|mancante|non chiar|ipotes|si suppone)", re.I)


def leggi(testo, parola):
    """Le righe (ordine, lingua, etimo, tipo, certezza) di una frase del Wikizionario, o [] se non è una frase che sappiamo
    leggere. Conta la prima frase, fino al punto e virgola o al punto; per «dal latino X, …» basta l'inizio."""
    t = ' '.join(str(testo).split()).strip()
    t = re.sub(r'^\([^)]*\)\s*', '', t)                    # «(anatomia)dal latino …»
    if not t or DUBBIO.search(t.split(';')[0]):
        return []
    m = DALLA_LINGUA.match(t)
    if m:
        lingua = LINGUE[m.group(1).lower()]
        etimo = m.group(2).strip("'’-")
        return [(1, lingua, etimo, 'generico', 3)] if etimo else []
    frase = re.split(r'[;.:(]|,', t, maxsplit=1)[0].strip()
    m = COMPOSTO.match(frase)
    if m and m.group(1).lower() not in LINGUE:
        return [(1, 'it', m.group(1), 'composizione', 3), (2, 'it', m.group(2), 'composizione', 3)]
    m = DA_PAROLA.match(frase)
    if m and m.group(1).lower() not in LINGUE and m.group(1).lower() != parola.lower():
        return [(1, 'it', m.group(1), 'derivazione', 3)]
    m = VEDI.match(frase)
    if m and m.group(1).lower() != parola.lower():
        return [(1, 'it', m.group(1), 'generico', 2)]
    return []


def esc(v):
    return '\\N' if v is None or v == '' else str(v).replace('\\', '\\\\').replace('\t', ' ').replace('\n', ' ')


if __name__ == '__main__':
    out = open(sys.argv[1], 'a', encoding='utf-8')
    conta, esempi, viste = Counter(), [], set()
    for riga in sys.stdin:
        try:
            v = json.loads(riga)
        except Exception:
            continue
        parola = v.get('word')
        if v.get('lang_code') != 'it' or not parola or parola in viste:
            continue
        testi = v.get('etymology_texts') or ([v['etymology_text']] if v.get('etymology_text') else [])
        if not testi:
            continue
        viste.add(parola)                      # una voce per parola: la prima etimologia, come nel Wikizionario
        righe = leggi(testi[0], parola)
        conta['con etimologia'] += 1
        if not righe:
            conta['non lette'] += 1
            continue
        conta[righe[0][3]] += 1
        if len(esempi) < 25 and conta['lette'] % 400 == 0:
            esempi.append(f'{parola}: {testi[0][:90]} → ' + ' + '.join(f'{l}:{e}' for _, l, e, _, _ in righe))
        conta['lette'] += 1
        for ordine, lingua, etimo, tipo, certezza in righe:
            etimo = unicodedata.normalize('NFC', etimo)
            # un rimando («vedi …») è un legame più debole: opera Wikizionario-vedi, certezza 2
            out.write('\t'.join(esc(x) for x in (f'wikizionario:it:{parola}', 'it', parola, ordine, lingua, etimo, tipo,
                                                 None, 'Wikizionario' if certezza == 3 else 'Wikizionario-vedi')) + '\n')
    print(f'etimologie del Wikizionario: {dict(conta)}', file=sys.stderr)
    for e in esempi:
        print('  ' + e, file=sys.stderr)
