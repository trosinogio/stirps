#!/usr/bin/env python3
"""Traduzioni e definizioni italiane scritte da Claude, per le voci che hanno solo una glossa inglese o nessuna.
Sono testi automatici: nel dizionario portano il segno ≈ e il nome del modello, finché la redazione non li rivede.

    python3 definisci.py estrai PGURL radici|campione lotto.jsonl.gz
        Da una copia locale del database: le radici della pagina «Radici», ciascuna con i discendenti più vicini e le
        loro glosse (il significato si ancora alla famiglia); oppure un campione di 300 voci di ogni tipo, per
        confrontare i modelli.
    python3 definisci.py esegui lotto.jsonl.gz MODELLO uscita.tsv.gz [--sforzo low|medium|high] [--per-richiesta N]
                                [--registro dati/definizioni.tsv.gz]
        Con la Batch API (metà prezzo): manda le voci che non hanno ancora un risultato (nell'uscita o nel registro,
        per la stessa glossa d'origine), aspetta la fine e scrive: chiave, originale, traduzione, definizione, modello.
        Un batch interrotto si riprende da solo (uscita.tsv.gz.batch). Serve ANTHROPIC_API_KEY.
    python3 definisci.py unisci registro.tsv.gz uscita.tsv.gz…
        Aggiunge i risultati al registro (dati/definizioni.tsv.gz, nel pacchetto): per ogni voce vale l'ultimo.

Una voce senza risposta (il modello non conosce la parola con sicurezza) resta nel registro con i campi vuoti, così
non si paga due volte.
"""
import gzip, json, os, re, subprocess, sys, time

SISTEMA = """Sei un lessicografo italiano. Lavori a Stirps, un dizionario etimologico in rete che per ogni parola mostra la catena degli etimi fino alla radice. Il dizionario contiene parole italiane, latine, greche antiche, forme ricostruite (indoeuropee, protogermaniche, protoitaliche…) e parole di altre lingue. Molte voci hanno solo una glossa inglese, presa da Wiktionary o dai dizionari Lewis & Short (latino) e Liddell–Scott–Jones (greco); alcune non ne hanno nessuna.

Per ogni voce ricevi un numero tra parentesi quadre, la lingua, il lemma (con l’asterisco se è ricostruito), a volte la traslitterazione e la parte del discorso, la glossa inglese e l’eventuale glossa italiana già presente. Una radice ha anche i discendenti più vicini, con le loro glosse.

Per ciascuna voce restituisci:

1. «traduzione»: la glossa italiana breve, come in un dizionario bilingue: uno o più traducenti separati da virgole, i verbi all’infinito, al massimo 80 caratteri. Per una parola italiana, un sinonimo o una definizione di poche parole. Lasciala vuota se la voce ha già una glossa italiana.

2. «definizione»: la definizione italiana, proporzionata alla parola. Per un termine raro e univoco basta una frase; per una parola comune con più accezioni, fino a quattro frasi (al massimo 600 caratteri). Di’ che cosa significa; le accezioni principali, nell’ordine abituale dei dizionari; l’ambito d’uso e il registro quando sono notevoli (poetico, tecnico, tardo, medico…); per i verbi la costruzione (transitivo, intransitivo, il caso retto). Per un nome proprio, chi o che cosa designa. Per una variante o una forma flessa, di quale lemma è variante o forma, e che cosa significa.

Per una radice la definizione è più ampia, fino a sei frasi (al massimo 900 caratteri): il significato ricostruito, con la prudenza dovuta («radice indoeuropea ricostruita con il senso di…»), e le principali linee di significato che i discendenti mostrano. Non elencare i discendenti né le loro forme: la pagina della famiglia li mostra già.

Regole:
- Attieniti al significato documentato: la glossa ricevuta, i discendenti, la lessicografia corrente (per il latino e il greco i dizionari di riferimento, per le ricostruzioni i repertori come il LIV e il Pokorny). Se la glossa manca o non basta e non conosci la parola con sicurezza, lascia vuoti entrambi i campi: una voce vuota è meglio di una voce inventata.
- Non scrivere l’etimologia, le date, gli autori o i passi che attestano la parola: il dizionario li riporta altrove, con le fonti.
- Non cominciare la definizione ripetendo il lemma; niente corsivo, grassetto o markdown.
- Scrivi in un italiano sobrio e preciso; usa l’apostrofo tipografico (’) e, per citare parole o significati, i caporali (« »).
- Le parole straniere citate restano nel loro alfabeto.
- Restituisci un elemento per ogni voce ricevuta, con lo stesso numero."""

SCHEMA = {
    'type': 'object',
    'properties': {'voci': {'type': 'array', 'items': {
        'type': 'object',
        'properties': {'n': {'type': 'integer'}, 'traduzione': {'type': 'string'}, 'definizione': {'type': 'string'}},
        'required': ['n', 'traduzione', 'definizione'], 'additionalProperties': False}}},
    'required': ['voci'], 'additionalProperties': False}

# prezzi per milione di token (ingresso, uscita, lettura della cache), prima dello sconto del 50% della Batch API
PREZZI = {'claude-opus-5-5': (4, 20, 0.20), 'claude-sonnet-5-5': (2, 10, 0.20), 'claude-haiku-5-5': (0.10, 0.50, 0.01)}

DECLARATA = """(r.ricostruito or coalesce(r.pos = 'rad.', false)
       or exists (select 1 from ipotesi h where h.esito_id = r.id and h.stato = 'accolta' and h.origine <> 'etimo'))"""
# la glossa italiana che vale come fonte: non una traduzione automatica
GLOSSA_IT = """coalesce(case when r.glossa_lingua = 'it' then r.glossa end,
       (select g.testo from glossa g where g.lessema_id = r.id and g.lingua = 'it' and g.accezione_id is null
          and g.provenienza not in ('traduzione-automatica', 'claude')))"""
VOCE = """'chiave', r.id_esterno, 'lingua', lg.nome, 'lemma', r.lemma, 'ricostruito', r.ricostruito, 'pos', r.pos,
  'translit', r.translit, 'glossa', case when r.glossa_lingua = 'it' then '' else coalesce(r.glossa, '') end,
  'originale', coalesce(r.glossa, ''), 'glossa_it', """ + GLOSSA_IT + """,
  'attuale', (select g.testo from glossa g where g.lessema_id = r.id and g.lingua = 'it' and g.accezione_id is null
                and g.provenienza = 'traduzione-automatica')"""

SQL_RADICI = """
select json_build_object('tipo', 'radice', """ + VOCE + """,
  'discendenti', coalesce((select json_agg(json_build_object('lingua', d.nome, 'lemma', d.lemma, 'ricostruito', d.ricostruito,
                                                              'glossa', d.glossa) order by d.glossa is null, d.prof, d.ord, d.lemma)
    from (select * from (select distinct on (x.lingua) x.lemma, x.ricostruito, x.glossa, lx.nome, f.profondita as prof,
                                case x.lingua when 'la' then 1 when 'grc' then 2 when 'sa' then 3 when 'it' then 4 else 5 end as ord
                           from mv_famiglia f join lessema x on x.id = f.id join lingua lx on lx.codice = x.lingua
                          where f.capo = r.id and f.pubblico and x.stato_editoriale <> 'superato'
                          order by x.lingua, f.profondita, x.glossa is null, x.id) t
          order by glossa is null, prof, ord limit 10) d), '[]'::json))::text
from (select distinct capo from mv_famiglia where pubblico) c join lessema r on r.id = c.capo join lingua lg on lg.codice = r.lingua
where """ + DECLARATA + """ and r.id_esterno is not null and r.stato_editoriale <> 'superato'
order by r.id_esterno"""

# il campione: voci importate che non sono radici, in proporzioni scelte per vedere tutti i casi difficili
STRATI = [("r.lingua = 'it' and not ha_it", 40), ("r.lingua = 'it' and ha_it", 20),
          ("r.lingua = 'la' and not ha_it and r.glossa is not null", 50), ("r.lingua = 'la' and r.glossa is null and not ha_it", 15),
          ("r.lingua = 'la' and ha_it", 15),
          ("r.lingua = 'grc' and not ha_it and r.glossa is not null", 55), ("r.lingua = 'grc' and r.glossa is null and not ha_it", 20),
          ("r.lingua = 'grc' and ha_it", 15),
          ("r.ricostruito", 30), ("r.lingua not in ('it', 'la', 'grc') and not r.ricostruito", 40)]
SQL_CAMPIONE = """
select setseed(0.42);
create temp table base as
  select r.id, (""" + GLOSSA_IT + """) is not null as ha_it from lessema r
   where r.provenienza in ('wiktionary', 'perseus') and r.stato_editoriale = 'importato' and r.id_esterno is not null
     and not (""" + DECLARATA + """ and exists (select 1 from mv_famiglia f where f.capo = r.id));
""" + '\n'.join(f"""(select json_build_object('tipo', 'voce', 'strato', {i}, """ + VOCE + f""")::text
   from base b join lessema r on r.id = b.id join lingua lg on lg.codice = r.lingua where {cond} order by random() limit {n})
 union all""" for i, (cond, n) in enumerate(STRATI)).removesuffix(' union all') + ';'


def estrai(pgurl, che, uscita):
    sql = SQL_RADICI if che == 'radici' else SQL_CAMPIONE
    out = subprocess.run(['psql', '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', pgurl], input=sql, capture_output=True,
                         text=True, check=True).stdout
    righe = [r for r in out.splitlines() if r.startswith('{')]
    scrivi_gz(''.join(r + '\n' for r in righe).encode('utf-8'), uscita)
    print(f'{che}: {len(righe)} voci', file=sys.stderr)


def riga(v, n):
    """La voce come la legge il modello."""
    lemma = ('*' if v['ricostruito'] else '') + v['lemma']
    testa = ' · '.join(x for x in (v['lingua'], lemma, v.get('translit') or '', (v.get('pos') or '').replace('rad.', ''),
                                   'radice' if v['tipo'] == 'radice' else '') if x)
    parti = [f'[{n}] {testa}', f"glossa inglese: {v['glossa'] or '—'}"]
    if v.get('glossa_it'):
        parti.append(f"glossa italiana: {v['glossa_it']}")
    if v.get('discendenti'):
        parti.append('discendenti: ' + '; '.join(
            f"{d['lingua']} {'*' if d['ricostruito'] else ''}{d['lemma']}" + (f" «{d['glossa']}»" if d.get('glossa') else '')
            for d in v['discendenti']))
    return '\n'.join(parti)


def leggi_tsv(percorso):
    """chiave → (originale, traduzione, definizione, modello), dal formato testo di COPY."""
    if not os.path.exists(percorso):
        return {}
    apri = gzip.open if percorso.endswith('.gz') else open
    sv = lambda x: x.replace('\\t', '\t').replace('\\n', '\n').replace('\\\\', '\\')
    with apri(percorso, 'rt', encoding='utf-8') as f:
        return {c[0]: tuple(sv(x) for x in c[1:5]) for c in (r.rstrip('\n').split('\t') for r in f) if len(c) >= 5}


def campo(x):
    return ' '.join(x.split()).replace('\\', '\\\\')


def pulisci(t):
    t = ' '.join((t or '').split())
    t = re.sub(r"(?<=\w)'(?=\w)", '’', t)                        # apostrofo tipografico
    t = re.sub(r'"([^"]+)"', r'«\1»', t)                           # virgolette diritte → caporali
    t = re.sub(r'[*_]{1,2}([^*_]+)[*_]{1,2}', r'\1', t)            # niente markdown
    return t.strip()


def esegui(lotto, modello, uscita, sforzo='medium', per_richiesta=None, registro=None, attesa=5 * 3600):
    import anthropic
    from anthropic.types.message_create_params import MessageCreateParamsNonStreaming
    from anthropic.types.messages.batch_create_params import Request
    voci = [json.loads(r) for r in gzip.open(lotto, 'rt', encoding='utf-8')]
    per_chiave = {v['chiave']: v for v in voci}
    client = anthropic.Anthropic()
    # l'id del batch e le chiavi di ogni richiesta, scritti appena mandato: se l'esecuzione s'interrompe, la prossima
    # riprende quel batch con quelle chiavi (non ricalcola i gruppi, che nel frattempo potrebbero essere cambiati)
    segno = uscita + '.batch'
    if os.path.exists(segno):
        stato = json.load(open(segno, encoding='utf-8'))
        batch_id, gruppi = stato['batch'], [[per_chiave[c] for c in g] for g in stato['gruppi']]
        print(f'riprendo il batch {batch_id}', file=sys.stderr)
    else:
        fatte = {**leggi_tsv(registro or ''), **leggi_tsv(uscita)}
        da_fare = [v for v in voci if not (v['chiave'] in fatte and fatte[v['chiave']][0] == v['originale'])]
        print(f'{lotto}: {len(voci)} voci, {len(voci) - len(da_fare)} già fatte', file=sys.stderr)
        if not da_fare:
            return
        # a gruppi della stessa lingua e dello stesso tipo
        da_fare.sort(key=lambda v: (v['tipo'], v['lingua'], v['chiave']))
        k = per_richiesta or (8 if da_fare[0]['tipo'] == 'radice' else 20)
        gruppi, cur = [], []
        for v in da_fare:
            if cur and (len(cur) == k or cur[0]['lingua'] != v['lingua'] or cur[0]['tipo'] != v['tipo']):
                gruppi.append(cur); cur = []
            cur.append(v)
        gruppi.append(cur)
        richieste = [Request(custom_id=f'g{i:05d}', params=MessageCreateParamsNonStreaming(
            model=modello, max_tokens=32000,
            system=[{'type': 'text', 'text': SISTEMA, 'cache_control': {'type': 'ephemeral', 'ttl': '1h'}}],
            messages=[{'role': 'user', 'content': '\n\n'.join(riga(v, n) for n, v in enumerate(g, 1))}],
            output_config={'effort': sforzo, 'format': {'type': 'json_schema', 'schema': SCHEMA}}))
            for i, g in enumerate(gruppi)]
        batch_id = client.messages.batches.create(requests=richieste).id
        with open(segno, 'w', encoding='utf-8') as f:
            json.dump({'batch': batch_id, 'modello': modello, 'gruppi': [[v['chiave'] for v in g] for g in gruppi]}, f)
    print(f'::notice title=Batch {modello}::{batch_id}: {len(gruppi)} richieste, {sum(map(len, gruppi))} voci', flush=True)
    inizio = time.time()
    while (b := client.messages.batches.retrieve(batch_id)).processing_status != 'ended':
        if time.time() - inizio > attesa:
            sys.exit(f'il batch {batch_id} non è finito: la prossima esecuzione lo riprende ({segno})')
        time.sleep(60)
    uso = {'input': 0, 'cache_w': 0, 'cache_r': 0, 'output': 0}
    esiti = {'ok': 0, 'vuote': 0, 'senza_risposta': 0, 'errori': 0}
    motivi = {}                                        # gli errori, per tipo e messaggio
    nuove = {}
    for r in client.messages.batches.results(batch_id):
        g = gruppi[int(r.custom_id[1:])]
        if r.result.type != 'succeeded':
            esiti['errori'] += len(g)
            e = getattr(r.result, 'error', None)
            e = getattr(e, 'error', e)
            motivo = f"{r.result.type}: {getattr(e, 'type', '')} {getattr(e, 'message', '')}"[:300]
            motivi[motivo] = motivi.get(motivo, 0) + 1
            continue
        m = r.result.message
        u = m.usage
        uso['input'] += u.input_tokens; uso['output'] += u.output_tokens
        uso['cache_w'] += u.cache_creation_input_tokens or 0; uso['cache_r'] += u.cache_read_input_tokens or 0
        testo = next((x.text for x in m.content if x.type == 'text'), '')
        try:
            risposte = {x['n']: x for x in json.loads(testo)['voci']} if m.stop_reason == 'end_turn' else {}
        except (ValueError, KeyError):
            risposte = {}
        for n, v in enumerate(g, 1):
            x = risposte.get(n)
            if x is None:
                esiti['senza_risposta'] += 1; continue        # si riprova alla prossima esecuzione
            tr, de = pulisci(x['traduzione'])[:150], pulisci(x['definizione'])[:1500]
            if v.get('glossa_it'):
                tr = ''                                        # c'è già una glossa italiana di rango più alto
            if v['lingua'] == 'italiano' and tr.lower() == v['lemma'].lower():
                tr = ''                                        # per una parola italiana il lemma stesso non è una glossa
            esiti['ok' if de or tr else 'vuote'] += 1
            nuove[v['chiave']] = (v['originale'], tr, de, modello)
    if motivi:
        print(f'::warning title=Errori {modello}::{motivi}', flush=True)
    pi, po, pc = PREZZI.get(modello, (0, 0, 0))
    costo = (uso['input'] * pi + uso['cache_w'] * pi * 2 + uso['cache_r'] * pc + uso['output'] * po) / 1e6 / 2
    print(f'::notice title=Esito {modello}::{esiti}; token {uso}; costo ${costo:.2f} '
          f'(${costo / max(1, sum(esiti.values()) - esiti["errori"]) * 1000:.2f} ogni mille voci)', flush=True)
    scrivi({**leggi_tsv(uscita), **nuove}, uscita)
    if os.path.exists(segno):
        os.remove(segno)


def scrivi_gz(dati, percorso):
    with open(percorso, 'wb') as f:          # come gzip -9 -n: niente nome né data, l'impronta dipende dal contenuto
        with gzip.GzipFile(filename='', mode='wb', compresslevel=9, fileobj=f, mtime=0) as g:
            g.write(dati)


def scrivi(righe, percorso):
    scrivi_gz(''.join('\t'.join([k] + [campo(x) for x in righe[k]]) + '\n' for k in sorted(righe)).encode('utf-8'), percorso)


if __name__ == '__main__':
    a = sys.argv[1:]
    if a[0] == 'estrai':
        estrai(a[1], a[2], a[3])
    elif a[0] == 'esegui':
        opz = {k: a[a.index(f'--{k}') + 1] for k in ('sforzo', 'per-richiesta', 'registro') if f'--{k}' in a}
        esegui(a[1], a[2], a[3], sforzo=opz.get('sforzo', 'medium'), per_richiesta=int(opz['per-richiesta']) if 'per-richiesta' in opz else None,
               registro=opz.get('registro'))
    elif a[0] == 'unisci':
        reg = leggi_tsv(a[1])
        for f in a[2:]:
            reg.update(leggi_tsv(f))
        scrivi(reg, a[1])
        print(f'registro: {len(reg)} voci, {sum(1 for x in reg.values() if x[2])} con definizione', file=sys.stderr)
