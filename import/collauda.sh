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
# la sintassi ad albero di {{ety}}/{{etymon}}: i termini portano la loro etimologia annidata (φωνή, μύω, κριτής, φίλος
# erano cime senza etimologia: l'etimo diventava «<ety:der<ine-pro:*bʰeh₂->>», e il suffisso -τής una parola)
from filtra import radici_ety
fone = {'args': {'1': 'grc', '2': ':inh', '3': 'grk-pro:<alt:*pʰōnā́><ety:der<ine-pro:*bʰeh₂-<id:speak>>>', 'id': 'sound'}}
assert da_ety(fone, 'grc')['args'] == {'1': 'grc', '2': 'grk-pro', '3': '*pʰōnā́'}, da_ety(fone, 'grc')
assert radici_ety(fone, 'grc') == [('ine-pro', '*bʰeh₂-', 'speak')], 'la radice dichiarata nell\'albero, con il suo identificativo'
assert da_ety({'args': {'1': 'grc', '2': ':af', '3': '<alt:κρῐ-><ety:from<κρῑ́νω>>', '4': '-τής'}}, 'grc')['args'] == {'1': 'grc', '2': 'κρῑ́νω', '3': '-τής'}, 'il tema κρῐ- non è una voce: vale κρίνω'
myo = {'args': {'1': 'grc', '2': ':der', '3': 'ine-pro:<alt:*mewH-ye-><ety:from<*mewH->>'}}
assert da_ety(myo, 'grc')['args']['3'] == '*mewH-ye-' and radici_ety(myo, 'grc') == [('ine-pro', '*mewH-', None)], 'il tema *mewH-ye- non è una radice'
filos = {'args': {'1': 'grc', '2': ':inh', '3': 'ine-pro:<alt:*bʰil-o-s><ety:af<*bʰil-><*-os<id:athematic>>>', 'id': 'dear'}}
assert da_ety(filos, 'grc')['args']['3'] == '*bʰil-o-s' and radici_ety(filos, 'grc') == [('ine-pro', '*bʰil-', None)], 'il suffisso *-os non è una radice'
assert radici_ety({'args': {'1': 'it', '2': ':influence', '3': 'ine-pro:*bʰer-'}}, 'it') == [], ':influence non dichiara una radice'
sema = {'args': {'1': 'grc', '2': ':inh<unc:1>', '3': 'grk-pro:<alt:*tsā́mə><ety:inh<ine-pro:<alt:*dʰyéh₂mn̥><ety:af<ine-pro:<alt:*dʰyeh₂-><ety:from<*dʰeyh₂-<pos:root><unc:1>>>><*-mn̥>>>>', '4': ':afeq', '5': '-μα'}}
assert radici_ety(sema, 'grc') == [], 'un\'etimologia incerta (σῆμα) non dichiara una radice'
assert da_ety(sema, 'grc')['args'] == {'1': 'grc', '2': 'grk-pro', '3': '*tsā́mə'}, da_ety(sema, 'grc')
variante = {'args': {'1': 'grc', '2': ':inh', '3': 'ine-pro:<alt:*dʰyéh₂mn̥><ety:af<ine-pro:<alt:*dʰyeh₂-><ety:from<*dʰeyh₂->>><*-mn̥>>'}}
assert radici_ety(variante, 'grc') == [('ine-pro', '*dʰeyh₂-', None)], 'la radice è la più profonda: *dʰyeh₂- viene da *dʰeyh₂-'
assert da_ety({'args': {'1': 'grc', '2': ':from<text:from earlier>', '3': 'ζώῐ̈ον<ety:af<ζώς<ety:from<ζωός><-ῐον>>'}}, 'grc')['args']['3'] == 'ζώῐ̈ον', 'parentesi non chiuse nel dump: resta il termine'
assert da_ety({'args': {'1': 'la', '2': ':af', '3': 'fābula<id:discourse>', '4': '-lus<alt:-la>'}}, 'la')['args'] == {'1': 'la', '2': 'fābula<id:discourse>', '3': '-lus<alt:-la>'}, 'il caso semplice non cambia'
assert porta_etimo({'name': 'inh', 'args': {'1': 'grc', '2': 'grk-pro', '3': '', '4': '*pʰōnā́'}}), 'una forma ricostruita senza pagina è un etimo'
# le varianti senza etimologia: ὄνυμα e προτί (96 parole sotto) erano cime, staccate da ὄνομα e da πρός
from filtra import variante_di
onyma = {'word': 'ὄνυμα', 'lang_code': 'grc', 'senses': [{'glosses': ['Lyric, Aeolic, and Laconian form of ὄνομᾰ (ónomă)']}]}
assert variante_di(onyma) == [{'n': 'variante', 'a': {'1': 'grc', '2': 'ὄνομᾰ'}, 'e': ''}], variante_di(onyma)
assert variante_di({'word': 'προτί', 'lang_code': 'grc', 'senses': [{'glosses': ['Epic form of πρός (prós)']}]})[0]['a']['2'] == 'πρός'
assert variante_di({'word': 'caussa', 'lang_code': 'la', 'senses': [{'glosses': ['x'], 'alt_of': [{'word': 'causa'}]}]})[0]['a']['2'] == 'causa', 'alt_of di Kaikki'
assert variante_di({'word': 'color', 'lang_code': 'en', 'senses': [{'glosses': ['x'], 'alt_of': [{'word': 'colour'}]}]}) == [], 'solo nelle lingue che entrano intere'
assert variante_di({'word': 'x', 'lang_code': 'grc', 'senses': [{'glosses': ['Epic form of πρός']}, {'glosses': ['Doric form of ποτί']}]}) == [], 'due parole diverse: nessuna variante'
assert variante_di({'word': 'x', 'lang_code': 'grc', 'senses': [{'glosses': ['Epic form of πρός']}, {'glosses': ['a river']}]}) == [], 'un senso proprio: non è solo una variante'
assert variante_di({'word': 'amamus', 'lang_code': 'la', 'senses': [{'glosses': ['first-person plural of amo'], 'form_of': [{'word': 'amo'}]}]}) == [], 'una forma flessa non è una variante'
assert not porta_etimo({'name': 'suffix', 'args': {'1': 'grc', '2': '', '3': 'τής'}}), '{{suffix|grc||τής}} non ha una base'
assert not porta_etimo({'name': 'der', 'args': {'1': 'grc', '2': 'qsb-grc', '3': '-'}}), 'il sostrato senza parola non è un etimo'
# più forme in <alt:>: la prima; una frase al posto del termine non è un etimo
from filtra import termine_ety, base_dalla_menzione, prima_forma
assert termine_ety('itc-ala:<alt:*iowos, *iowez->', 'la')[:2] == ('itc-ala', '*iowos') and termine_ety('ine-pro:<alt:*h₂ér-ti-s ~ *h₂r̥-téy-s>', 'x')[1] == '*h₂ér-ti-s'
assert prima_forma('*kérp-t ` *kr̥p-énti') == '*kérp-t', 'due forme separate dall’accento grave'
assert da_ety({'args': {'1': 'la', '2': ':from', '3': 'trivius and trivium'}}, 'la') is None, 'una frase non è un etimo'
# «lie + -ing» scritto {{m|en|lie}} {{suffix|en||ing}}: la base è la menzione che precede
lying = {'etymology_templates': [{'name': 'm', 'args': {'1': 'en', '2': 'lie', '4': 'to rest'}}, {'name': 'suffix', 'args': {'1': 'en', '2': '', '3': 'ing'}}]}
assert base_dalla_menzione(lying, 'en')['args'] == {'1': 'en', '2': 'lie', '3': '-ing'}
prec = {'etymology_templates': [{'name': 'm', 'args': {'1': 'it', '2': 'precoce'}}, {'name': 'm', 'args': {'1': 'it', '2': '-izzare'}}, {'name': 'suf', 'args': {'1': 'it', '2': '', '3': 'ante'}}]}
assert base_dalla_menzione(prec, 'it')['args']['2'] == 'precoce', 'un affisso menzionato non è la base'
sed = {'etymology_templates': [{'name': 'der', 'args': {'1': 'en', '2': 'la', '3': '', '4': 'sēduct-'}}, {'name': 'm', 'args': {'1': 'la', '2': 'sēdūcere'}}, {'name': 'suffix', 'args': {'1': 'en', '2': '', '3': 'ive'}}]}
assert base_dalla_menzione(sed, 'en')['args'] == {'1': 'en', '2': 'la:sēdūcere', '3': '-ive'}
assert base_dalla_menzione({'etymology_templates': [{'name': 'suffix', 'args': {'1': 'it', '2': '', '3': 'metro'}}]}, 'it') is None, 'senza una menzione il suffisso resta solo'
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
# la glossa con cui una pagina cita il nodo generico porta a una sola omografa: la regola vale solo se, misurata sugli
# archi che le dichiarazioni decidono, concorda abbastanza spesso; una glossa che si lega a due omografe non decide
import wiktionary
def omografe_per_glossa(soglia):
    wiktionary.OMOGRAFE_PER_GLOSSA = soglia
    imp = Importatore()
    gen, cut, turn = imp.lessema('ine-pro', '*(s)ker-'), imp.lessema('ine-pro', '*(s)ker-', ident='cut'), imp.lessema('ine-pro', '*(s)ker-', ident='turn')
    imp.lessemi[turn]['glosse']['to turn, bend'] += 1
    curtus, corona, crux = imp.lessema('la', 'curtus'), imp.lessema('la', 'corona'), imp.lessema('la', 'crux')
    arco(imp, curtus, gen); arco(imp, corona, gen); arco(imp, crux, gen)
    imp.glossa_arco = {(curtus, gen): 'to cut off', (corona, gen): 'to bend; to turn', (crux, gen): 'to turn; to cut'}
    imp.radici = {(curtus, cut)}
    imp.precisa_omografe()
    return imp, {r['esito']: r['etimo'] for r in imp.relazioni}, (gen, cut, turn, curtus, corona, crux)
imp, etimo, (gen, cut, turn, curtus, corona, crux) = omografe_per_glossa((50, 0.9))
assert etimo[curtus] == cut and etimo[corona] == gen and etimo[crux] == gen, 'una prova sola non basta: la glossa non sposta archi'
assert (imp.stat['omografe_glossa_concorde'], imp.stat['omografe_glossa_in_attesa'], imp.stat['omografe_glossa_non_decide']) == (1, 1, 1), dict(imp.stat)
imp, etimo, (gen, cut, turn, curtus, corona, crux) = omografe_per_glossa((1, 0.9))
assert etimo[corona] == turn and etimo[crux] == gen, 'misurata, la glossa «to bend; to turn» porta a *(s)ker- «girare»; «to turn; to cut» non decide'
wiktionary.OMOGRAFE_PER_GLOSSA = (50, 0.9)
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
# greco: suffissi regolari e composti di due parole note con -ο-; non i composti con elisione o parole corte
voci = [('s1', 'grc', 'σκοτίζω', 'v.'), ('s2', 'grc', 'σκότος', None), ('s3', 'grc', 'μοσχομάγειρος', None), ('s4', 'grc', 'μόσχος', None),
        ('s5', 'grc', 'μάγειρος', None), ('s6', 'grc', 'ἄκραντος', None), ('s7', 'grc', 'ἄκρος', None), ('s8', 'grc', 'ἄντος', None)]
righe, _ = analizza(voci, set())
per = {}
for r in righe:
    per.setdefault(r[2], []).append((r[5], r[6], r[7]))
assert per.get('σκοτίζω') == [('σκότος', 'derivazione', '-ίζω')], per
assert per.get('μοσχομάγειρος') == [('μόσχος', 'composizione', None), ('μάγειρος', 'composizione', None)], per
assert 'ἄκραντος' not in per, per
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
# composti con due radici: un elemento di composizione che viene da una parola (radio- < radius) è il secondo etimo;
# non un suffisso grammaticale (-mente < mens) né un legame sbagliato (-ulentus < frustum)
imp = Importatore()
radius, mens, frustum = imp.lessema('la', 'radius', pos='s.'), imp.lessema('la', 'mens', pos='s.f.'), imp.lessema('la', 'frustum', pos='s.')
radio_, mente_, ulentus_ = imp.lessema('it', 'radio-'), imp.lessema('it', '-mente'), imp.lessema('la', '-ulentus')
arco(imp, radio_, radius); arco(imp, mente_, mens); arco(imp, ulentus_, frustum)
imp.voce({'w': 'radioattivo', 'tpl': [{'n': 'af', 'a': {'1': 'it', '2': 'radio-', '3': 'attivo'}, 'e': ''}]})
imp.voce({'w': 'velocemente', 'tpl': [{'n': 'af', 'a': {'1': 'it', '2': 'veloce', '3': '-mente'}, 'e': ''}]})
imp.voce({'w': 'vinolentus', 'tpl': [{'n': 'af', 'a': {'1': 'la', '2': 'vinum', '3': '-ulentus'}, 'e': ''}]}, lingua_voce='la', parola='vinolentus')
imp.elementi_di_composizione()
etimi_di = lambda k: {(r['etimo'], r['tipo']) for r in imp.relazioni if r['esito'] == k}
assert (radio_, 'composizione') in etimi_di(imp.lessema('it', 'radioattivo')), etimi_di(imp.lessema('it', 'radioattivo'))
assert not any(e == mente_ for e, _ in etimi_di(imp.lessema('it', 'velocemente')))
assert not any(e == ulentus_ for e, _ in etimi_di(imp.lessema('la', 'vinolentus')))
# le etimologie del Wikizionario: solo frasi semplici, l'etimo nella scrittura della sua lingua, mai una locuzione
from etimi_wikizionario import leggi as lw
assert lw('dal latino avarus, avido', 'avaro') == [(1, 'la', 'avarus', 'generico', 3)]
assert lw('dal latino moderno psychologia', 'psicologia') == [(1, 'la', 'psychologia', 'generico', 3)], 'la varietà non è l\'etimo'
assert lw('dal latino contra passum', 'contrappasso') == [] and lw("dall'inglese hand in cap", 'handicap') == [], 'una locuzione'
assert lw('dal greco anecumène', 'anecumene') == [] and lw('dal greco παλαiός', 'paleo') == [], 'scrittura sbagliata'
assert lw('dal greco ϕωνητικός', 'fonetico') == [(1, 'grc', 'φωνητικός', 'generico', 3)]
assert lw('dal latino tardo, aciarium', 'acciaio') == [], 'l\'aggettivo della varietà non è l\'etimo'
assert lw('forse dal latino X', 'x') == [] and lw('composto da ago e puntura', 'agopuntura')[1][2] == 'puntura'
# il Wiktionnaire per il greco antico: i composti scritti con traslitterazione e glossa, il verbo, mai un etimo solo in
# parte («combiné avec»), mai un etimo greco in caratteri latini; il francese resta com'era
from etimi_wiktionnaire import leggi as lwn
assert [e for _, _, e, _, _, _ in lwn("Composé de ἀντί, antí (« opposé ») et de πόλις, pólis (« ville »).", 'Ἀντίπολις', 'grc')] == ['ἀντί', 'πόλις']
assert [e for _, _, e, _, _, _ in lwn("Composé de δῆμος, dêmos (« peuple »), σθένος, sthénos (« force ») et -ης, -ēs.", 'Δημοσθένης', 'grc')] == ['δῆμος', 'σθένος']
assert lwn("Du verbe χαίρω, khaírō (« se réjouir »).", 'χαῖρε', 'grc') == [(1, 'grc', 'χαίρω', 'derivazione', None, 3)]
assert lwn("Du verbe φύω, phúô (« naître ») combiné avec le verbe εἴλω.", 'φυλή', 'grc') == []
assert lwn("Dérivé de logos.", 'λογικός', 'grc') == [] and lwn("De l’indo-européen commun *bʰer-.", 'φέρω', 'grc') == []
assert lwn("Dérivé de chant, avec le suffixe -eur.", 'chanteur') == [(1, 'fr', 'chant', 'derivazione', '-eur', 3)]
# i due Wiktionary: concordano anche con un'altra forma di citazione o più in alto nella catena; due analisi italiane
# diverse non sono un disaccordo; un'altra lingua d'origine sì
from confronta_wikizionario import classifica as cw
assert cw([('la', 'ascendĕre')], {('la', 'ascendo'), ('ine', 'skend')}) == 'concorda'
assert cw([('la', 'papam')], {('la', 'papa')}) == 'concorda' and cw([('la', 'cycnus')], {('la', 'cygnus')}) == 'concorda'
assert cw([('it', 'poli-'), ('it', 'centro')], {('it', 'poli'), ('it', 'centrico')}) == 'concorda'
assert cw([('it', 'tavola')], {('la', 'tabula')}) == 'analisi', 'tavolo da tavola o dal latino: due analisi'
assert cw([('fr', 'destinataire')], {('la', 'destinatarius')}) == 'discorda'
assert cw([('grc', 'ὀκτάεδρος')], {('it', 'otta'), ('it', 'edro')}, formazione_italiana=True) == 'analisi', 'dotto o formazione'
assert cw([('fr', 'changer')], {('it', 'cangiare')}, formazione_italiana=True) == 'discorda'
assert cw([('la', 'casa')], {('la', 'caso')}) == 'discorda', 'parole corte: una lettera è un\'altra parola'
# greco: le regole che una coppia nota insegna (apprendi_greco.py), e una regola appresa che scatta solo su una base unica
from apprendi_greco import regole_della_coppia as rc, Modello
assert rc('σκοτιζω', ['σκοτοσ']) == [('S', 'ιζω', 'οσ')] and rc('καταβαινω', ['βαινω']) == [('P', 'κατα')]
assert rc('λαμπαδηφοροσ', ['λαμπασ', 'φερω']) == [('C', 'φοροσ', 'φερω')] and rc('φιλοσοφοσ', ['φιλοσ', 'σοφοσ']) == [('C', 'σοφοσ', 'σοφοσ')]
mg = Modello({'σκοτοσ': {'σκότος'}, 'κηρυσσω': {'κηρύσσω'}, 'ομοιοσ': {'ὅμοιος', 'ὁμοῖος'}}, {})
mg.S['ιζω'].add('οσ'); mg.S['ξισ'].add('σσω'); mg.S['οω'].add('οσ')
assert mg.scatti('σκοτιζω', 'σκοτίζω') == [(('S', 'ιζω', 'οσ'), ('σκότος',))]
assert mg.scatti('κηρυξισ', 'κήρυξις') == [(('S', 'ξισ', 'σσω'), ('κηρύσσω',))]
assert mg.scatti('ομοιοω', 'ὁμοιόω') == [], 'due basi con la stessa forma: nessuna previsione'
# verbo = preverbio + verbo: il preverbio più lungo, eliso solo davanti a vocale; la base dev'essere un verbo
from apprendi_greco import preverbio
assert preverbio('καταλυω') == 'κατα' and preverbio('καθαιρεω') == 'καθ' and preverbio('διερχομαι') == 'δι'
assert preverbio('τερπω') is None and preverbio('διαταξισ') is None and preverbio('περιαγω') == 'περι'
mv = Modello({'λυω': {'λύω'}, 'αλυω': {'ἀλύω'}, 'ταξισ': {'τάξις'}}, {})
assert mv.scatti('καταλυω', 'καταλύω') == [(('V', 'preverbio'), ('λύω',))], 'κατα- + λύω, non κατ- + ἀλύω'
assert mv.scatti('διαταξισ', 'διάταξις') == [], 'un nome non è un verbo composto'
# ricostruzioni alternative: *gʰeh₁bʰ- è una variante di *gʰebʰ- (Wiktionary lo dice), e habeō e give stanno in una
# famiglia; il passaggio resta anche se la variante è una radice. *ker- e *ḱer- non si toccano
from filtra import ricostruzioni_alternative as ra
assert ra({'word': 'gʰeh₁bʰ-', 'senses': [{'alt_of': [{'word': '*gʰebʰ-'}]}]}) == [('gʰeh₁bʰ-', 'gʰebʰ-', 'alt_of')]
assert ra({'word': 'gʰebʰ-', 'forms': [{'form': '*gʰeh₁bʰ-', 'tags': ['alternative']}, {'form': '*x- (Beekes)', 'tags': ['alternative']}]}) \
    == [('gʰeh₁bʰ-', 'gʰebʰ-', 'alternative')]
cartella_v = tempfile.mkdtemp()
open(cartella_v + '/varianti.tsv', 'w').write('gʰeh₁bʰ-\tgʰebʰ-\ngʰebʰ-\tgʰeh₁bʰ-\nḱer-\tker-\n')
imp = Importatore()
imp.carica_chiusura('ine-pro', os.devnull, varianti=cartella_v + '/varianti.tsv')
habeo, give = imp.lessema('la', 'habeō'), imp.lessema('en', 'give')
r1, r2, r3 = imp.lessema('ine-pro', '*gʰeh₁bʰ-'), imp.lessema('ine-pro', '*gʰebʰ-'), imp.lessema('ine-pro', '*ker-')
arco(imp, habeo, r1); arco(imp, give, r2); arco(imp, imp.lessema('en', 'gift'), r2)
imp.unisci_varianti(); imp.togli_archi_impossibili(); imp.togli_cicli()
v = [(r['esito'], r['etimo'], r['tipo']) for r in imp.relazioni if r['tipo'] == 'variante']
assert v == [(r1, r2, 'variante')], v          # si citano a vicenda: principale *gʰebʰ-, con più parole sotto
assert imp.ipotesi[r1 + '#wikt-variante']['confidenza'] == 3
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
# i discendenti dichiarati: una parola senza etimologia prende l'arco dell'albero (agua < aqua), non un nodo incerto né
# ciò che gli sta sotto, non una parola con omografi, non una parola indoeuropea; e solo se la misura regge
import wiktionary
imp = Importatore()
aqua, acqua, agua, eau, ewe = (imp.lessema('la', 'aqua'), imp.lessema('it', 'acqua'), imp.lessema('es', 'agua'),
                               imp.lessema('fr', 'eau'), imp.lessema('fro', 'ewe'))
agua_pt = imp.lessema('pt', 'água')
aquarium, canna, canna2, wod = (imp.lessema('en', 'aquarium'), imp.lessema('it', 'canna'), imp.lessema('it', 'canna', omografo=2),
                                imp.lessema('ine-pro', '*wódr̥'))
arco(imp, acqua, aqua)
with open(f'{d}/discendenti.tsv', 'w') as f:
    f.write('aqua\t1\t\t1\tit\tacqua\t\n' 'aqua\t1\t\t1\tes\tagua\t\n' 'aqua\t1\t\t1\tfro\tewe\tunc\n'
            'aqua\t1\t\t2\tfr\teau\t\n' 'aqua\t1\t\t1\ten\taquarium\tbor\n' 'aqua\t1\t\t1\tit\tcanna\t\n'
            'aqua\t1\t\t1\tine-pro\t*wódr̥\t\n'
            # il nome di un ramo senza parola tiene il posto: ciò che gli sta sotto discende da aqua, non dal nodo prima
            'aqua\t1\t\t1\tit\tacqua\t\n' 'aqua\t1\t\t1\troa-ibe\t\t\n' 'aqua\t1\t\t2\tpt\tágua\t\n')
# una radice con omografe: l'arco va alla radice che la pagina dichiara con il suo identificativo, o a nessuna
vestire, pascolare = imp.lessema('ine-pro', '*wes-', ident='dress'), imp.lessema('ine-pro', '*wes-', ident='graze')
generica, veste, bosko = imp.lessema('ine-pro', '*wes-'), imp.lessema('grc', 'ἐσθής'), imp.lessema('grc', 'βόσκω')
imp.id_proprio[generica] = 'dress'
with open(f'{d}/discendenti_pie.tsv', 'w') as f:
    f.write('wes-\t1\t1\t1\tgrc\tἐσθής\t\n' 'wes-\t2\t1\t1\tgrc\tβόσκω\t\n')
wiktionary.DISCENDENTI_DICHIARATI = (5, 0.85)
imp.collega_discendenti([('la', f'{d}/discendenti.tsv')])
assert imp.stat['discendenti_regola_non_applicata'] == 3 and not imp.stat['discendenti_collegati'], imp.stat
wiktionary.DISCENDENTI_DICHIARATI = (1, 0.85)
imp.collega_discendenti([('la', f'{d}/discendenti.tsv'), ('ine-pro', f'{d}/discendenti_pie.tsv')])
nuovi = {(r['esito'], r['etimo'], r['tipo'], r['conf']) for r in imp.relazioni if r['ipotesi'].endswith('#wikt-discendente')}
assert nuovi == {(agua, aqua, 'eredita', 2), (aquarium, aqua, 'prestito', 2), (agua_pt, aqua, 'eredita', 2), (veste, vestire, 'eredita', 2)}, nuovi
assert imp.ipotesi[agua + '#wikt-discendente']['etichetta'] == 'Wiktionary (discendente dichiarato)'
wiktionary.DISCENDENTI_DICHIARATI = (500, 0.85)
# le parole nuove dei rami antichi: entra il discendente che ha la sua pagina in una lingua di chiusura (gotico watō),
# non quello senza pagina, non una locuzione, non una pagina con omografi, non sotto una lingua fuori dall'elenco
imp = Importatore()
vuoto = {'voci': [], 'omografi': {}, 'forme': {}, 'participi': {}, 'flesse': {}, 'file_glosse': None}
imp.chiusura['got'] = {**vuoto, 'lemmi': {'𐍅𐌰𐍄𐍉', '𐌰𐌷𐍈𐌰'}, 'omografi': {'𐌰𐌷𐍈𐌰': [(1, set()), (2, set())]}}
imp.chiusura['es'] = {**vuoto, 'lemmi': {'agua'}}
# una pagina che è solo la grafia alternativa di un'altra parola non entra; e una parola entrata che resta senza
# etimologia e senza derivati esce
with open(f'{d}/got_glosse.tsv', 'w') as f:
    f.write('𐍅𐌰𐍄𐍉\t1\tnoun\twater\n' '𐍅𐌰𐍄𐍉𐌽\t1\tnoun\talternative form of 𐍅𐌰𐍄𐍉\n')
imp.chiusura['got']['lemmi'].add('𐍅𐌰𐍄𐍉𐌽')
imp.chiusura['got']['file_glosse'] = f'{d}/got_glosse.tsv'
acqua_pie, aqua = imp.lessema('ine-pro', '*wódr̥'), imp.lessema('la', 'aqua')
with open(f'{d}/discendenti_semina.tsv', 'w') as f:
    f.write('wódr̥\t1\t1\t1\tgot\t𐍅𐌰𐍄𐍉\t\n' 'wódr̥\t1\t1\t1\tgot\t𐍅𐌰𐍄𐌰\t\n' 'wódr̥\t1\t1\t1\tgot\t𐌰𐌷𐍈𐌰\t\n'
            'wódr̥\t1\t1\t1\tgot\t𐍅𐌰𐍄𐍉 𐍅𐌰𐍄𐍉\t\n' 'wódr̥\t1\t1\t1\txx\tboh\t\n' 'wódr̥\t1\t1\t1\tgot\t𐍅𐌰𐍄𐍉𐌽\t\n')
with open(f'{d}/discendenti_semina_la.tsv', 'w') as f:
    f.write('aqua\t1\t\t1\tes\tagua\t\n')
percorsi = [('ine-pro', f'{d}/discendenti_semina.tsv'), ('la', f'{d}/discendenti_semina_la.tsv')]
assert imp.semina_discendenti(percorsi, {'ine-pro', 'grc'}) == 1, imp.stat
assert {l['lemma'] for l in imp.lessemi.values() if l['lingua'] == 'got'} == {'𐍅𐌰𐍄𐍉'}, imp.lessemi.keys()
assert not any(l['lingua'] == 'es' for l in imp.lessemi.values()), 'il latino non è tra i rami da cui si semina'
assert imp.semina_discendenti(percorsi, {'ine-pro', 'grc'}) == 0, 'la seconda volta non c\'è più niente da seminare'
assert imp.stat['discendenti_sole_varianti'] == 2, imp.stat
imp.togli_seminati_orfani()
assert not any(l['lingua'] == 'got' for l in imp.lessemi.values()) and imp.stat['discendenti_seminati_orfani'] == 1
# le lingue antiche del confronto entrano anche dal basso (--risali): un lemma ittita entra se un etimo della sua pagina
# (o la radice che dichiara) è già nel dizionario; non per un confronto, non un nome proprio, non un etimo nuovo
imp = Importatore()
imp.lessema('ine-pro', '*wódr̥'); imp.lessema('ine-pro', '*(s)ker-', ident='cut')
v = lambda tpl, p='noun', w='𒉿𒀀𒋻': {'w': w, 'p': p, 'tpl': tpl}
assert imp.etimo_presente(v([{'n': 'inh', 'a': {'1': 'hit', '2': 'ine-pro', '3': '*wódr̥'}}]))
assert imp.etimo_presente(v([{'n': 'root', 'a': {'1': 'hit', '2': 'ine-pro', '3': '*(s)ker-'}}]))
assert not imp.etimo_presente(v([{'n': 'cog', 'a': {'1': 'grc', '2': 'ὕδωρ'}}]))
assert not imp.etimo_presente(v([{'n': 'inh', 'a': {'1': 'hit', '2': 'ine-pro', '3': '*wódr̥'}}], p='name'))
assert not imp.etimo_presente(v([{'n': 'inh', 'a': {'1': 'hit', '2': 'ine-pro', '3': '*h₂ébʰō'}}]))
# una lingua con le sole voci che hanno un'etimologia (le romanze): mai un nome proprio, una locuzione o una contrazione;
# nelle lingue intere (latino) anche i nomi propri
imp = Importatore()
imp.con_etimologia, imp.intere = {'es'}, {'la'}
assert imp.ammessa('es', {'w': 'estornino', 'p': 'noun'})
assert not imp.ammessa('es', {'w': 'del', 'p': 'contraction'}) and not imp.ammessa('es', {'w': 'Madrid', 'p': 'name'})
assert not imp.ammessa('es', {'w': 'a menudo', 'p': 'adv'})
assert imp.ammessa('la', {'w': 'Romanus', 'p': 'name'})
# un prefisso senza base aspetta l'etimo dopo il «+» (agăța = a- + *accaptiāre); senza «+» la catena si ferma come prima;
# un primo etimo che non è una forma valida (preb(i)ter) lascia il posto al successivo (preot < presbyter)
imp = Importatore()
imp.voce({'w': 'agăța', 'p': 'verb', 't': 'From a- + Vulgar Latin *accaptiāre.', 'g': ['x'], 'tpl': [
    {'n': 'af', 'a': {'1': 'ro', '2': 'a-'}, 'e': 'a-'}, {'n': 'inh', 'a': {'1': 'ro', '2': 'la-vul', '3': '*accaptiāre'}, 'e': 'Vulgar Latin *accaptiāre'}]}, lingua_voce='ro')
imp.voce({'w': 'zzzu', 'p': 'verb', 't': 'From a- (prefix). Compare Latin xyz.', 'g': ['x'], 'tpl': [
    {'n': 'af', 'a': {'1': 'ro', '2': 'a-'}, 'e': 'a-'}, {'n': 'der', 'a': {'1': 'ro', '2': 'la', '3': 'xyz'}, 'e': 'Latin xyz'}]}, lingua_voce='ro')
imp.voce({'w': 'preot', 'p': 'noun', 't': 'Vulgar Latin preb(i)ter, popular variant of Latin presbyter.', 'g': ['x'], 'tpl': [
    {'n': 'inh+', 'a': {'1': 'ro', '2': 'la-vul', '3': '', '4': 'preb(i)ter'}, 'e': 'Vulgar Latin preb(i)ter'},
    {'n': 'inh', 'a': {'1': 'ro', '2': 'la', '3': 'presbyter'}, 'e': 'Latin presbyter'}]}, lingua_voce='ro')
archi = {(r['esito'].split(':', 2)[2], r['etimo'].split(':', 2)[2], r['affisso']) for r in imp.relazioni}
assert archi == {('agăța', '*accaptiare', 'a-'), ('preot', 'presbyter', None)}, archi
# una parola indoeuropea con la sua pagina, anche senza etimologia, non prende un etimo dalla catena di un'altra pagina: nella
# pagina di Nero «… from *h₂nḗr. … It is possible that the term was borrowed from Sabine nerō» non fa di *h₂nḗr un prestito
# dal sabino; e il sabino discende dal protoitalico
from wiktionary import antenato_lingua, nome_pagina
assert antenato_lingua('sbv') == 'itc-pro'
# dentro le lingue germaniche l'antenato immediato: l'inglese discende dall'antico inglese, lo svedese dal norreno, l'afrikaans
# dall'olandese; non il contrario, e lo yiddish non è un antenato del tedesco
from wiktionary import discende_da
assert discende_da('en', 'ang') and discende_da('sv', 'non') and discende_da('af', 'nl') and discende_da('en', 'gem-pro')
assert not discende_da('ang', 'en') and not discende_da('non', 'sv') and not discende_da('de', 'yi') and not discende_da('da', 'nb')
# e dentro le slave: il russo discende dall'antico slavo orientale, il bulgaro dallo slavo ecclesiastico antico
assert discende_da('ru', 'orv') and discende_da('bg', 'cu') and discende_da('pl', 'zlw-opl') and discende_da('sla-pro', 'ine-bsl-pro')
assert not discende_da('orv', 'ru') and not discende_da('cu', 'bg') and not discende_da('ru', 'pl')
# il ripiego sulla radice dichiarata: nella stessa lingua la cima ha la forma della radice (*trémti < *trem-, *puH-yós
# < *pewH-, *ḱád-e-ti < *ḱh₂d-, *teh₂tis < *(s)teh₂-), non *úp < *men- né *dwóh₁ < *pel-
from wiktionary import ha_la_forma_della_radice as _hf
assert _hf('trémti', 'trem-') and _hf('puH-yós', 'pewH-') and _hf('ḱád-e-ti', 'ḱh₂d-') and _hf('teh₂tis', '(s)teh₂-')
assert _hf('h₁wogʷʰ-eye-ti', 'h₁wegʷʰ-') and _hf('wi-wǵʰ-é-ti', 'weǵʰ-') and _hf('káput', 'kap-')
assert not _hf('úp', 'men-') and not _hf('dwóh₁', 'pel-') and not _hf('dóru', 'weyd-')
# una forma ricostruita in alfabeto latino non ha traslitterazione (*bʰōw- «literally»), e nessuna voce ne ha una di HTML;
# le altre scritture la tengono
imp = Importatore()
assert imp.lessemi[imp.lessema('ine-pro', '*bʰōw-', translit='literally')]['translit'] is None
assert imp.lessemi[imp.lessema('egy', 'pr-ꜥꜣ', translit='<i class="Latn mention">pr-ꜥꜣ</i>')]['translit'] is None
assert imp.lessemi[imp.lessema('got', '*𐌲𐌰𐌱𐌹𐌻𐌰', translit='*gabila')]['translit'] == '*gabila'
# per una forma ricostruita una glossa che è un affisso è il suo discendente (*-kos «-y»), non il suo senso
imp = Importatore()
_k = imp.lessema('ine-pro', '*-kos', glossa='-y')
assert imp.scegli_glossa(imp.lessemi[_k]) is None
imp.lessema('ine-pro', '*-kos', glossa='adjectival suffix')
assert imp.scegli_glossa(imp.lessemi[_k]) == 'adjectival suffix'
# un lemma di sole cifre o segni non è una parola
from wiktionary import senza_lettere
assert senza_lettere('24') and senza_lettere('+') and senza_lettere('++') and senza_lettere('🎻') and senza_lettere('1-2-3')
assert not senza_lettere('ἄλφα') and not senza_lettere('18-enne') and not senza_lettere('h₂ner') and not senza_lettere('')
# e la tabella delle lingue porta quell'antenato anche per le germaniche non curate (svedese < svedese antico)
import tempfile
imp = Importatore()
imp.lessema('sv', 'djur'); imp.lessema('gmq-osw', 'diur')
_d = tempfile.mkdtemp(); imp.scrivi(_d)
_l = {r.split('\t')[0]: r.rstrip('\n').split('\t') for r in open(_d + '/lingue.tsv', encoding='utf-8')}
assert _l['sv'][5:8] == ['indoeuropea', 'germanica', 'gmq-osw'] and _l['gmq-osw'][7] == 'non', (_l['sv'], _l['gmq-osw'])
imp = Importatore()
imp.chiusura['ine-pro'] = {'voci': [], 'omografi': {}, 'forme': {}, 'participi': {}, 'flesse': {}, 'file_glosse': None,
                           'lemmi': {nome_pagina('ine-pro', 'h₂nḗr')}}
imp.voce({'w': 'Nero', 'p': 'name', 'g': ['Nero'], 'tpl': [
    {'n': 'inh', 'a': {'1': 'la', '2': 'itc-pro', '3': '*nēr'}, 'e': 'Proto-Italic *nēr'},
    {'n': 'der', 'a': {'1': 'la', '2': 'ine-pro', '3': '*h₂nḗr'}, 'e': 'Proto-Indo-European *h₂nḗr'},
    {'n': 'bor', 'a': {'1': 'la', '2': 'sbv', '3': 'nerō'}, 'e': 'Sabine nerō'}],
    't': 'From Proto-Italic *nēr, from Proto-Indo-European *h₂nḗr. It is possible that the term was borrowed from Sabine nerō.'}, lingua_voce='la')
imp.risolvi_intermedi()
assert not [h for h in imp.ipotesi.values() if h['esito'] == imp.chiave_di('ine-pro', '*h₂nḗr')]
assert [h for h in imp.ipotesi.values() if h['esito'] == imp.chiave_di('itc-pro', '*nēr')], 'il passaggio *nēr < *h₂nḗr resta'
# una radice con l'identificativo tra parentesi, come nei nomi delle categorie («*h₃ed- (bite)»), è la radice omografa con
# quell'identificativo, non una voce a sé; una forma ricostruita che non è una radice resta com'è
imp = Importatore()
assert imp.lessema('ine-pro', '*h₃ed- (bite)') == imp.lessema('ine-pro', '*h₃ed-', ident='bite') == 'enwikt:ine-pro:*h₃ed-@bite'
assert imp.lessemi['enwikt:ine-pro:*h₃ed-@bite']['lemma'] == 'h₃ed-'
assert imp.lessema('la-vul', '*veranum (tempus)') == 'enwikt:la-vul:*veranum (tempus)'
# il Wiktionnaire scrive l'etimo latino all'infinito («Du latin calculare»): va alla voce del dizionario, alla prima persona
from etimi_wiktionnaire import verbo_latino
_v = {('la', 'calculo'), ('la', 'loquor'), ('la', 'rosa')}
assert (verbo_latino('calculāre', _v), verbo_latino('loqui', _v), verbo_latino('rosa', _v), verbo_latino('xyzare', _v)) == ('calculo', 'loquor', 'rosa', 'xyzare')
# le radici semitiche: la parola araba dichiara la sua radice ({{etymon|ar|:root|…}}, {{ar-root}}, {{ar-rootbox}}) e, se la pagina
# non dà un altro etimo, ne deriva; una radice di un'altra lingua (ar-root in una voce italiana) non conta
from filtra import radice_semitica as rs
assert rs([{'name': 'etymon', 'args': {'1': 'ar', 'id': 'book', '2': ':root', '3': 'ك ت ب<id:root>'}}], 'ar')['args']['3'] == 'ك ت ب'
assert rs([{'name': 'ar-rootbox', 'args': {'1': 'ق ل ب'}}], 'ar')['name'] == 'radice'
assert rs([{'name': 'ar-root', 'args': {'1': 'خ ل ف'}}], 'it') is None
imp = Importatore()
imp.voce({'w': 'كتاب', 'p': 'noun', 't': '', 'g': ['book'], 'tpl': [{'n': 'radice', 'a': {'1': 'ar', '2': 'ar', '3': 'ك ت ب'}, 'e': ''}]}, lingua_voce='ar')
assert [(r['tipo'], imp.lessemi[r['etimo']]['lemma']) for r in imp.relazioni] == [('derivazione', 'ك ت ب')], imp.relazioni
# un segno di una scrittura non è una parola: il segno sillabico 𐀆 e il numerale 𐄉 escono, la congiunzione 𐀤 resta
imp = Importatore()
for lemma, glossa in (('𐀆', 'The Linear B syllabic letter ⟨de⟩.'), ('𐄉', 'three, 3'), ('𐀤', 'and')):
    imp.lessema('gmy', lemma, glossa=glossa)
imp.togli_non_validi()
assert {l['lemma'] for l in imp.lessemi.values()} == {'𐀤'}, imp.lessemi.keys()
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
