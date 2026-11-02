#!/usr/bin/env bash
# Collaudo dell'importatore su import/esempio/: voci reali italiane, latine, del francese antico e del greco antico.
# Latino e greco entrano interi (--intere): anche le voci che nessuna catena italiana raggiunge. In più alcuni lemmi
# dei dizionari del Perseus (esempio/dizionari.tsv, l'uscita di filtra_perseus.py).
# Richiede un database con 01–03 e 05 caricati: DATABASE_URL=… ./collauda.sh
set -euo pipefail
cd "$(dirname "$0")"
rm -rf esempio/tsv
# le etimologie scritte solo nel testo: la prima menzione diventa un der («From the verb {{m|it|segare}}»)
python3 - <<'PY'
from filtra import menzione_come_der as f
v = {'lang_code': 'it', 'etymology_text': 'From the verb segare.', 'etymology_templates': [{'name': 'm', 'args': {'1': 'it', '2': 'segare'}, 'expansion': 'segare'}]}
assert f(v) == [{'n': 'der', 'a': {'1': 'it', '2': 'it', '3': 'segare'}, 'e': 'segare'}], f(v)
assert f({**v, 'etymology_text': 'Compare segare.'}) == [], 'solo i testi che cominciano con From'
assert f({**v, 'etymology_templates': v['etymology_templates'] + [{'name': 'inh', 'args': {}}]}) == [], 'solo senza modelli etimologici'
d = {'lang_code': 'it', 'etymology_text': 'From dividere, influenced by French devise.', 'etymology_templates': [{'name': 'm', 'args': {'1': 'fr', '2': 'devise'}, 'expansion': 'devise'}]}
assert f(d) == [], 'una menzione fuori dalla prima frase (un\'influenza) non è l\'etimo'
c = {'lang_code': 'it', 'etymology_text': 'From pesce + cane.', 'etymology_templates': [{'name': 'm', 'args': {'1': 'it', '2': 'pesce'}, 'expansion': 'pesce'}]}
assert f(c) == [], 'un composto non è una derivazione dalla prima parte'
# le forme flesse non sono voci: anche quando Wiktionary non marca il senso, la glossa lo dice
from filtra import forma_flessa as ff
s = lambda *g: {'senses': [{'glosses': [x]} for x in g]}
assert ff(s('second-person plural present passive indicative/imperative of contemperō')), 'forma dalla glossa'
assert ff({'senses': [{'glosses': ['genitive singular of nox'], 'form_of': [{'word': 'nox'}]}, {'tags': ['no-gloss']}]}), 'un senso vuoto non salva una forma'
assert not ff(s('perfect passive participle of amō', 'beloved, dear')), 'un senso lessicale e la voce resta'
assert not ff(s('alternative form of riappressare')) and not ff(s('comparative studies')), 'varianti e falsi amici restano'
# {{ety}}/{{etymon}}, il sistema nuovo di Wiktionary, diventa il modello classico equivalente
from filtra import da_ety
assert da_ety({'args': {'1': 'la', '2': ':af', '3': 'audiēns', '4': '-ia'}}, 'la')['args'] == {'1': 'la', '2': 'audiēns', '3': '-ia'}
assert da_ety({'args': {'1': 'it', '2': ':inh', '3': 'la:aquila'}}, 'it')['name'] == 'inh'
assert da_ety({'args': {'1': 'la', '2': ':bor', '3': 'grc:Α', '4': ':influence', '5': 'ett:𐌀'}}, 'la')['args']['3'] == 'Α', ':influence non è un etimo'
assert da_ety({'args': {'1': 'it', '2': ':influence', '3': 'fr:x'}}, 'it') is None
from filtra import lemma_della_forma as lf
assert lf(s('second-person plural present passive indicative/imperative of contemperō')) == ('contemperō', ['second-person', 'plural', 'present', 'passive', 'indicative', 'imperative'])
assert lf({'senses': [{'glosses': ['g'], 'form_of': [{'word': 'nox'}], 'tags': ['genitive']}]}) == ('nox', ['genitive'])
assert lf(s('genitive singular uncontracted of ζεῦγος (zeûgos)'))[0] == 'ζεῦγος'
# le catene non si rovesciano: una radice non ha etimi automatici, una parola non deriva da una lingua figlia
from wiktionary import Importatore
def arco(imp, esito, etimo, h=None):
    h = h or esito + '#wikt'
    imp.ipotesi[h] = {'chiave': h, 'esito': esito, 'etichetta': 'Wiktionary', 'stato': 'accolta', 'confidenza': 3, 'origine': 'etimo', 'nota': None}
    imp.relazioni.append({'chiave': h + '#0', 'ipotesi': h, 'etimo': etimo, 'esito': esito, 'tipo': 'generico', 'ordine': 1, 'affisso': None, 'conf': 3, 'forma': None})
ha = lambda imp, k: any(h['esito'] == k for h in imp.ipotesi.values())
imp = Importatore()
steh, stn = imp.lessema('ine-pro', '*steh₂-'), imp.lessema('ine-pro', '*stnéh₂ti')
kais, caes = imp.lessema('gem-pro', '*kaisaraz'), imp.lessema('la', 'Caesar')
imp.intermedi[steh][(stn, 'generico', 3, None)] += 1
imp.intermedi[kais][(caes, 'prestito', 3, None)] += 1
imp.risolvi_intermedi()
assert not ha(imp, steh), '*steh₂- non deriva dal suo derivato *stnéh₂ti'
tema, meh = imp.lessema('ine-pro', '*meh₂-tu-'), imp.lessema('ine-pro', '*meh₂-')
arco(imp, tema, meh)
imp.togli_archi_impossibili()
assert ha(imp, tema), 'un tema (*meh₂-tu-) deriva dalla sua radice (*meh₂-)'
assert ha(imp, kais), '*kaisaraz < Caesar resta: un prestito dal latino al germanico è possibile'
boln, palla = imp.lessema('ine-pro', '*bʰolnós'), imp.lessema('lng', '*palla')
laudo, lodare = imp.lessema('la', 'laudo'), imp.lessema('it', 'lodare')
arco(imp, boln, palla); arco(imp, laudo, lodare)
imp.togli_archi_impossibili()
assert not ha(imp, boln) and not ha(imp, laudo), 'nessuna parola deriva da una lingua figlia della sua'
# carne: dal nodo generico *(s)ker- alla radice dichiarata *(s)ker-@cut, se tutte le parole sotto concordano
imp = Importatore()
carne, caro, karo = imp.lessema('it', 'carne'), imp.lessema('la', 'caro'), imp.lessema('itc-pro', '*karō')
gen, cut, turn = imp.lessema('ine-pro', '*(s)ker-'), imp.lessema('ine-pro', '*(s)ker-', ident='cut'), imp.lessema('ine-pro', '*(s)ker-', ident='turn')
corte, cors = imp.lessema('it', 'cortina'), imp.lessema('itc-pro', '*korts')
arco(imp, carne, caro); arco(imp, caro, karo); arco(imp, karo, gen); arco(imp, corte, cors); arco(imp, cors, gen)
imp.radici = {(carne, cut), (corte, turn), (corte, cut)}
imp.precisa_omografe()
etimo = {r['esito']: r['etimo'] for r in imp.relazioni}
assert etimo[karo] == cut, '*karō punta a *(s)ker- «tagliare»'
assert etimo[cors] == gen, 'con dichiarazioni discordi l\'arco resta sul nodo generico'
# audientia: il ripiego sulla radice dichiarata non sceglie a caso tra due radici
imp = Importatore()
aud, audience = imp.lessema('la', 'audientia'), imp.lessema('it', 'audience')
h2ew, dheh1 = imp.lessema('ine-pro', '*h₂ew-', ident='perceive'), imp.lessema('ine-pro', '*dʰeh₁-')
arco(imp, audience, aud)
imp.radici = {(audience, h2ew), (audience, dheh1)}
imp.chiudi_su_radici()
assert not ha(imp, aud), 'due radici dichiarate alla pari: nessun legame'
PY
LINGUA=it python3 wiktionary.py esempio/lemmi.jsonl esempio/tsv esempio/glosse.tsv \
  --chiudi la=esempio/la_lemmi.jsonl,esempio/la_glosse.tsv,esempio/la_forme.tsv \
  --chiudi fro=esempio/fro_lemmi.jsonl,esempio/fro_glosse.tsv,esempio/fro_forme.tsv \
  --chiudi grc=esempio/grc_lemmi.jsonl,esempio/grc_glosse.tsv,esempio/grc_forme.tsv --passi 5 --intere la,grc > /dev/null
cd esempio/tsv
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
truncate stg_lingua, stg_lessema, stg_ipotesi, stg_relazione, stg_doppione, stg_radice, stg_attestazione, stg_wikizionario,
         stg_glossa_wikidata, stg_glossa_tradotta, stg_dizionario, stg_autore, stg_stima, stg_definizione;
\copy stg_lingua from 'lingue.tsv'
\copy stg_lessema from 'lessemi.tsv'
\copy stg_ipotesi from 'ipotesi.tsv'
\copy stg_relazione from 'relazioni.tsv'
\copy stg_doppione from 'doppioni.tsv'
\copy stg_radice from 'radici.tsv'
\copy stg_attestazione from 'attestazioni.tsv'
\copy stg_wikizionario from '../glosse_it.tsv'
\copy stg_glossa_wikidata from '../glosse_wikidata.tsv'
\copy stg_glossa_tradotta from '../glosse_tradotte.tsv'
\copy stg_dizionario from '../dizionari.tsv'
\copy stg_autore from '../autori.tsv'
\copy stg_stima from '../stime.tsv'
select importa_wiktionary();
select importa_dizionari();
select importa_stime();
select importa_glosse_wikizionario();
select importa_glosse_aggiuntive();
select importa_definizioni();
refresh materialized view mv_allotropi;
refresh materialized view mv_famiglia;
SQL
cd ../..
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "${TEST_SQL:-../db/06_test_import.sql}"
