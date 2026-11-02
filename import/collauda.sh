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
from filtra import lemma_della_forma as lf
assert lf(s('second-person plural present passive indicative/imperative of contemperō')) == ('contemperō', ['second-person', 'plural', 'present', 'passive', 'indicative', 'imperative'])
assert lf({'senses': [{'glosses': ['g'], 'form_of': [{'word': 'nox'}], 'tags': ['genitive']}]}) == ('nox', ['genitive'])
assert lf(s('genitive singular uncontracted of ζεῦγος (zeûgos)'))[0] == 'ζεῦγος'
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
