#!/usr/bin/env python3
"""Il pacchetto dati di Stirps per Zenodo: i file di dati/ (tutti CC BY-SA 4.0, le definizioni di Wikidata CC0), con
LEGGIMI.txt, la guida alle colonne (COLONNE.txt, ricavata dalle tabelle d'appoggio di db/05_import_wiktionary.sql),
la licenza, CITATION.cff e le impronte SHA-256. Il lavoro della redazione non c'è: la sua licenza non è ancora decisa.

    python3 scripts/pacchetto_zenodo.py cartella_di_uscita     # → stirps-dati-AAAA-MM-GG.zip

Solo libreria standard; si lancia dalla radice del repository.
"""
import datetime, hashlib, os, re, sys, zipfile

LICENZA = """Stirps — pacchetto dati

Licenza: Creative Commons Attribuzione – Condividi allo stesso modo 4.0 Internazionale (CC BY-SA 4.0),
https://creativecommons.org/licenses/by-sa/4.0/deed.it

I dati derivano da:
- Wiktionary (en.wiktionary.org) e Wikizionario (it.wiktionary.org), via Kaikki/wiktextract: CC BY-SA 4.0;
- Perseus Digital Library (Tufts University, http://www.perseus.tufts.edu/), Lewis & Short e Liddell–Scott–Jones,
  file TEI di github.com/PerseusDL/lexica: CC BY-SA 4.0;
- FrequencyWords di Hermit Dave (OpenSubtitles 2018): CC BY-SA 4.0;
- lessemi di Wikidata: CC0 1.0 (glosse_wikidata.tsv.gz);
- traduzioni, definizioni e aree di significato scritte in automatico (OPUS-MT, Claude di Anthropic): CC BY-SA 4.0,
  come le fonti da cui nascono.

Chi riusa i dati deve citare Stirps e le fonti qui sopra, e distribuire le opere derivate con la stessa licenza.
Le voci scritte o rivedute dalla redazione di Stirps non sono in questo pacchetto.
"""


def colonne():
    """file → colonne, dalle tabelle d'appoggio di 05_import_wiktionary.sql e dall'elenco di inizializza-db.mjs."""
    sql = open('db/05_import_wiktionary.sql', encoding='utf-8').read()
    schema = open('db/01_schema.sql', encoding='utf-8').read()
    js = open('scripts/inizializza-db.mjs', encoding='utf-8').read()
    tabelle = {}
    for m in re.finditer(r'create unlogged table if not exists (stg_\w+) \((.*?)\);', sql, re.S):
        tabelle[m.group(1)] = [c.strip().split()[0] for c in re.sub(r'--[^\n]*', '', m.group(2)).split(',') if c.strip()]
    for m in re.finditer(r'alter table (stg_\w+) ((?:add column if not exists \w+ \w+,?\s*)+);', sql):
        for c in re.findall(r'add column if not exists (\w+)', m.group(2)):
            if c not in tabelle.setdefault(m.group(1), []):
                tabelle[m.group(1)].append(c)
    m = re.search(r'create table if not exists frequenza \((.*?)\);|create table frequenza \((.*?)\);', schema, re.S)
    corpo = re.sub(r'--[^\n]*', '', (m.group(1) or m.group(2))) if m else ''
    freq = [x for x in re.findall(r'^\s*(\w+)\s+\w', corpo, re.M) if x not in ('primary', 'unique', 'constraint', 'check')]
    out = {}
    for tab, file in re.findall(r"\['(stg_\w+)', '(\w+)'\]", js):
        out[file + '.tsv.gz'] = tabelle.get(tab, [])
    for f in sorted(os.listdir('dati')):
        if f.startswith('frequenze_'):
            out[f] = freq
    return out


def main():
    uscita = sys.argv[1] if len(sys.argv) > 1 else '.'
    oggi = datetime.date.today().isoformat()
    nome = os.path.join(uscita, f'stirps-dati-{oggi}.zip')
    col = colonne()
    righe_col = ['Le colonne dei file (TSV compressi con gzip, senza intestazione; \\N è il valore mancante).', '']
    impronte = []
    with zipfile.ZipFile(nome, 'w', zipfile.ZIP_STORED) as z:          # i .gz sono già compressi
        for f in sorted(os.listdir('dati')):
            if not f.endswith('.tsv.gz'):
                continue
            percorso = os.path.join('dati', f)
            z.write(percorso, f'stirps-dati/{f}')
            impronte.append(f'{hashlib.sha256(open(percorso, "rb").read()).hexdigest()}  {f}')
            righe_col.append(f"{f}: {', '.join(col.get(f, [])) or '(vedi LEGGIMI.txt)'}")
        z.writestr('stirps-dati/LEGGIMI.txt', open('dati/LEGGIMI.txt', encoding='utf-8').read())
        z.writestr('stirps-dati/COLONNE.txt', '\n'.join(righe_col) + '\n')
        z.writestr('stirps-dati/LICENZA.txt', LICENZA)
        z.writestr('stirps-dati/CITATION.cff', open('CITATION.cff', encoding='utf-8').read())
        z.writestr('stirps-dati/SHA256SUMS', '\n'.join(impronte) + '\n')
    print(nome)


if __name__ == '__main__':
    main()
