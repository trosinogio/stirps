#!/usr/bin/env python3
"""Il datatore dei dizionari (import/DATAZIONI.md, passo 1): per ogni voce del Lewis & Short e dell'LSJ, l'autore datato
più antico tra quelli che la voce cita, come stima della prima attestazione (terminus ante quem). Solo libreria standard.

    python3 datatore_dizionari.py autori autori.tsv
        Interroga Wikidata: gli autori con un identificativo PHI (P1055) o TLG (P1041), con nascita, morte, floruit,
        periodo d'attività. Scrive: lingua, identificativo, nome, anno_da, anno_a, precisione, wikidata.
    python3 datatore_dizionari.py stime autori.tsv stime.tsv lat.ls.perseus-eng2.xml grc.lsj.perseus-eng*.xml
        Scrive: chiave della voce del dizionario, lingua, lemma, anno, precisione, autore, opera, fonte, confidenza.

La data di un autore è il terminus ante quem dei suoi testi: la morte, o la fine del periodo d'attività, o il floruit;
con la precisione di Wikidata (anno, decennio, secolo). Si usano solo le citazioni con l'identificativo dell'opera
(urn:cts:latinLit:phi0119…, Perseus:abo:tlg,0012,…), non le sigle da sole.
"""
import json, re, sys, time, unicodedata, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from filtra_perseus import da_beta, GRECO
from wiktionary import nome_pagina

SPARQL = 'https://query.wikidata.org/sparql'
QUERY = """
SELECT ?id ?prop ?item ?nome ?morte ?pm ?fine ?pf ?fl ?pfl ?nascita ?pn WHERE {
  VALUES ?prop { wdt:P1055 wdt:P1041 }
  ?item ?prop ?id .
  OPTIONAL { ?item rdfs:label ?nome FILTER(lang(?nome) = 'it') }
  OPTIONAL { ?item p:P570/psv:P570 [ wikibase:timeValue ?morte; wikibase:timePrecision ?pm ] }
  OPTIONAL { ?item p:P2032/psv:P2032 [ wikibase:timeValue ?fine; wikibase:timePrecision ?pf ] }
  OPTIONAL { ?item p:P1317/psv:P1317 [ wikibase:timeValue ?fl; wikibase:timePrecision ?pfl ] }
  OPTIONAL { ?item p:P569/psv:P569 [ wikibase:timeValue ?nascita; wikibase:timePrecision ?pn ] }
}"""


def anno(valore):
    """«-0183-01-01T00:00:00Z» → -183 (gli anni a.C. di Wikidata sono già negativi, senza anno zero: -0184 è il 184 a.C.)"""
    m = re.match(r'^([+-]?)(\d+)-', valore or '')
    return None if not m else (-int(m.group(2)) if m.group(1) == '-' else int(m.group(2)))


def autori(uscita):
    req = urllib.request.Request(SPARQL + '?' + urllib.parse.urlencode({'query': QUERY}),
                                 headers={'Accept': 'application/sparql-results+json',
                                          'User-Agent': 'Stirps/0.1 (dizionario etimologico; github.com/trosinogio/stirps)'})
    for prova in range(4):
        try:
            dati = json.load(urllib.request.urlopen(req, timeout=180))
            break
        except Exception:
            if prova == 3:
                raise
            time.sleep(20 * (prova + 1))
    migliori = {}
    for r in dati['results']['bindings']:
        v = {k: x['value'] for k, x in r.items()}
        lingua = 'la' if v['prop'].endswith('P1055') else 'grc'
        ident = ('phi' if lingua == 'la' else 'tlg') + v['id'].zfill(4)
        # il terminus ante quem: morte, fine dell'attività, floruit; la nascita più sessant'anni, in mancanza d'altro
        for chiave, prec, scarto in (('morte', 'pm', 0), ('fine', 'pf', 0), ('fl', 'pfl', 0), ('nascita', 'pn', 60)):
            if v.get(chiave):
                a = anno(v[chiave]) + scarto
                precisione = 'secolo' if int(v.get(prec, 9)) <= 7 else 'circa' if int(v.get(prec, 9)) == 8 or scarto else 'esatta'
                break
        else:
            continue
        nome = v.get('nome') or v['item'].rsplit('/', 1)[-1]
        candidato = (a, precisione, nome, v['item'].rsplit('/', 1)[-1])
        # più elementi di Wikidata per lo stesso autore: vale la data più antica
        if ident not in migliori or a < migliori[ident][1][0]:
            migliori[ident] = (lingua, candidato)
    with open(uscita, 'w', encoding='utf-8') as f:
        for ident, (lingua, (a, precisione, nome, item)) in sorted(migliori.items()):
            f.write('\t'.join((lingua, ident, nome.replace('\t', ' '), str(a), '\\N', precisione, item)) + '\n')
    print(f'autori datati: {len(migliori)}', file=sys.stderr)


IDENT = re.compile(r'(phi\d{4}|tlg,?\d{4})(?:[.,](\w+))?')


def stime(file_autori, uscita, file_xml):
    date = {}
    for r in open(file_autori, encoding='utf-8'):
        lingua, ident, nome, a, _, precisione, item = r.rstrip('\n').split('\t')
        date[ident] = (int(a), precisione, nome)
    conta = {'voci': 0, 'con_citazioni': 0, 'datate': 0}
    with open(uscita, 'w', encoding='utf-8') as out:
        for percorso in file_xml:
            lsj = '.lsj.' in percorso
            for _, el in ET.iterparse(percorso, events=('end',)):
                if el.tag != 'entryFree':
                    continue
                conta['voci'] += 1
                chiave_dz, ident_voce = el.get('key') or '', el.get('id') or ''
                base = re.sub(r'\d+$', '', chiave_dz).strip()
                if lsj:
                    lingua, lemma = 'grc', da_beta(base).strip(' ,.:;')
                    if not GRECO.match(lemma or '-'):
                        el.clear(); continue
                else:
                    lingua = 'la'
                    lemma = re.sub(r'[^\w\- ]', '', base.replace('j', 'i').replace('J', 'I').replace('æ', 'ae').replace('œ', 'oe')).strip()
                lemma = nome_pagina(lingua, unicodedata.normalize('NFC', lemma))
                citati = []
                for b in el.iter('bibl'):
                    m = IDENT.search(b.get('n') or '')
                    if m:
                        ident = m.group(1).replace(',', '')
                        if ident in date:
                            citati.append((date[ident], ident, m.group(2)))
                conta['con_citazioni'] += bool(citati)
                if citati and lemma and ident_voce and el.get('type') != 'spur':
                    (a, precisione, nome), ident, opera = min(citati, key=lambda x: x[0][0])
                    # confidenza: 3 se la datazione è all'anno o al decennio, 2 se è per secolo
                    conf = 2 if precisione == 'secolo' else 3
                    fonte = 'LSJ' if lsj else 'Lewis & Short'
                    out.write('\t'.join((f"perseus:{'lsj' if lsj else 'ls'}:{ident_voce}", lingua, lemma, str(a), precisione,
                                         nome, f'{ident}.{opera}' if opera else ident, fonte, str(conf))) + '\n')
                    conta['datate'] += 1
                el.clear()
    print(conta, file=sys.stderr)


if __name__ == '__main__':
    if sys.argv[1] == 'autori':
        autori(sys.argv[2])
    elif sys.argv[1] == 'stime':
        stime(sys.argv[2], sys.argv[3], sys.argv[4:])
