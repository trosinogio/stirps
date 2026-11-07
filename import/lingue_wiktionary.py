#!/usr/bin/env python3
"""Le lingue e le famiglie linguistiche di Wiktionary, dai suoi moduli di dati (CC BY-SA): per ogni codice il nome
canonico, la famiglia (italiano: roa-itr, italo-romanzo), gli antenati (italiano: roa-oit) e, per le lingue
«etimologiche» come il latino volgare, la lingua madre (la-vul: la-cla); per ogni famiglia la famiglia madre
(roa-itr › roa › itc › ine). Servono a mettere ogni lingua del dizionario nel suo albero genealogico
(importa_lingue_wiktionary()): oggi molte restano senza famiglia.

    python3 lingue_wiktionary.py ../dati/lingue_wiktionary.tsv ../dati/famiglie_wiktionary.tsv [../dati/lingue.tsv.gz]

Scrive, senza intestazione:
    lingue:   codice, nome inglese, famiglia, antenati (separati da virgola), madre (lingue etimologiche), tipo,
              elemento di Wikidata, nome italiano
    famiglie: codice, nome inglese, famiglia madre
Il nome italiano viene dall'etichetta di Wikidata, solo per le lingue del pacchetto (il terzo argomento, il lingue.tsv
del parser): «lingua basca» diventa «basco» (italiano()).
"""
import gzip, json, re, string, sys, time, urllib.error, urllib.parse, urllib.request

AGENTE = 'stirps-dizionario-etimologico/1.0 (https://dizionario-etimologico.vercel.app)'
MODULI_LINGUE = (['languages/data/2'] + [f'languages/data/3/{c}' for c in string.ascii_lowercase]
                 + ['languages/data/exceptional'])
BLOCCO = re.compile(r'^m\["([^"]+)"\]\s*=\s*\{\n(.*?)\n\}', re.M | re.S)
POSIZIONALE = re.compile(r'^\t(?:"((?:[^"\\]|\\.)*)"|(nil)|(\d+)|([a-zA-Z_.]+)),\s*(?:--.*)?$')
CAMPO = re.compile(r'^\t(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"')


def scarica(modulo):
    url = 'https://en.wiktionary.org/w/index.php?' + urllib.parse.urlencode({'title': 'Module:' + modulo, 'action': 'raw'})
    req = urllib.request.Request(url, headers={'User-Agent': AGENTE})
    for tentativo in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode('utf-8')
        except Exception:
            if tentativo == 3:
                raise
            time.sleep(2 ** tentativo)


def voci(testo):
    """I blocchi m["codice"] = {…}: i primi tre valori posizionali (nome, Wikidata, famiglia o madre) e i campi
    testuali al primo livello (ancestors, parent, type…)."""
    for codice, corpo in BLOCCO.findall(testo):
        pos, campi = [], {}
        for riga in corpo.split('\n'):
            m = POSIZIONALE.match(riga)
            if m and len(pos) < 4:
                pos.append(m.group(1) if m.group(1) is not None else None if m.group(2) else m.group(3) or m.group(4))
                continue
            c = CAMPO.match(riga)
            if c:
                campi[c.group(1)] = c.group(2)
        yield codice, pos, campi


# i nomi di lingua in -a che in italiano non si volgono al maschile (l'aymara, lo tswana)
INVARIABILI = {'aymara', 'tswana', 'shona', 'luganda', 'maya', 'quechua', 'chichewa', 'kiswahili', 'sesotho', 'setswana',
               'ganda', 'xhosa', 'zulu', 'oromo', 'hawaiana', 'samoa', 'tonga', 'fula', 'kituba', 'lingala', 'mapudungun'}
AGGETTIVO = re.compile(r'(ana|ina|ica|sca|ea|ara|era|ita|ata|ena|ota|ia|ca|ga|aba|ola|ssa|rda)$')


# etichette di Wikidata che non danno il nome della lingua: il nome giusto
ECCEZIONI_IT = {'nds': 'basso tedesco', 'nds-de': 'basso tedesco tedesco', 'nds-nl': 'basso sassone olandese'}


def italiano(etichetta):
    """Il nome italiano di una lingua dall'etichetta di Wikidata: «lingua basca» → «basco», «lingua protoindoeuropea» →
    «protoindoeuropeo», «giapponese antico» resta com'è. Una parola sola dopo «lingua» è un aggettivo femminile."""
    e = (etichetta or '').strip()
    if e.startswith('lingue '):
        return ''                         # un gruppo («lingue native nordamericane»), non una lingua
    m = re.match(r'^lingua (.+)$', e)
    if not m:
        return e
    parole = m.group(1).split()
    if any(p in ('di', 'dei', 'del', 'della', 'delle', 'degli', 'e') for p in parole):
        return e                          # «lingua dei segni italiana» resta intera
    return ' '.join(p[:-1] + 'o' if p.lower() not in INVARIABILI and AGGETTIVO.search(p) else p for p in parole)


def etichette_it(qid):
    """Le etichette italiane di Wikidata, cinquanta elementi per richiesta."""
    out, ids = {}, sorted(set(qid))
    for i in range(0, len(ids), 50):
        url = 'https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'wbgetentities', 'ids': '|'.join(ids[i:i + 50]), 'props': 'labels', 'languages': 'it', 'format': 'json'})
        req = urllib.request.Request(url, headers={'User-Agent': AGENTE})
        for tentativo in range(6):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    dati = json.load(r)
                break
            except urllib.error.HTTPError as e:
                if e.code != 429 or tentativo == 5:
                    raise
                time.sleep(int(e.headers.get('Retry-After') or 0) or 5 * 2 ** tentativo)   # Wikidata chiede di rallentare
        for q, ent in dati.get('entities', {}).items():
            lab = ent.get('labels', {}).get('it', {}).get('value')
            if lab:
                out[q] = lab
        time.sleep(2)
    return out


def main():
    out_lingue, out_famiglie = sys.argv[1:3]
    righe_l = []
    for modulo in MODULI_LINGUE:
        for codice, pos, campi in voci(scarica(modulo)):
            nome = pos[0] if pos else None
            famiglia = pos[2] if len(pos) > 2 and pos[2] and not pos[2].isdigit() else ''
            antenati = ','.join(a.strip() for a in campi.get('ancestors', '').split(',') if a.strip())
            tipo = campi.get('type', '')
            qid = 'Q' + pos[1] if len(pos) > 1 and pos[1] and pos[1].isdigit() else ''
            righe_l.append((codice, nome or codice, famiglia, antenati, '', tipo, qid))
        time.sleep(1)
    # le lingue etimologiche: il terzo valore è la lingua (o la famiglia) madre
    for codice, pos, campi in voci(scarica('etymology languages/data')):
        madre = campi.get('parent') or (pos[2] if len(pos) > 2 and pos[2] and not pos[2].isdigit() else '')
        qid = 'Q' + pos[1] if len(pos) > 1 and pos[1] and pos[1].isdigit() else ''
        righe_l.append((codice, pos[0] if pos else codice, '', '', madre, 'etimologica', qid))
    righe_f = [(codice, pos[0] if pos else codice, pos[2] if len(pos) > 2 and pos[2] and not pos[2].isdigit() else '')
               for codice, pos, _ in voci(scarica('families/data'))]
    # i nomi italiani, per le lingue del pacchetto
    nostre = set()
    if len(sys.argv) > 3:
        with gzip.open(sys.argv[3], 'rt', encoding='utf-8') as f:
            nostre = {r.split('\t', 1)[0] for r in f if r.strip()}
    lab = etichette_it([r[6] for r in righe_l if r[0] in nostre and r[6]]) if nostre else {}
    righe_l = [r + (ECCEZIONI_IT.get(r[0]) or italiano(lab.get(r[6], '')),) for r in righe_l]
    pulisci = lambda v: (v or '').replace('\t', ' ').replace('\n', ' ')
    with open(out_lingue, 'w', encoding='utf-8') as f:
        for r in sorted(set(righe_l)):
            f.write('\t'.join(pulisci(x) for x in r) + '\n')
    with open(out_famiglie, 'w', encoding='utf-8') as f:
        for r in sorted(set(righe_f)):
            f.write('\t'.join(pulisci(x) for x in r) + '\n')
    print(f'lingue: {len(set(righe_l))}, famiglie: {len(set(righe_f))}', file=sys.stderr)


if __name__ == '__main__':
    main()
