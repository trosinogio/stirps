#!/usr/bin/env python3
"""Le etimologie del Wiktionnaire (fr.wiktionary.org) per le voci francesi, sul modello di etimi_wikizionario.py: legge
dallo standard input il dump di Kaikki («All languages combined» del Wiktionnaire) e scrive righe nel formato di
filtra_perseus.py --etimi, con opera «Wiktionnaire»:

    chiave, lingua, lemma, ordine, lingua dell'etimo, etimo, tipo, affisso, opera

Il Wiktionnaire apre l'etimologia con la data tra parentesi («(XIIe siècle)», «(Date à préciser)») e poi una frase
regolare; si leggono solo queste:
- «Du latin avarus», «De l'ancien français chastel», «Emprunté à l'anglais week-end», «Du grec ancien ἄγγελος»: l'etimo
  nella sua lingua;
- «Dérivé de chant, avec le suffixe -eur», «Déverbal de crier», «Diminutif de …», «Participe passé de …»: una parola
  francese (il suffisso, se c'è, va nella colonna dell'affisso);
- «Composé de porte et de manteau»: un composto di due parole francesi;
- «Voir chanter»: un rimando, che vale come legame indeterminato con certezza 2 (Wiktionnaire-vedi).
Mai «Étymologie manquante», mai una frase che dubita («peut-être», «probablement», «origine obscure»), mai una forma
ricostruita («du latin populaire *…»). Come per il Wikizionario, con i file delle voci (lessemi.tsv, dizionari.tsv) si
scrivono solo le righe in cui la parola e l'etimo sono voci del dizionario. Il confronto con Wiktionary inglese lo fa
confronta_wikizionario.py con «fr Wiktionnaire». Fonti autorevoli per il francese, da citare in redazione: TLFi, FEW,
DMF, DEAF (non Étymonaute, che è costruito sul Wiktionnaire).

    curl -s https://kaikki.org/frwiktionary/All%20languages%20combined/kaikki.org-dictionary-all.jsonl \
        | python3 etimi_wiktionnaire.py etimi.tsv [lessemi.tsv dizionari.tsv]
"""
import json, os, random, re, sys, unicodedata
from collections import Counter

from etimi_wikizionario import LATINA, SCRITTURA, carica_voci, esc

LINGUE = {'latin': 'la', 'latin classique': 'la', 'latin tardif': 'la', 'bas latin': 'la', 'bas-latin': 'la',
          'latin médiéval': 'la', 'latin ecclésiastique': 'la', 'latin chrétien': 'la', 'latin impérial': 'la',
          'latin archaïque': 'la', 'latin scientifique': 'la', 'latin savant': 'la', 'latin moderne': 'la', 'néolatin': 'la',
          'latin juridique': 'la', 'latin botanique': 'la', 'latin humaniste': 'la',
          'latin populaire': 'la-vul', 'latin vulgaire': 'la-vul', 'latin parlé': 'la-vul',
          'grec': 'grc', 'grec ancien': 'grc', 'grec classique': 'grc', 'grec tardif': 'grc', 'grec hellénistique': 'grc',
          'grec byzantin': 'gkm', 'grec médiéval': 'gkm', 'grec moderne': 'el',
          'ancien français': 'fro', 'vieux français': 'fro', 'moyen français': 'frm', 'français': 'fr',
          'ancien occitan': 'pro', 'ancien provençal': 'pro', 'occitan': 'oc', 'provençal': 'oc',
          'italien': 'it', 'ancien italien': 'it', 'espagnol': 'es', 'ancien espagnol': 'osp', 'portugais': 'pt',
          'catalan': 'ca', 'anglais': 'en', 'moyen anglais': 'enm', 'vieil anglais': 'ang', 'ancien anglais': 'ang',
          'allemand': 'de', 'moyen haut-allemand': 'gmh', 'moyen haut allemand': 'gmh', 'ancien haut allemand': 'goh',
          'ancien haut-allemand': 'goh', 'vieux haut allemand': 'goh', 'vieux haut-allemand': 'goh', 'francique': 'frk',
          'néerlandais': 'nl', 'moyen néerlandais': 'dum', 'gotique': 'got', 'vieux norrois': 'non', 'norrois': 'non',
          'gaulois': 'xtg', 'breton': 'br', 'basque': 'eu', 'arabe': 'ar', 'arabe classique': 'ar', 'persan': 'fa',
          'turc': 'tr', 'hébreu': 'he', 'russe': 'ru', 'japonais': 'ja', 'sanskrit': 'sa', 'hindi': 'hi'}
_LINGUA = '|'.join(sorted(map(re.escape, LINGUE), key=len, reverse=True))
_PAROLA = r"([^\W\d_][\w'’-]*)"
_ART = r"(?:du|des|de\s+la|de\s+l['’]|de|d['’]|au|aux|à\s+la|à\s+l['’]|à)"
# «Du latin X», «Emprunté au latin X», «Issu de l'ancien français X», «Dérivé du latin X»
DALLA_LINGUA = re.compile(r"^(?:(?:mot\s+)?(?:emprunt(?:é|ée|és)?|issu|issue|hérité|héritée|dérivé|dérivée|tiré|tirée|venu|"
                          r"calque|calqué)\s+)?" + _ART + r"\s*(" + _LINGUA + r")\s+" + _PAROLA, re.I)
# dopo l'etimo vengono la fine, un segno, una glossa o un connettivo: «du latin X et Y» è una locuzione, e resta fuori
DOPO_ETIMO = re.compile(r"\s*(?:$|[,;.:()«»\"“”‘'’\[\]/–-]|(?:lui-même|elle-même|qui|par|via|avec|de|du|des|d['’]|au|aux|à|"
                        r"dans|pour|issu|dérivé|composé|peut-être|probablement|même\s+sens|sens)\b)", re.I)
NON_ETIMI = {'composé', 'composée', 'dérivé', 'dérivée', 'mot', 'terme', 'nom', 'forme', 'verbe', 'adjectif', 'radical',
             'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'même', 'origine',
             'populaire', 'classique', 'médiéval', 'tardif', 'vulgaire', 'ecclésiastique', 'scientifique', 'savant',
             'ancien', 'moderne', 'impérial', 'chrétien', 'archaïque', 'byzantin', 'hellénistique', 'moyen', 'vieux'}
COMPOSTO = re.compile(r"^composée?\s+(?:de|du|d['’])\s*" + _PAROLA + r"\s*,?\s+et\s+(?:de\s+|du\s+|d['’]\s*)?"
                      + _PAROLA + r"\s*$", re.I)
CON_AFFISSO = re.compile(r"^(?:dérivé|dérivée)\s+(?:de|du|d['’])\s*" + _PAROLA + r"\s*,?\s+avec\s+le\s+(?:suffixe|préfixe)\s+"
                         r"(-?[^\W\d_][\w-]*-?)\s*$", re.I)
DA_PAROLA = re.compile(r"^(?:dérivé|dérivée|dérivé\s+de|dérivée\s+de|de|déverbal\s+de|dénominal\s+de|diminutif\s+de|augmentatif\s+de|"
                       r"péjoratif\s+de|féminin\s+de|participe\s+passé\s+de|participe\s+présent\s+de|substantivation\s+de|"
                       r"nominalisation\s+de|apocope\s+de|aphérèse\s+de|abréviation\s+de|troncation\s+de)\s*(?:d['’])?\s*"
                       + _PAROLA + r"\s*$", re.I)
VEDI = re.compile(r"^voir\s+" + _PAROLA + r"\s*$", re.I)
# un dubbio sull'etimologia della parola; «du latin X, d'origine obscure» parla invece dell'etimo, e si legge
DUBBIO = re.compile(r"(?:peut-être|probablement|sans doute|vraisemblablement|incertain|douteu|controvers|manquant|"
                    r"incomplèt|\bserait\b|\bpourrait\b|\bsemble\b|on suppose|à préciser|^(?:d['’]\s*)?origine\b)", re.I)
DATA = re.compile(r"^\s*(?:\((?:[^()]|\([^()]*\))*\)\s*)+")       # «(XIIe siècle)», «(1546)», «(Date à préciser)»


# «Mot dérivé de», «Locution composée de»: Kaikki toglie lo spazio dopo il corsivo («motdérivé de»)
NOME_INIZIALE = re.compile(r"^(?:mot|nom|locution|toponyme|adjectif|verbe|adverbe)\s*(?=(?:dérivée?|composée?)\b)", re.I)


def pulisci(testo):
    t = ' '.join(str(testo).split()).strip()
    t = re.sub(r'\[\d+\]', '', t)                               # le note: «du latin avarus[1]»
    return NOME_INIZIALE.sub('', DATA.sub('', t).strip())


def leggi(testo, parola, propria='fr'):
    """Le righe (ordine, lingua, etimo, tipo, affisso, certezza) di una frase del Wiktionnaire, o [] se non è una frase
    che sappiamo leggere. Conta la prima frase, fino al punto e virgola o al punto; per «Du latin X, …» basta l'inizio.
    propria è la lingua della parola: fr, o grc per le voci di greco antico («Dérivé de λόγος, avec le suffixe -ικός»),
    dove un etimo della stessa lingua dev'essere scritto in greco."""
    righe = _leggi(testo, parola, propria)
    if propria in SCRITTURA:
        righe = [(o, l, senza_quantita(e) if l == propria else e, tp, aff, c) for o, l, e, tp, aff, c in righe]
        if any(l == propria and not SCRITTURA[propria].match(e) for _, l, e, _, _, _ in righe):
            return []
    return righe


def senza_quantita(w):
    """Il titolo della pagina di una parola greca: senza macron e brevi (ἀγορᾱ́ → ἀγορά)."""
    return unicodedata.normalize('NFC', ''.join(c for c in unicodedata.normalize('NFD', w) if c not in '\u0304\u0306'))


def _leggi(testo, parola, propria):
    t = pulisci(testo)
    if not t or DUBBIO.search(t.split(';')[0].split('. ')[0]):
        return []
    m = DALLA_LINGUA.match(t)
    if m:
        lingua = LINGUE[' '.join(m.group(1).lower().split())]
        etimo = m.group(2).strip("'’-")
        if not etimo or len(etimo) < 2 or etimo.lower() in NON_ETIMI or not DOPO_ETIMO.match(t[m.end():]):
            return []
        if not (SCRITTURA[lingua].match(etimo) if lingua in SCRITTURA else LATINA.match(etimo)):
            return []
        if lingua in ('grc', 'gkm', 'el'):
            etimo = etimo.replace('ϕ', 'φ').replace('ϑ', 'θ')
        # una parola francese da un'altra francese («du français X») è una derivazione, non un prestito
        return [(1, lingua, etimo, 'derivazione' if lingua == propria else 'generico', None, 3)]
    frase = re.split(r'[;.:(]', t, maxsplit=1)[0].strip()
    m = COMPOSTO.match(frase)
    if m and m.group(1).lower() not in LINGUE and m.group(1).lower() not in NON_ETIMI:
        return [(1, propria, m.group(1), 'composizione', None, 3), (2, propria, m.group(2), 'composizione', None, 3)]
    m = CON_AFFISSO.match(frase)
    if m and m.group(1).lower() not in NON_ETIMI and m.group(1).lower() != parola.lower():
        return [(1, propria, m.group(1), 'derivazione', m.group(2), 3)]
    frase = frase.split(',')[0].strip()
    m = DA_PAROLA.match(frase)
    if m and m.group(1).lower() not in LINGUE and m.group(1).lower() not in NON_ETIMI and m.group(1).lower() != parola.lower():
        return [(1, propria, m.group(1), 'derivazione', None, 3)]
    m = VEDI.match(frase)
    if m and m.group(1).lower() != parola.lower():
        return [(1, propria, m.group(1), 'generico', None, 2)]
    return []


if __name__ == '__main__':
    # LINGUE_WIKTIONNAIRE=fr,grc: le lingue delle voci da leggere (per default il solo francese); GREZZE=file: un campione
    # delle frasi grezze delle lingue diverse dal francese, per imparare a leggerle
    proprie = [x for x in os.environ.get('LINGUE_WIKTIONNAIRE', 'fr').split(',') if x]
    grezze = open(os.environ['GREZZE'], 'w', encoding='utf-8') if os.environ.get('GREZZE') else None
    out = open(sys.argv[1], 'a', encoding='utf-8')
    voci = carica_voci(sys.argv[2:])
    conta = {p: Counter() for p in proprie}
    esempi, non_lette = {p: [] for p in proprie}, {p: Counter() for p in proprie}
    viste, lingue, caso = set(), Counter(), random.Random(7)
    for riga in sys.stdin:
        try:
            v = json.loads(riga)
        except Exception:
            continue
        parola, propria = v.get('word'), v.get('lang_code')
        lingue[propria] += 1
        if propria not in conta or not parola or (propria, parola) in viste:
            continue
        if propria in SCRITTURA:
            parola = senza_quantita(parola)
        testi = [x for x in (v.get('etymology_texts') or ([v['etymology_text']] if v.get('etymology_text') else []))
                 if pulisci(x)]
        if not testi:
            conta[propria]['senza etimologia'] += 1
            continue
        c = conta[propria]
        if c['con etimologia'] < 3:              # per la diagnosi: com'è fatta una voce del dump
            print(f'  grezza ({propria}): ' + json.dumps({'word': parola, 'etymology_texts': testi[:2]}, ensure_ascii=False)[:300],
                  file=sys.stderr)
        if grezze and propria != 'fr' and caso.random() < 0.15:
            grezze.write(f"{propria}\t{parola}\t{' '.join(str(testi[0]).split())[:400]}\n")
        viste.add((propria, parola))           # una voce per parola: la prima etimologia, come nel Wiktionnaire
        righe = leggi(testi[0], parola, propria)
        c['con etimologia'] += 1
        if not righe:
            c['non lette'] += 1
            # per la diagnosi: come comincia una frase che non sappiamo leggere («Dérivé de», «Du latin», «Mot»…)
            non_lette[propria][' '.join(pulisci(testi[0]).split()[:2]).lower()] += 1
            continue
        if voci is not None and (((propria, unicodedata.normalize('NFC', parola)) not in voci)
                                 or any((l, unicodedata.normalize('NFC', e)) not in voci for _, l, e, _, _, _ in righe)):
            c['non voci'] += 1
            continue
        c[righe[0][3]] += 1
        if len(esempi[propria]) < 25 and c['lette'] % (200 if propria == 'fr' else 20) == 0:
            esempi[propria].append(f'{parola}: {pulisci(testi[0])[:90]} → ' + ' + '.join(f'{l}:{e}' for _, l, e, _, _, _ in righe))
        c['lette'] += 1
        for ordine, lingua, etimo, tipo, affisso, certezza in righe:
            out.write('\t'.join(esc(x) for x in (f'wiktionnaire:{propria}:{parola}', propria, parola, ordine, lingua,
                                                 unicodedata.normalize('NFC', etimo), tipo, affisso,
                                                 'Wiktionnaire' if certezza == 3 else 'Wiktionnaire-vedi')) + '\n')
    for p in proprie:
        print(f'etimologie del Wiktionnaire ({p}): {dict(conta[p])}', file=sys.stderr)
    print(f'  voci lette per lingua: {dict(lingue.most_common(8))}', file=sys.stderr)
    for p in proprie:
        for e in esempi[p]:
            print(f'  {p} ' + e, file=sys.stderr)
        print(f'  {p}, inizi non letti più frequenti: ' + '; '.join(f'{k} ({n})' for k, n in non_lette[p].most_common(30)),
              file=sys.stderr)
