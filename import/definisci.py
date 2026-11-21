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
    python3 definisci.py estrai PGURL aree lotto.jsonl.gz
        Le radici ricostruite in cima a una famiglia, per l'indice delle radici: Claude assegna a ciascuna un'area di
        significato (AREE), e il risultato va nel registro dati/aree_radici.tsv.gz (l'area al posto della traduzione).
    python3 definisci.py estrai PGURL omografi lotto.jsonl.gz
        Le voci con omografi che hanno solo la glossa inglese (il Wikizionario ha una pagina per parola, e la sua glossa
        andava spesso all'omografo sbagliato): Claude traduce la glossa della voce, senza definizione.

    python3 definisci.py estrai PGURL elenco=chiavi.txt lotto.jsonl.gz
        Le voci di un elenco di chiavi (una per riga) con la sola glossa inglese o con una traduzione di OPUS-MT: le voci
        nuove di un import (il 15 novembre 2026, le 9 mila parole entrate dagli alberi dei discendenti).

    python3 definisci.py blocchi lotto.jsonl.gz cartella [--per-blocco 500]
    python3 definisci.py raccogli lotto.jsonl.gz cartella MODELLO uscita.tsv.gz [--registro dati/definizioni.tsv.gz]
        Senza la Batch API: il lotto diviso in blocchi (cartella/blocco_NN.txt, con le istruzioni e le voci numerate),
        che traducono degli agenti di Claude Code, uno per blocco, scrivendo cartella/esito_NN.tsv (numero, tabulazione,
        traduzione). «raccogli» controlla ogni esito (una riga per voce, numeri giusti) e scrive l'uscita nel formato
        del registro; un blocco con difetti ferma tutto, e le voci che il registro ha già non si riscrivono. Vale per
        i lotti di sole glosse (omografi): il 14 novembre 2026, 14.869 voci in 30 blocchi con Haiku 5.5.

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

# Le aree di significato dell'indice delle radici: codice e descrizione per il modello
AREE = [
    ('corpo', 'corpo e salute: parti del corpo, funzioni e stati fisici, malattia, guarigione'),
    ('parentela', 'parentela e persone: famiglia, matrimonio, generazioni, persone, ospite e straniero'),
    ('vita', 'vita e morte: nascere, crescere, vivere, morire, invecchiare'),
    ('sentimenti', 'sentimenti e volontà: amare, temere, desiderare, odiare, gioia, dolore, volere'),
    ('mente', 'percezione e mente: vedere, udire, sentire, conoscere, pensare, ricordare'),
    ('parola', 'parola: dire, chiamare, nominare, gridare, cantare, chiedere'),
    ('movimento', 'movimento: andare, venire, correre, volare, nuotare, portare, cadere, girare, spingere'),
    ('azione', 'fare, prendere, dare: fare, porre, prendere, tenere, dare, tagliare, colpire, rompere, legare'),
    ('stato', 'essere e stare: essere, esistere, stare in piedi, sedere, giacere, restare, abitare'),
    ('natura', 'animali e piante: animali, piante, alberi, frutti, caccia e allevamento'),
    ('elementi', 'terra, acqua, fuoco e cielo: elementi, paesaggio, astri, tempo atmosferico, minerali e metalli'),
    ('luce', 'luce e colori: splendere, bruciare, colori, chiaro e scuro'),
    ('misura', 'numeri e misure: numeri, quantità, grandezza, pieno e vuoto, peso'),
    ('spazio', 'spazio e tempo: direzioni, posizioni, vicino e lontano, prima e dopo, giorno, anno, stagioni'),
    ('casa', 'casa, mestieri e cibo: costruire, tessere, cucire, lavorare il legno e i metalli, attrezzi, coltivare, mangiare, bere, cucinare'),
    ('societa', 'società, guerra e sacro: comandare, legge, scambio, dono, possesso, combattere, armi, religione, culto'),
    ('qualita', 'qualità e forme: buono e cattivo, nuovo e vecchio, forte, debole, acuto, curvo, dritto, caldo, freddo'),
    ('grammatica', 'pronomi e particelle: pronomi, dimostrativi, negazione, preposizioni, congiunzioni'),
]
SISTEMA_AREE = """Sei un linguista storico. Lavori a Stirps, un dizionario etimologico che raccoglie le parole in famiglie, ciascuna discesa da una radice o da una forma ricostruita (indoeuropea, protogermanica, protoslava, protoitalica…). Per l'indice delle radici ogni radice va in un'area di significato, scelta da questo elenco:

""" + '\n'.join(f'- {c}: {d}' for c, d in AREE) + """

Per ogni voce ricevi un numero tra parentesi quadre, la lingua, la forma ricostruita, la glossa e i discendenti più vicini con le loro glosse. Restituisci per ciascuna il codice dell'area che descrive meglio il significato ricostruito della radice (non quello di un singolo discendente). Se la radice ha più significati, scegli quello principale; se il significato non è noto con sicurezza, restituisci un'area vuota. Restituisci un elemento per ogni voce ricevuta, con lo stesso numero."""

SCHEMA_AREE = {
    'type': 'object',
    'properties': {'voci': {'type': 'array', 'items': {
        'type': 'object',
        'properties': {'n': {'type': 'integer'}, 'area': {'type': 'string', 'enum': [c for c, _ in AREE] + ['']}},
        'required': ['n', 'area'], 'additionalProperties': False}}},
    'required': ['voci'], 'additionalProperties': False}

# Le sole glosse (lotto «omografi»): la traduzione della glossa della voce, senza definizione
SISTEMA_GLOSSE = """Sei un lessicografo italiano. Lavori a Stirps, un dizionario etimologico in rete che per ogni parola mostra la catena degli etimi fino alla radice. Il dizionario è in italiano, ma molte voci hanno solo una glossa inglese, presa da Wiktionary: tu la traduci.

Per ogni voce ricevi un numero tra parentesi quadre, la lingua, il lemma (con l’asterisco se è ricostruito), a volte la traslitterazione e la parte del discorso, e la glossa inglese. Ogni voce ha degli omografi: altre voci scritte allo stesso modo, con un’altra origine e un altro significato (in inglese «bank», la riva, e «bank», l’istituto di credito). Conta solo il significato della glossa che ricevi, non quello più comune della parola.

Per ciascuna voce restituisci «traduzione»: la glossa italiana breve, come in un dizionario bilingue. Uno o più traducenti separati da virgole, i verbi all’infinito, al massimo 80 caratteri; se un traducente non c’è, una definizione di poche parole. Per una parola italiana, un sinonimo o una definizione di poche parole, mai il lemma stesso.

Regole:
- Traduci il significato della glossa, non le sue parole una per una: di una glossa lunga rendi il nucleo («A large shallow vat; a cistern, tub, or trough, used by brewers…» → «tino, vasca»).
- Una glossa che rimanda a un’altra parola («alternative form of…», «obsolete spelling of…», «plural of…») si traduce come rimando: «variante di …», «grafia antica di …», «plurale di …», con la parola citata nella sua grafia.
- Se la glossa non basta a capire il significato e non conosci la parola con sicurezza, lascia la traduzione vuota: una voce vuota è meglio di una voce inventata.
- Niente etimologia, date, corsivo, grassetto o markdown; niente punto finale.
- Scrivi in un italiano sobrio e preciso; usa l’apostrofo tipografico (’) e, per citare parole o significati, i caporali (« »). Le parole straniere citate restano nel loro alfabeto.
- Restituisci un elemento per ogni voce ricevuta, con lo stesso numero."""

SCHEMA_GLOSSE = {
    'type': 'object',
    'properties': {'voci': {'type': 'array', 'items': {
        'type': 'object',
        'properties': {'n': {'type': 'integer'}, 'traduzione': {'type': 'string'}},
        'required': ['n', 'traduzione'], 'additionalProperties': False}}},
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


SQL_AREE = SQL_RADICI.replace("json_build_object('tipo', 'radice',", "json_build_object('tipo', 'area',").replace(
    "where " + DECLARATA + " and r.id_esterno", "where r.ricostruito and r.id_esterno")


# Le voci importate con omografi (un'altra voce con la stessa lingua e lo stesso lemma) che hanno una glossa inglese e
# nessuna glossa italiana: lì il Wikizionario non si usa (una pagina per parola), e resta la traduzione della glossa
SQL_OMOGRAFI = """
select json_build_object('tipo', 'glossa', """ + VOCE + """)::text
from lessema r join lingua lg on lg.codice = r.lingua
where r.provenienza in ('wiktionary', 'perseus') and r.stato_editoriale = 'importato' and r.id_esterno is not null
  and r.glossa is not null and coalesce(r.glossa_lingua, '') <> 'it'
  and (select count(*) from lessema o where o.lingua = r.lingua and o.lemma = r.lemma) > 1
  and not exists (select 1 from glossa g where g.lessema_id = r.id and g.lingua = 'it' and g.accezione_id is null)
order by r.id_esterno"""


# Il campo di senso di ogni radice (lotto «campi», registro dati/campi_radici.tsv.gz): le parole chiave inglesi del suo
# significato, con cui il parser controlla che una parola stia nella famiglia giusta (ὄψις «sight» sotto *wekʷ- «speak»
# no, sotto *h₃ekʷ- «eye, see» sì) e sceglie tra due omografi quando la pagina non dice quale
SQL_CAMPI = SQL_RADICI.replace("json_build_object('tipo', 'radice',", "json_build_object('tipo', 'campo',").replace(
    "where " + DECLARATA + " and r.id_esterno", "where r.ricostruito and r.id_esterno")
SISTEMA_CAMPI = """Sei un linguista storico. Lavori a Stirps, un dizionario etimologico che raccoglie le parole in famiglie, ciascuna discesa da una radice o da una forma ricostruita (indoeuropea, protogermanica, protosemitica…). Per ogni radice serve il suo campo di senso: le parole chiave con cui lo strumento controlla che una parola stia nella famiglia giusta. Per esempio *h₃ekʷ- «eye, to see» ha il campo «eye, see, sight, look, view, face, vision, appearance», e *wekʷ- «to speak» il campo «speak, say, voice, word, call, utter».

Per ogni voce ricevi un numero tra parentesi quadre, la lingua, la forma ricostruita, la glossa e i discendenti più vicini con le loro glosse.

Per ciascuna voce restituisci:
- «campo»: da 5 a 10 parole chiave inglesi, minuscole, separate da virgole: il significato ricostruito della radice e i sensi che ne derivano in modo regolare nei discendenti (il nome, il verbo, la qualità). Parole singole e comuni, come quelle delle glosse dei dizionari; niente frasi, niente nomi propri, niente parole che valgono per qualunque radice («thing», «make», «have»).
- «senso»: il significato della radice in italiano, in poche parole («occhio, vedere»).

Regole:
- Il campo descrive la radice, non un singolo discendente: quando i discendenti hanno sensi diversi, lascia fuori dal campo il senso che compare in un solo discendente, lontano da tutti gli altri.
- Una radice con discendenti in un solo ramo, o con un solo discendente, ha comunque il suo campo: il senso di quei discendenti (e della glossa, se c'è) è il senso della radice. Lo stesso per una forma ricostruita senza glossa: il senso viene dai discendenti.
- Se la radice ha due significati distinti nelle fonti (omografe non separate), mettili tutti e due.
- Lascia la voce vuota solo se non c'è nessuna glossa e i discendenti non hanno glosse, sono soltanto nomi propri, o hanno sensi tanto diversi che non se ne ricava uno: un campo vuoto è meglio di un campo inventato.
- Restituisci un elemento per ogni voce ricevuta, con lo stesso numero."""
SCHEMA_CAMPI = {
    'type': 'object',
    'properties': {'voci': {'type': 'array', 'items': {
        'type': 'object',
        'properties': {'n': {'type': 'integer'}, 'campo': {'type': 'string'}, 'senso': {'type': 'string'}},
        'required': ['n', 'campo', 'senso'], 'additionalProperties': False}}},
    'required': ['voci'], 'additionalProperties': False}


# il prompt e lo schema di ogni tipo di voce; gli altri tipi (radice, voce) hanno SISTEMA e SCHEMA
PER_TIPO = {'area': (SISTEMA_AREE, SCHEMA_AREE), 'glossa': (SISTEMA_GLOSSE, SCHEMA_GLOSSE), 'campo': (SISTEMA_CAMPI, SCHEMA_CAMPI)}


# Le voci di un elenco di chiavi (un file, una chiave per riga) che hanno una glossa inglese: le voci nuove di un import,
# perché la traduzione di Claude viene prima di quella automatica di OPUS-MT. Le voci già nel registro non si rifanno.
SQL_ELENCO = """
create temp table elenco_chiavi (chiave text primary key);
\\copy elenco_chiavi from '{file}'
select json_build_object('tipo', 'glossa', """ + VOCE + """)::text
from lessema r join lingua lg on lg.codice = r.lingua join elenco_chiavi k on k.chiave = r.id_esterno
where r.provenienza in ('wiktionary', 'perseus') and r.stato_editoriale = 'importato'
  and r.glossa is not null and coalesce(r.glossa_lingua, '') <> 'it'
  and not exists (select 1 from glossa g where g.lessema_id = r.id and g.lingua = 'it' and g.accezione_id is null
                    and g.provenienza <> 'traduzione-automatica')
order by r.id_esterno"""


def estrai(pgurl, che, uscita):
    if che.startswith('elenco='):
        sql = SQL_ELENCO.replace('{file}', os.path.abspath(che.split('=', 1)[1]))
    else:
        sql = {'radici': SQL_RADICI, 'aree': SQL_AREE, 'campi': SQL_CAMPI, 'omografi': SQL_OMOGRAFI, 'campione': SQL_CAMPIONE}[che]
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
        k = per_richiesta or {'radice': 8, 'area': 40, 'glossa': 40}.get(da_fare[0]['tipo'], 20)
        gruppi, cur = [], []
        for v in da_fare:
            if cur and (len(cur) == k or cur[0]['lingua'] != v['lingua'] or cur[0]['tipo'] != v['tipo']):
                gruppi.append(cur); cur = []
            cur.append(v)
        gruppi.append(cur)
        richieste = [Request(custom_id=f'g{i:05d}', params=MessageCreateParamsNonStreaming(
            model=modello, max_tokens=32000,
            system=[{'type': 'text', 'text': PER_TIPO.get(g[0]['tipo'], (SISTEMA, SCHEMA))[0],
                     'cache_control': {'type': 'ephemeral', 'ttl': '1h'}}],
            messages=[{'role': 'user', 'content': '\n\n'.join(riga(v, n) for n, v in enumerate(g, 1))}],
            output_config={'effort': sforzo, 'format': {'type': 'json_schema',
                                                        'schema': PER_TIPO.get(g[0]['tipo'], (SISTEMA, SCHEMA))[1]}}))
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
            if v['tipo'] == 'area':                           # l'area va al posto della traduzione
                esiti['ok' if x['area'] else 'vuote'] += 1
                nuove[v['chiave']] = (v['originale'], x['area'], '', modello)
                continue
            tr, de = pulisci(x['traduzione'])[:150], pulisci(x.get('definizione', ''))[:1500]
            if v['tipo'] == 'glossa':
                tr = tr.rstrip('.')                            # una glossa non ha il punto finale
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


def blocchi(lotto, cartella, per_blocco=500):
    """Il lotto in blocchi per gli agenti: le istruzioni e le voci numerate in blocco_NN.txt, le chiavi in blocco_NN.json."""
    voci = [json.loads(r) for r in gzip.open(lotto, 'rt', encoding='utf-8')]
    tipi = {v['tipo'] for v in voci}
    assert tipi in ({'glossa'}, {'campo'}), 'i blocchi valgono per i lotti di sole glosse o di soli campi'
    voci.sort(key=lambda v: (v['lingua'], v['chiave']))
    os.makedirs(cartella, exist_ok=True)
    if tipi == {'campo'}:
        istruzioni = SISTEMA_CAMPI.replace(
            'Restituisci un elemento per ogni voce ricevuta, con lo stesso numero.',
            'Scrivi una riga per ogni voce ricevuta, nell’ordine ricevuto: il numero, un carattere di tabulazione, il campo, '
            'un altro carattere di tabulazione e il senso (niente dopo il numero se lasci la voce vuota). Nessuna riga in più, '
            'nessuna intestazione.')
        assert istruzioni != SISTEMA_CAMPI
    else:
        istruzioni = SISTEMA_GLOSSE.replace(
            'Restituisci un elemento per ogni voce ricevuta, con lo stesso numero.',
            'Scrivi una riga per ogni voce ricevuta, nell’ordine ricevuto: il numero, un carattere di tabulazione e la traduzione '
            '(niente dopo la tabulazione se la lasci vuota). Nessuna riga in più, nessuna intestazione.')
        assert istruzioni != SISTEMA_GLOSSE
    for b, i in enumerate(range(0, len(voci), per_blocco), 1):
        gruppo = voci[i:i + per_blocco]
        with open(os.path.join(cartella, f'blocco_{b:02d}.txt'), 'w', encoding='utf-8') as f:
            f.write(istruzioni + f'\n\nLe voci sono {len(gruppo)}, numerate da 1 a {len(gruppo)}:\n\n'
                    + '\n\n'.join(riga(v, n) for n, v in enumerate(gruppo, 1)) + '\n')
        with open(os.path.join(cartella, f'blocco_{b:02d}.json'), 'w', encoding='utf-8') as f:
            json.dump([{'chiave': v['chiave'], 'originale': v['originale'], 'lingua': v['lingua'], 'lemma': v['lemma'],
                        'tipo': v['tipo']} for v in gruppo], f, ensure_ascii=False)
    print(f'{lotto}: {len(voci)} voci in {b} blocchi da {per_blocco}', file=sys.stderr)


def raccogli(cartella, modello, uscita, registro=None):
    """Gli esiti degli agenti nel formato del registro, dopo il controllo: una riga per voce, numeri da 1 a N."""
    fatte = leggi_tsv(registro or '')
    nuove, conti, difetti = {}, {'tradotte': 0, 'vuote': 0, 'già nel registro': 0, 'uguali al lemma': 0}, []
    for nome in sorted(f for f in os.listdir(cartella) if re.fullmatch(r'blocco_\d+\.json', f)):
        voci = json.load(open(os.path.join(cartella, nome), encoding='utf-8'))
        esito = os.path.join(cartella, nome.replace('blocco_', 'esito_').replace('.json', '.tsv'))
        if not os.path.exists(esito):
            difetti.append(f'{nome}: manca l\'esito')
            continue
        tr = {}
        for r in open(esito, encoding='utf-8'):
            m = re.match(r'^(\d+)(?:\t(.*))?$', r.rstrip('\n'), re.S)
            if not m:
                if r.strip():
                    difetti.append(f'{nome}: riga non letta «{r.strip()[:40]}»')
                continue
            if int(m.group(1)) in tr:
                difetti.append(f'{nome}: il numero {m.group(1)} c\'è due volte')
            tr[int(m.group(1))] = (m.group(2) or '').strip()
        if sorted(tr) != list(range(1, len(voci) + 1)):
            difetti.append(f'{nome}: {len(tr)} righe per {len(voci)} voci')
            continue
        for n, v in enumerate(voci, 1):
            if v['chiave'] in fatte:
                conti['già nel registro'] += 1          # una definizione o una traduzione che c'è già non si riscrive
                continue
            if v.get('tipo') == 'campo':
                # «eye, see, sight, look\tocchio, vedere»: il campo va nella traduzione, il senso nella definizione
                kw, _, senso = tr[n].partition('\t')
                kw = ', '.join(x.strip().lower() for x in pulisci(kw).split(',') if x.strip())[:200]
                conti['tradotte' if kw else 'vuote'] += 1
                nuove[v['chiave']] = (v['originale'], kw, pulisci(senso)[:80].rstrip('.') if kw else '', modello)
                continue
            t = pulisci(tr[n])[:150].rstrip('.')
            if v['lingua'] == 'italiano' and t.lower() == v['lemma'].lower():
                t = ''
                conti['uguali al lemma'] += 1
            conti['tradotte' if t else 'vuote'] += 1
            nuove[v['chiave']] = (v['originale'], t, '', modello)
    if difetti:
        sys.exit('esiti con difetti, niente scritto:\n  ' + '\n  '.join(difetti))
    scrivi(nuove, uscita)
    print(f'{uscita}: {len(nuove)} voci, {conti}', file=sys.stderr)


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
    elif a[0] == 'blocchi':
        blocchi(a[1], a[2], int(a[a.index('--per-blocco') + 1]) if '--per-blocco' in a else 500)
    elif a[0] == 'raccogli':
        raccogli(a[2], a[3], a[4], a[a.index('--registro') + 1] if '--registro' in a else None)
    elif a[0] == 'unisci':
        reg = leggi_tsv(a[1])
        for f in a[2:]:
            reg.update(leggi_tsv(f))
        scrivi(reg, a[1])
        print(f'registro: {len(reg)} voci, {sum(1 for x in reg.values() if x[2])} con definizione', file=sys.stderr)
