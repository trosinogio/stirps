# Filtra il dump dei lessemi di Wikidata (CC0): lessemi italiani con almeno un senso glossato in italiano.
# Uscita TSV: id del lessema, lemma, categoria lessicale (Q…), prima glossa italiana, numero di sensi glossati.
#   curl -s https://dumps.wikimedia.org/wikidatawiki/entities/latest-lexemes.json.bz2 | bzcat | python3 filtra_wikidata.py uscita.tsv
import json, sys
out = open(sys.argv[1], 'w', encoding='utf-8')
lette = italiani = tenuti = 0
for riga in sys.stdin:
    lette += 1
    if '"Q652"' not in riga:            # l'italiano: scarta subito il resto senza leggere il JSON
        continue
    riga = riga.strip().rstrip(',')
    if not riga.startswith('{'):
        continue
    try:
        v = json.loads(riga)
    except ValueError:
        continue
    if v.get('language') != 'Q652':
        continue
    italiani += 1
    lemma = ((v.get('lemmas') or {}).get('it') or {}).get('value')
    glosse = [s['glosses']['it']['value'] for s in (v.get('senses') or []) if 'it' in (s.get('glosses') or {})]
    if not lemma or not glosse:
        continue
    pulita = ' '.join(glosse[0].split())[:300]
    out.write('\t'.join((v['id'], lemma, v.get('lexicalCategory') or '', pulita, str(len(glosse)))) + '\n')
    tenuti += 1
print(f'righe {lette}, lessemi italiani {italiani}, con glossa italiana {tenuti}', file=sys.stderr)
