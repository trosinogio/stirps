#!/usr/bin/env bash
# Collaudo dell'importatore su import/esempio/: voci reali italiane, latine, del francese antico e del greco antico.
# Latino e greco entrano interi (--intere): anche le voci che nessuna catena italiana raggiunge. In più alcuni lemmi
# dei dizionari del Perseus (esempio/dizionari.tsv, l'uscita di filtra_perseus.py).
# Richiede un database con 01–03 e 05 caricati: DATABASE_URL=… ./collauda.sh
set -euo pipefail
cd "$(dirname "$0")"
rm -rf esempio/tsv
# il ciclo completo del filtro su due voci in stile Kaikki: un lemma con etimologia, pronuncia e accezioni, e una forma
PROVA=$(mktemp -d)
cat > "$PROVA/kaikki.jsonl" <<'JSON'
{"word": "caro", "lang_code": "la", "pos": "noun", "etymology_templates": [{"name": "inh", "args": {"1": "la", "2": "itc-pro", "3": "*karō"}, "expansion": "*karō"}], "etymology_text": "From *karō.", "head_templates": [{"name": "la-noun", "args": {}, "expansion": "carō f (genitive carnis); third declension"}], "sounds": [{"ipa": "/ˈka.roː/", "tags": ["Classical-Latin"]}, {"audio": "a \"b\".ogg"}], "senses": [{"glosses": ["flesh"]}, {"glosses": ["the body"], "tags": ["figuratively"]}]}
{"word": "carnis", "lang_code": "la", "pos": "noun", "senses": [{"glosses": ["genitive singular of carō"], "form_of": [{"word": "carō"}]}]}
JSON
LINGUA=la python3 filtra.py "$PROVA/lemmi.jsonl" "$PROVA/glosse.tsv" < "$PROVA/kaikki.jsonl" 2> /dev/null
python3 - "$PROVA" <<'PY'
import json, sys
d = sys.argv[1]
lemmi = [json.loads(r) for r in open(f'{d}/lemmi.jsonl', encoding='utf-8')]
glosse = [r.rstrip('\n').split('\t') for r in open(f'{d}/glosse.tsv', encoding='utf-8')]
assert [l['w'] for l in lemmi] == ['caro'] and [g[0] for g in glosse] == ['caro'], 'la forma flessa resta fuori'
assert lemmi[0]['pr']['a'] == 'a "b".ogg' and lemmi[0]['se']['t'].startswith('carō f'), lemmi[0]
assert json.loads(glosse[0][6])['i'][0][1] == 'Classical-Latin' and json.loads(glosse[0][7])['s'][1] == ['the body', 'figuratively']
PY
rm -rf "$PROVA"
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
assert da_ety({'args': {'1': 'la', '2': ':af', '3': 'ad<id:to>', '4': 'quiēscō'}}, 'la')['args']['2'] == 'ad-<id:to>', 'il preverbo è un prefisso'
assert da_ety({'args': {'1': 'grc', '2': ':af', '3': 'κατά', '4': 'βαίνω'}}, 'grc')['args']['2'] == 'κατά-'
assert da_ety({'args': {'1': 'la', '2': ':inh', '3': 'itc-pro:<id:x>'}}, 'la') is None, 'un termine vuoto non è un etimo'
from filtra import porta_etimo
assert not porta_etimo({'name': 'suffix', 'args': {'1': 'la', '2': '-ia'}}), '{{suffix|la|-ia}} senza base non dà un etimo: vale {{ety}}'
assert porta_etimo({'name': 'suffix', 'args': {'1': 'la', '2': 'audiēns', '3': 'ia'}}) and porta_etimo({'name': 'inh', 'args': {'1': 'it', '2': 'la', '3': 'aquila'}})
from wiktionary import lemma_valido, senza_albero
# l'albero etimologico appiattito prima del testo di Wiktionary non è testo
assert senza_albero('Etymology tree Latin obstruō Proto-Indo-European *-tis Latin -tiō Latin obstrūctiō From obstruō + -tiō.') == 'From obstruō + -tiō.'
assert senza_albero('Etymology tree Proto-Indo-European *dem- Latin dominus Latin dominiumder') == ''
assert senza_albero('From Latin carō.') == 'From Latin carō.' and senza_albero('') == ''
assert senza_albero('PIE word  *wisós Etymology tree Proto-Indo-European *weys- Latin virus From Proto-Italic *weizos.') == 'From Proto-Italic *weizos.'
t = 'From Old English cyningdōm, from Proto-Germanic *kuningadōmaz. Equivalent to king + -dom. Etymology tree Proto-Indo-European *ǵenh₁- English kingdom'
assert senza_albero(t) == t[:t.index(' Etymology tree')], senza_albero(t)
assert not lemma_valido('itc-pro', '', True) and not lemma_valido('ine-pro', '*', True), 'un lemma vuoto non è una voce'
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
# quintal dichiara la radice araba di qinṭār, che sta a metà della sua catena: centum, in cima, non ci si lega
imp = Importatore()
quintal, qintar, centum = imp.lessema('en', 'quintal'), imp.lessema('ar', 'قنطار'), imp.lessema('la', 'centum')
qntr = imp.lessema('ar', 'ق ن ط ر')
arco(imp, quintal, qintar); arco(imp, qintar, centum)
imp.radici = {(quintal, qntr)}
imp.chiudi_su_radici()
assert not ha(imp, centum), 'la radice di una parola a metà della catena non va in cima'
# una forma ricostruita non deriva dalla radice di una lingua attestata
imp = Importatore()
km, cento, qntr = imp.lessema('ine-pro', '*ḱm̥tóm'), imp.lessema('it', 'cento'), imp.lessema('ar', 'ق ن ط ر')
arco(imp, cento, km)
imp.radici = {(cento, qntr)}
imp.chiudi_su_radici()
assert not ha(imp, km), '*ḱm̥tóm non viene da una radice araba'
# una cima grande non si lega per il voto di una sola parola che le sta sotto (immaterial e *méh₂tēr); una piccola sì,
# e la cima che dichiara da sé la sua radice si lega comunque
imp = Importatore()
mater, h2el = imp.lessema('ine-pro', '*méh₂tēr'), imp.lessema('ine-pro', '*h₂el-')
figli = [imp.lessema('la', f'parola{i}') for i in range(12)]
for f in figli:
    arco(imp, f, mater)
imp.radici = {(figli[0], h2el)}
imp.chiudi_su_radici()
assert not ha(imp, mater), 'una cima con dieci parole sotto non si lega per un voto solo'
imp = Importatore()
olens, olente, h3ed = imp.lessema('la', 'olens'), imp.lessema('it', 'olente'), imp.lessema('ine-pro', '*h₃ed-')
arco(imp, olente, olens)
imp.radici = {(olente, h3ed)}
imp.chiudi_su_radici()
assert ha(imp, olens), 'una cima piccola si lega anche per un voto solo'
imp = Importatore()
mater, h2el = imp.lessema('ine-pro', '*méh₂tēr'), imp.lessema('ine-pro', '*meh₂-')
figli = [imp.lessema('la', f'parola{i}') for i in range(12)]
for f in figli:
    arco(imp, f, mater)
imp.radici = {(mater, h2el)}
imp.chiudi_su_radici()
assert ha(imp, mater), 'una cima che dichiara da sé la sua radice si lega anche se è grande'
# le etimologie del Lewis & Short e dell'LSJ (filtra_perseus.py --etimi): la base, il composto, il prefisso; non le radici
# né i confronti con parole affini
import xml.etree.ElementTree as ET
from filtra_perseus import etimo_ls, etimo_lsj
E = ET.fromstring
assert etimo_ls(E('<etym>anguis</etym>')) == [('la', 'anguis', 'derivazione', None)]
assert etimo_ls(E('<etym>anguis-coma</etym>')) == [('la', 'anguis', 'composizione', None), ('la', 'coma', 'composizione', None)]
assert etimo_ls(E('<etym>ab-dūco</etym>')) == [('la', 'duco', 'derivazione', 'ab-')], 'il prefisso resta un affisso, la catena va alla base'
assert etimo_ls(E('<etym>root ten; v. teneo</etym>')) is None and etimo_ls(E('<etym>Sanscr. tris; cf. tres</etym>')) is None
assert etimo_ls(E('<etym>Gr. <foreign lang="greek">ἄροτρον</foreign></etym>')) is None, 'aratrum e ἄροτρον sono affini, non un prestito'
assert etimo_lsj(E('<etym lang="greek">a)gei/rw</etym>')) == [('grc', 'ἀγείρω', 'derivazione', None)]
assert etimo_lsj(E('<etym lang="greek">gai=a, gh=</etym>'))[0][1:3] == ('γαῖα', 'generico')
assert etimo_lsj(E('<etym lang="greek">kata-</etym>')) is None
# l'analisi della forma: prefisso e base nota, mai un nome proprio come base, ἀ- privativo solo davanti a consonante,
# i prefissi latini assimilati solo davanti alla loro consonante; niente per le voci che hanno già un'etimologia
from analisi_composti import analizza
voci = [('g1', 'grc', 'καταδάπτω', 'v.'), ('g2', 'grc', 'δάπτω', 'v.'), ('g3', 'grc', 'ἐπικάρπιος', None), ('g4', 'grc', 'Κάρπιος', 'np'),
        ('g5', 'grc', 'ἀεργός', None), ('g6', 'grc', 'ἐργός', None), ('g7', 'grc', 'ἐφίστημι', 'v.'), ('g8', 'grc', 'ἵστημι', 'v.'),
        ('l1', 'la', 'transtollo', 'v.'), ('l2', 'la', 'tollo', 'v.'), ('l3', 'la', 'affero', 'v.'), ('l4', 'la', 'fero', 'v.'),
        ('l5', 'la', 'acfero', 'v.'), ('l6', 'la', 'perlego', 'v.'), ('l7', 'la', 'lego', 'v.')]
righe, _ = analizza(voci, {'l6'})
trovate = {r[2]: (r[5], r[7]) for r in righe}
assert trovate.get('καταδάπτω') == ('δάπτω', 'κατα-') and trovate.get('ἐφίστημι') == ('ἵστημι', 'ἐφ-'), trovate
assert trovate.get('transtollo') == ('tollo', 'trans-') and trovate.get('affero') == ('fero', 'ad-'), trovate
assert 'ἐπικάρπιος' not in trovate and 'ἀεργός' not in trovate and 'acfero' not in trovate and 'perlego' not in trovate, trovate
# una radice ricostruita è la base del suo derivato, non un prefisso; un suffisso ricostruito resta un affisso
from wiktionary import e_affisso
assert e_affisso('-ente') and e_affisso('ab-') and e_affisso('*-eti') and not e_affisso('*bʰer-') and not e_affisso('casa')
imp = Importatore()
imp.voce({'w': '*bʰéreti', 'l': 'ine-pro', 'rec': True, 'tpl': [{'n': 'af', 'a': {'1': 'ine-pro', '2': '*bʰer-', '3': '*-eti'}, 'e': ''}]},
         lingua_voce='ine-pro', parola='*bʰéreti')
archi = [(r['etimo'], r['affisso']) for r in imp.relazioni if r['esito'] == imp.lessema('ine-pro', '*bʰéreti')]
assert archi == [(imp.lessema('ine-pro', '*bʰer-'), '*-eti')], archi
# le etimologie scritte solo a parole, senza modelli: la prima frase, se è semplice; mai dubbi, confronti o influssi
from filtra import testo_come_der, surf_come_af
tc = lambda t: [(x['n'], x['a']) for x in testo_come_der({'etymology_text': t, 'lang_code': 'it'})]
assert tc('Deverbal of domandare.') == [('der', {'1': 'it', '2': 'it', '3': 'domandare'})]
assert tc('Past participle of trovare.') == [('der', {'1': 'it', '2': 'it', '3': 'trovare'})]
assert tc('From Latin dominus, from domus.') == [('der', {'1': 'it', '2': 'la', '3': 'dominus'})]
assert tc('From divertire +\u200e -ente.') == [('af', {'1': 'it', '2': 'divertire', '3': '-ente'})]
assert tc('Possibly from Latin X.') == [] and tc('Compare French fou.') == [] and tc('From French papa, a child word.') == []
assert surf_come_af({'etymology_templates': [{'name': 'surf', 'args': {'1': 'it', '2': 'divertire', '3': '-ente'}}]})[0]['n'] == 'af'
from filtra import modello_di_ripiego
mr = lambda n, a: [(x['n'], x['a']) for x in modello_di_ripiego({'etymology_templates': [{'name': n, 'args': a}]})]
assert mr('it-verb-obj', {'1': 'lanciare<t:to launch>', '2': 'razzo<t:rockets><pl:1>'}) == [('af', {'1': 'it', '2': 'lanciare', '3': 'razzo'})]
assert mr('from', {'1': 'it', '2': "l'aquila"}) == [('der', {'1': 'it', '2': 'it', '3': "l'aquila"})]
assert mr('contraction', {'1': 'it', '2': 'ci', '3': 'è'}) == [('af', {'1': 'it', '2': 'ci', '3': 'è'})]
assert mr('contraction', {'1': 'it', '2': "va' a fa' 'n culo"}) == [] and mr('contraction', {'1': 'it', '2': 'non è?'}) == []
assert surf_come_af({'word': 'de', 'etymology_templates': [{'name': 'surf', 'args': {'1': 'it', '2': 'la', '3': 'de'}}]}) == []
import os, tempfile
# una pagina con una radice tra gli omografi (वा: «o» e «soffiare»): l'etimo citato è la radice
cartella_sa = tempfile.mkdtemp()
open(cartella_sa + '/glosse.tsv', 'w').write('वा\t1\tconj\tor\t\nवा\t2\troot\tto blow\t\nदा\t1\troot\tto give\t\n')
imp = Importatore()
imp.carica_chiusura('sa', os.devnull, None, cartella_sa + '/glosse.tsv')
assert imp.risolvi('sa', 'वा', None)[2] == 2 and imp.risolvi('sa', 'दा', None)[2] == 1
# nella lingua di partenza una forma flessa citata va al suo lemma, come forma citata (quattrocchi < occhio, «occhi»)
import os, tempfile
cartella = tempfile.mkdtemp()
open(cartella + '/forme.tsv', 'w').write('occhi\tocchio\tplural\ntrovato\ttrovare\tpast,participle\n')
open(cartella + '/glosse.tsv', 'w').write('occhio\t1\tnoun\teye\t\n')
imp = Importatore()
imp.carica_chiusura('it', os.devnull, cartella + '/forme.tsv', cartella + '/glosse.tsv', base=True)
assert imp.risolvi('it', 'occhi', None)[1::2] == ('occhio', 'occhi'), imp.risolvi('it', 'occhi', None)
imp.voce({'w': 'quattrocchi', 'tpl': [{'n': 'af', 'a': {'1': 'it', '2': 'quattro', '3': 'occhi'}, 'e': ''}]})
archi = {(r['etimo'], r['forma']) for r in imp.relazioni if r['esito'] == imp.lessema('it', 'quattrocchi')}
from wiktionary import chiave
assert (imp.lessema('it', 'occhio'), 'occhi') in archi and chiave('it', 'occhi') not in imp.lessemi, archi
# l'inglese: il suo alfabeto, le sue forme verbali, niente sigle; entrano solo le voci con un'etimologia (--con-etimologia)
assert lemma_valido('en', 'hound') and lemma_valido('ang', 'þing') and lemma_valido('en', 'café') and lemma_valido('en', 'I')
assert not lemma_valido('en', '4x4') and not lemma_valido('en', 'A'), 'cifre e lettere isolate non sono parole'
assert ff(s('simple past tense and past participle of hound')) and ff(s('third-person singular simple present indicative form of hound'))
assert not ff(s('a dog used for hunting')), 'un senso lessicale resta'
# le forme italiane con pronomi attaccati non sono lemmi: dirvela, dandola; il lemma è l'infinito
assert ff(s('compound of the infinitive dire with ve (the conjunctive variant of vi) and la'))
assert lf(s('compound of the infinitive dire with ve (the conjunctive variant of vi) and la'))[0] == 'dire'
assert lf(s('compound of dando, the gerund of dare, with la'))[0] == 'dare'
assert lf(s('compound of fa\', the second-person singular imperative form of fare, with le'))[0] == 'fare'
assert not ff(s('A compound of mercury and another metal.')), 'una definizione che contiene «compound of» resta'
from filtra import non_parola
assert non_parola({'word': 'NASA', 'pos': 'name'}) and non_parola({'word': '&', 'pos': 'symbol'}) and non_parola({'word': 'lol', 'pos': 'abbrev'})
assert not non_parola({'word': 'laser', 'pos': 'noun'}) and not non_parola({'word': 'I', 'pos': 'pron'})
# le lingue si incontrano nello stesso nodo: la menzione con i segni e la voce senza sono la stessa pagina
from wiktionary import nome_pagina as npg
assert npg('ru', 'во́дка') == 'водка' and npg('ru', 'ёж') == 'ёж' and npg('ru', 'йод') == 'йод', 'ё e й sono lettere'
assert npg('ang', 'ċēol') == 'ceol' and npg('ang', 'sæterdæġ') == 'sæterdæg' and npg('enm', 'fōtmāl') == 'fotmal'
assert npg('non', 'háls') == 'háls' and npg('fr', 'dé') == 'dé' and npg('gem-pro', '*berô') == '*berô'
assert lemma_valido('ru', 'водка') and lemma_valido('de', 'Straße') and lemma_valido('fr', 'cœur') and not lemma_valido('ru', 'vodka')
# la parte del discorso dalle glosse: Haus, in tedesco, è un nome comune
from wiktionary import completa_glosse
import os, tempfile
td = tempfile.mkdtemp()
imp = Importatore()
haus = imp.lessema('de', 'Haus')
with open(f'{td}/de_glosse.tsv', 'w') as f:
    f.write('Haus\t1\tnoun\thouse\t\t\n')
completa_glosse(imp, f'{td}/de_glosse.tsv', 'de')
assert imp.lessemi[haus]['pos'] == 's.' and imp.scegli_glossa(imp.lessemi[haus]) == 'house', imp.lessemi[haus]
# un nome tedesco che il dump non ha (Besitzer in Ladenbesitzer) è un nome comune; un nome di due parole resta senza
bes, rd = imp.lessema('de', 'Besitzer'), imp.lessema('de', 'Rudolf Diesel')
imp.nomi_tedeschi()
assert imp.lessemi[bes]['pos'] == 's.' and imp.lessemi[rd]['pos'] is None
# la traslitterazione della voce stessa, per la ricerca: дом → dom
imp.voce({'w': 'дом', 'p': 'noun', 'en': None, 't': '', 'g': ['house'], 'h': [], 'c': None, 'rec': False, 'tpl': [], 'r': 'dom'}, lingua_voce='ru')
assert imp.lessemi[imp.lessema('ru', 'дом')]['translit'] == 'dom'
# la pronuncia: IPA con la varietà, sillabazione, audio; dal lemma con etimologia e dalla settima colonna delle glosse
import json
from filtra import pronuncia
pv = {'sounds': [{'ipa': '/ˈka.roː/', 'tags': ['Classical-Latin']}, {'ipa': '[ˈkaː.ro]', 'tags': ['Ecclesiastical-Latin']},
                 {'audio': 'LL-Q397 (lat)-caro.wav', 'ogg_url': 'https://upload.wikimedia.org/x/LL-Q397_caro.ogg'}, {'rhymes': '-aro'}],
      'hyphenations': [{'parts': ['ca', 'ro']}]}
assert pronuncia(pv) == {'i': [['/ˈka.roː/', 'Classical-Latin'], ['[ˈkaː.ro]', 'Ecclesiastical-Latin']], 's': 'ca‧ro', 'a': 'LL-Q397 (lat)-caro.wav'}, pronuncia(pv)
assert pronuncia({'sounds': [{'rhymes': '-aro'}]}) is None
# i dati della scheda: la riga delle forme e le accezioni con le etichette d'uso, senza i sensi che sono forme
from filtra import dati_scheda as sensi
sv = {'word': 'caro', 'head_templates': [{'expansion': 'carō f (genitive carnis); third declension'}],
      'senses': [{'glosses': ['flesh, meat']}, {'glosses': ['the body'], 'tags': ['figuratively', 'feminine']},
                 {'glosses': ['pulp of fruit'], 'topics': ['botany']}, {'glosses': ['dative of x'], 'form_of': [{'word': 'x'}]}]}
assert sensi(sv) == {'t': 'carō f (genitive carnis); third declension', 's': [['flesh, meat', ''], ['the body', 'figuratively'], ['pulp of fruit', 'botany']]}, sensi(sv)
assert sensi({'word': 'x', 'senses': []}) is None
assert pronuncia({'sounds': [{'ipa': '[ˈkaː.ro]', 'raw_tags': ['Ecclesiastical']}]})['i'] == [['[ˈkaː.ro]', 'Ecclesiastical']]
imp.voce({'w': 'caro', 'p': 'noun', 'en': None, 't': '', 'g': ['flesh'], 'h': [], 'c': None, 'rec': False, 'tpl': [], 'pr': pronuncia(pv)}, lingua_voce='la')
assert imp.lessemi[imp.lessema('la', 'caro')]['pronuncia']['s'] == 'ca‧ro'
with open(f'{td}/de_glosse2.tsv', 'w') as f:
    f.write('Haus\t1\tnoun\thouse\t\t\t' + json.dumps({'i': [['/haʊ̯s/', '']]}, ensure_ascii=False) + '\n')
imp2 = Importatore()
h2 = imp2.lessema('de', 'Haus')
completa_glosse(imp2, f'{td}/de_glosse2.tsv', 'de')
assert imp2.lessemi[h2]['pronuncia'] == {'i': [['/haʊ̯s/', '']]}, imp2.lessemi[h2]
import json, tempfile
d = tempfile.mkdtemp()
with open(f'{d}/en_lemmi.jsonl', 'w') as f:
    f.write(json.dumps({'w': 'hound', 'p': 'noun', 'en': None, 't': 'From Middle English hound.', 'g': ['A dog'], 'h': [], 'c': None,
                        'rec': False, 'tpl': [{'n': 'inh', 'a': {'1': 'en', '2': 'enm', '3': 'hound'}, 'e': 'hound'}]}) + '\n')
with open(f'{d}/en_glosse.tsv', 'w') as f:
    f.write('hound\t1\tnoun\tA dog\t\t\nwoof\t1\tintj\tthe bark of a dog\t\t\n')
for modo, attesi in (('con_etimologia', {'hound'}), ('intere', {'hound', 'woof'})):
    imp = Importatore()
    setattr(imp, modo, {'en'})
    imp.carica_chiusura('en', f'{d}/en_lemmi.jsonl', None, f'{d}/en_glosse.tsv')
    imp.chiudi(1); imp.aggiungi_lemmi_interi()
    lemmi = {l['lemma'] for l in imp.lessemi.values() if l['lingua'] == 'en'}
    assert lemmi == attesi, (modo, lemmi)
# con un elenco (il lessico comune) entrano solo i lemmi dell'elenco, senza nomi propri né locuzioni; le voci raggiunte sì
with open(f'{d}/en_lemmi.jsonl', 'a') as f:
    for w, p in (('Hounslow', 'name'), ('hound dog', 'noun'), ('houndfish', 'noun'), ('dog', 'noun')):
        f.write(json.dumps({'w': w, 'p': p, 'en': None, 't': '', 'g': [], 'h': [], 'c': None, 'rec': False,
                            'tpl': [{'n': 'inh', 'a': {'1': 'en', '2': 'enm', '3': w}, 'e': w}]}) + '\n')
imp = Importatore()
imp.con_etimologia, imp.elenco = {'en'}, {'en': {'hound', 'hounslow', 'hound dog'}}
imp.carica_chiusura('en', f'{d}/en_lemmi.jsonl', None, f'{d}/en_glosse.tsv')
imp.lessema('en', 'dog')
imp.chiudi(2)
lemmi = {l['lemma'] for l in imp.lessemi.values() if l['lingua'] == 'en'}
assert lemmi == {'hound', 'dog'}, lemmi
# con --esterni entrano anche le voci fuori elenco con l'etimo in un'altra lingua (kennel < anglonormanno), non i composti
with open(f'{d}/en_lemmi.jsonl', 'a') as f:
    f.write(json.dumps({'w': 'kennel', 'p': 'noun', 'en': None, 't': '', 'g': [], 'h': [], 'c': None, 'rec': False,
                        'tpl': [{'n': 'bor', 'a': {'1': 'en', '2': 'xno', '3': 'kenil'}, 'e': 'kenil'}]}) + '\n')
    f.write(json.dumps({'w': 'houndlike', 'p': 'adj', 'en': None, 't': '', 'g': [], 'h': [], 'c': None, 'rec': False,
                        'tpl': [{'n': 'suffix', 'a': {'1': 'en', '2': 'hound', '3': 'like'}, 'e': ''}]}) + '\n')
imp = Importatore()
imp.con_etimologia, imp.elenco, imp.esterni = {'en'}, {'en': {'hound'}}, {'en'}
imp.carica_chiusura('en', f'{d}/en_lemmi.jsonl', None, f'{d}/en_glosse.tsv')
imp.chiudi(2)
lemmi = {l['lemma'] for l in imp.lessemi.values() if l['lingua'] == 'en'}
assert lemmi == {'hound', 'dog', 'houndfish', 'kennel'}, lemmi
# la glossa: quella della voce stessa prima delle menzioni (t=bee); senza voce propria, quella già pubblicata
imp = Importatore()
for _ in range(3):
    api = imp.lessema('la', 'apis', glossa='bee')
imp.voce({'w': 'apis', 'p': 'noun', 'en': None, 't': '', 'g': ['bee (insect of the clade Anthophila)'], 'h': [], 'c': None, 'rec': False, 'tpl': []}, lingua_voce='la')
assert imp.scegli_glossa(imp.lessemi[api]) == 'bee (insect of the clade Anthophila)', imp.lessemi[api]
imp.glosse_precedenti = {api: 'bee'}
assert imp.scegli_glossa(imp.lessemi[api]) == 'bee', 'la glossa già pubblicata viene prima di quella della voce'
dr = imp.lessema('ine-pro', '*h₂eǵ-', glossa='to drive', ident='drive')
imp.lessemi[dr]['ident'] = 'drive'
imp.glosse_precedenti = {dr: 'drive'}
assert imp.scegli_glossa(imp.lessemi[dr]) == 'drive', 'l\'identificativo pubblicato di una radice omografa resta'
imp.glosse_precedenti = {}
es = imp.lessema('ine-pro', '*h₁es-', glossa='to be')
imp.lessema('ine-pro', '*h₁es-', glossa='to be'); imp.lessema('ine-pro', '*h₁es-', glossa='to be, exist')
assert imp.scegli_glossa(imp.lessemi[es]) == 'to be', 'senza glossa precedente vince la più citata'
imp.glosse_precedenti = {es: 'to be, exist'}
assert imp.scegli_glossa(imp.lessemi[es]) == 'to be, exist', 'la glossa pubblicata resta, se è ancora tra le candidate'
imp.glosse_precedenti = {es: 'to exist'}
assert imp.scegli_glossa(imp.lessemi[es]) == 'to be', 'una glossa pubblicata che non è più tra le candidate non resta'
# un suffisso scritto senza trattino non è una base: forty < four + -y, non forty < «y»
imp = Importatore()
imp.chiusura['en'] = {'voci': [], 'lemmi': {'-y', 'forty', 'four'}, 'omografi': {}, 'forme': {}, 'participi': {}, 'flesse': {}, 'file_glosse': None}
forty, y, four = imp.lessema('en', 'forty'), imp.lessema('en', 'y'), imp.lessema('en', 'four')
arco(imp, forty, four)
imp.relazioni.append({**imp.relazioni[-1], 'chiave': forty + '#wikt#1', 'etimo': y, 'ordine': 2})
imp.togli_archi_impossibili()
assert [r['etimo'] for r in imp.relazioni if r['esito'] == forty] == [four], imp.relazioni
PY
LINGUA=it python3 wiktionary.py esempio/lemmi.jsonl esempio/tsv esempio/glosse.tsv \
  --chiudi la=esempio/la_lemmi.jsonl,esempio/la_glosse.tsv,esempio/la_forme.tsv \
  --chiudi fro=esempio/fro_lemmi.jsonl,esempio/fro_glosse.tsv,esempio/fro_forme.tsv \
  --chiudi grc=esempio/grc_lemmi.jsonl,esempio/grc_glosse.tsv,esempio/grc_forme.tsv --passi 5 --intere la,grc > /dev/null
cd esempio/tsv
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
truncate stg_lingua, stg_lessema, stg_ipotesi, stg_relazione, stg_doppione, stg_radice, stg_attestazione, stg_wikizionario,
         stg_glossa_wikidata, stg_glossa_tradotta, stg_dizionario, stg_autore, stg_stima, stg_definizione, stg_pronuncia, stg_sensi,
         stg_etimo_dizionario;
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
\copy stg_etimo_dizionario from '../etimi_dizionari.tsv'
\copy stg_pronuncia from 'pronunce.tsv'
\copy stg_sensi from 'sensi.tsv'
select importa_wiktionary();
select importa_dizionari();
select importa_stime();
select importa_etimi_dizionari();
select importa_glosse_wikizionario();
select importa_glosse_aggiuntive();
select importa_definizioni();
select importa_pronunce();
select importa_sensi();
refresh materialized view mv_allotropi;
refresh materialized view mv_famiglia;
SQL
cd ../..
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "${TEST_SQL:-../db/06_test_import.sql}"
