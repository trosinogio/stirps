#!/usr/bin/env python3
"""Deposita su Zenodo il pacchetto di pacchetto_zenodo.py, con i metadati di .zenodo.json: un deposito nuovo, o una nuova
versione di uno già pubblicato (VERSIONE_DI = il suo id), che resta in bozza finché PUBBLICA non vale «true».
Variabili: ZENODO_TOKEN (un token personale con i permessi deposit:write e deposit:actions), BASE (https://zenodo.org,
o https://sandbox.zenodo.org per le prove), PUBBLICA, VERSIONE_DI. Solo libreria standard.

    python3 scripts/deposito_zenodo.py stirps-dati-AAAA-MM-GG.zip
"""
import datetime, json, os, sys, urllib.request

BASE = os.environ.get('BASE', 'https://sandbox.zenodo.org').rstrip('/')
TOKEN = os.environ.get('ZENODO_TOKEN', '')


def chiama(metodo, url, dati=None, grezzi=None, tipo='application/json'):
    corpo = grezzi if grezzi is not None else (json.dumps(dati).encode() if dati is not None else None)
    r = urllib.request.Request(url, data=corpo, method=metodo,
                               headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': tipo})
    with urllib.request.urlopen(r, timeout=600) as risposta:
        testo = risposta.read()
    return json.loads(testo) if testo else {}


def main():
    if not TOKEN:
        print('::error title=Zenodo::manca il segreto del token (ZENODO_TOKEN, o ZENODO_SANDBOX_TOKEN per la sandbox)')
        sys.exit(1)
    percorso = sys.argv[1]
    api = f'{BASE}/api/deposit/depositions'
    if os.environ.get('VERSIONE_DI'):
        r = chiama('POST', f"{api}/{os.environ['VERSIONE_DI']}/actions/newversion")
        bozza = chiama('GET', r['links']['latest_draft'])
        for f in bozza.get('files', []):                 # la nuova versione parte con i file della vecchia
            chiama('DELETE', f['links']['self'])
    else:
        bozza = chiama('POST', api, {})
    nome = os.path.basename(percorso)
    with open(percorso, 'rb') as f:
        chiama('PUT', f"{bozza['links']['bucket']}/{nome}", grezzi=f.read(), tipo='application/octet-stream')
    meta = json.load(open('.zenodo.json', encoding='utf-8'))
    oggi = datetime.date.today().isoformat()
    meta.update({'version': oggi, 'publication_date': oggi})
    chiama('PUT', f"{api}/{bozza['id']}", {'metadata': meta})
    if os.environ.get('PUBBLICA') == 'true':
        r = chiama('POST', f"{api}/{bozza['id']}/actions/publish")
        print(f"::notice title=Zenodo::pubblicato, DOI {r.get('doi')} ({r['links'].get('html')})")
    else:
        print(f"::notice title=Zenodo::bozza {bozza['id']} pronta da controllare: {bozza['links'].get('html')}")


if __name__ == '__main__':
    main()
