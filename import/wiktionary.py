#!/usr/bin/env python3
"""Import delle etimologie di Wiktionary (via Kaikki/wiktextract) nello schema del dizionario.

Legge un JSONL filtrato (vedi filtra.py) e scrive file TSV per le tabelle di appoggio:
lingue, lessemi, ipotesi, relazioni, doppioni dichiarati, radici dichiarate.
Solo libreria standard. Uso:

    python3 wiktionary.py it_lemmi.jsonl cartella_uscita/ it_glosse.tsv

Regole principali
- Le catene si leggono dal testo: «From A, from B» è una catena; «or», «compare», «cf.» la interrompono.
- Quello che Wiktionary afferma vale al massimo «probabile» (3); «perhaps/possibly» abbassano a 2 l'anello
  che segue, «uncertain» a 1. La certezza 4 è un giudizio di redazione.
- Un etimo che finisce con il trattino è una radice: l'arco diventa una formazione, non un'eredità.
- Per gli etimi intermedi spiegati in più voci vince la spiegazione più frequente; le altre sono alternative.
- Gli affissi restano testo dell'arco (relazione.affisso), non diventano lessemi.
"""
import json, re, sys, os, unicodedata

# lingua delle voci da importare (codice Wiktionary): LINGUA=fr python3 wiktionary.py …
LINGUA = os.environ.get('LINGUA', 'it')
from collections import Counter, defaultdict

CATENA = {'inh': 'eredita', 'inh+': 'eredita', 'bor': 'prestito', 'bor+': 'prestito', 'ubor': 'prestito', 'obor': 'prestito',
          'lbor': 'prestito_dotto', 'slbor': 'semidotto', 'der': 'generico', 'der+': 'generico', 'uder': 'generico',
          'cal': 'calco', 'calque': 'calco', 'sl': 'calco_semantico', 'psm': 'calco'}
LOCALI = {'bf': 'retroformazione', 'back-form': 'retroformazione', 'clipping': 'accorciamento', 'ellipsis': 'accorciamento',
          'named-after': 'deonimico'}
AFFISSI = {'af', 'affix', 'suffix', 'prefix', 'confix', 'compound', 'blend'}
POS = {'verb': 'v.', 'adj': 'agg.', 'adv': 'avv.', 'name': 'np', 'prep': 'prep.', 'pron': 'pron.', 'conj': 'cong.',
       'intj': 'inter.', 'num': 'num.', 'det': 'det.', 'phrase': 'loc.', 'suffix': 'suff.', 'prefix': 'pref.'}
PREFISSI_ESPANSIONE = ('Inherited from ', 'Borrowed from ', 'Derived from ', 'Learned borrowing from ',
                       'Unadapted borrowing from ', 'Semi-learned borrowing from ', 'Orthographic borrowing from ',
                       'Calque of ', 'Semantic loan from ', 'Phono-semantic matching of ')
DUBBIO_FORTE = re.compile(r'\b(uncertain|unknown|obscure|unclear|disputed)\b', re.I)
DUBBIO = re.compile(r'\b(perhaps|possibly|maybe|conceivably)\b', re.I)
PROBABILE = re.compile(r'\b(probably|likely)\b', re.I)
INTERROMPE = re.compile(r'\b(or|compare|cf|cognates?|related|see|akin|influenced|contamination|alongside|versus|vs)\b', re.I)
PROSEGUE = re.compile(r'\b(from|via|through|ultimately)\b', re.I)
# «First element con- derives from cum…»: da qui il testo spiega le parti del composto, non la parola
ELEMENTI = re.compile(r'\b(elements?|components?|constituents?)\b|\b(first|second|third|latter|former)\s+(part|member|half)\b', re.I)

# Lingue più frequenti nelle etimologie italiane: nome e sigla in italiano e inglese, genealogia, luogo indicativo.
# Le altre vengono create con il nome inglese ricavato dalle espansioni, da rivedere.
CURATE = {
    'la-lat': ('latino tardo', 'lat. tardo', 'Late Latin', 'LL', 'indoeuropea', 'italica', None, 'la', None, None),
    'la-cla': ('latino classico', 'lat. class.', 'Classical Latin', 'CL', 'indoeuropea', 'italica', None, 'la', None, None),
    'la-new': ('latino moderno', 'lat. mod.', 'New Latin', 'NL', 'indoeuropea', 'italica', None, 'la', None, None),
    'la-ecc': ('latino ecclesiastico', 'lat. eccl.', 'Ecclesiastical Latin', 'EL', 'indoeuropea', 'italica', None, 'la', None, None),
    'la-eme': ('latino altomedievale', 'lat. altomed.', 'Early Medieval Latin', 'EML', 'indoeuropea', 'italica', None, 'la', None, None),
    'la-pre': ('latino preclassico', 'lat. precl.', 'Old Latin', 'OL', 'indoeuropea', 'italica', None, 'la', None, None),
    'roa-oit': ('italiano antico', 'it. ant.', 'Old Italian', 'OIt.', 'indoeuropea', 'italica', None, 'it', None, None),
    'grc-koi': ('greco della koinè', 'gr. koinè', 'Koine Greek', 'Koine', 'indoeuropea', 'ellenica', None, 'grc', None, None),
    # le parole scritte nel sillabario cipriota (Wiktionary le mette sotto il greco antico): una varietà a sé
    'grc-arp': ('greco arcadocipriota', 'gr. arcadocipr.', 'Arcadocypriot Greek', 'Arcadocypr.', 'indoeuropea', 'ellenica', None, 'grc', 35.0, 33.0),
    'gkm': ('greco bizantino', 'gr. biz.', 'Byzantine Greek', 'ByzGk.', 'indoeuropea', 'ellenica', 'grc', None, 41.01, 28.98),
    'el': ('greco moderno', 'gr. mod.', 'Greek', 'ModGk.', 'indoeuropea', 'ellenica', 'gkm', None, 37.98, 23.73),
    'grk-pro': ('protoellenico', 'protoellen.', 'Proto-Hellenic', 'PHel.', 'indoeuropea', 'ellenica', 'ine-pro', None, None, None),
    'frm': ('francese medio', 'fr. medio', 'Middle French', 'MFr.', 'indoeuropea', 'italica', 'fro', None, 48.86, 2.35),
    'pro': ('occitano antico', 'occ. ant.', 'Old Occitan', 'OOcc.', 'indoeuropea', 'italica', 'la', None, 43.60, 1.44),
    'oc': ('occitano', 'occ.', 'Occitan', 'Occ.', 'indoeuropea', 'italica', 'pro', None, 43.60, 1.44),
    'ca': ('catalano', 'cat.', 'Catalan', 'Cat.', 'indoeuropea', 'italica', 'la', None, 41.39, 2.17),
    'scn': ('siciliano', 'sic.', 'Sicilian', 'Sic.', 'indoeuropea', 'italica', 'la', None, 38.12, 13.36),
    'vec': ('veneto', 'ven.', 'Venetan', 'Ven.', 'indoeuropea', 'italica', 'la', None, 45.44, 12.33),
    'nap': ('napoletano', 'nap.', 'Neapolitan', 'Nap.', 'indoeuropea', 'italica', 'la', None, 40.85, 14.27),
    'lmo': ('lombardo', 'lomb.', 'Lombard', 'Lmo.', 'indoeuropea', 'italica', 'la', None, 45.46, 9.19),
    'lij': ('ligure', 'lig.', 'Ligurian', 'Lij.', 'indoeuropea', 'italica', 'la', None, 44.41, 8.93),
    'fur': ('friulano', 'friul.', 'Friulian', 'Fur.', 'indoeuropea', 'italica', 'la', None, 46.06, 13.24),
    'sc': ('sardo', 'sardo', 'Sardinian', 'Srd.', 'indoeuropea', 'italica', 'la', None, 40.10, 9.00),
    'pms': ('piemontese', 'piem.', 'Piedmontese', 'Pms.', 'indoeuropea', 'italica', 'la', None, 45.07, 7.69),
    'egl': ('emiliano', 'emil.', 'Emilian', 'Egl.', 'indoeuropea', 'italica', 'la', None, 44.49, 11.34),
    'rgn': ('romagnolo', 'romagn.', 'Romagnol', 'Rgn.', 'indoeuropea', 'italica', 'la', None, 44.22, 12.04),
    'co': ('corso', 'corso', 'Corsican', 'Co.', 'indoeuropea', 'italica', 'la', None, 42.15, 9.10),
    'ro': ('romeno', 'rom.', 'Romanian', 'Rom.', 'indoeuropea', 'italica', 'la', None, 44.43, 26.10),
    'osp': ('spagnolo antico', 'sp. ant.', 'Old Spanish', 'OSp.', 'indoeuropea', 'italica', 'la', None, 40.42, -3.70),
    'itc-ola': ('latino arcaico', 'lat. arc.', 'Old Latin', 'OL', 'indoeuropea', 'italica', 'itc-pro', None, 41.89, 12.49),
    'osc': ('osco', 'osco', 'Oscan', 'Osc.', 'indoeuropea', 'italica', 'itc-pro', None, 41.00, 14.50),
    'xum': ('umbro', 'umbro', 'Umbrian', 'Umb.', 'indoeuropea', 'italica', 'itc-pro', None, 43.10, 12.39),
    'enm': ('inglese medio', 'ingl. medio', 'Middle English', 'ME', 'indoeuropea', 'germanica', 'ang', None, 51.51, -0.13),
    'xno': ('anglonormanno', 'anglonorm.', 'Anglo-Norman', 'AN', 'indoeuropea', 'italica', 'fro', None, 51.51, -0.13),
    'goh': ('alto tedesco antico', 'a. ted. ant.', 'Old High German', 'OHG', 'indoeuropea', 'germanica', 'gmw-pro', None, 49.80, 8.60),
    'gmh': ('medio alto tedesco', 'm. a. ted.', 'Middle High German', 'MHG', 'indoeuropea', 'germanica', 'goh', None, 49.80, 9.00),
    'gmw-pro': ('protogermanico occidentale', 'protogerm. occ.', 'Proto-West Germanic', 'PWG', 'indoeuropea', 'germanica', 'gem-pro', None, None, None),
    'frk': ('francone', 'franc.', 'Frankish', 'Frk.', 'indoeuropea', 'germanica', 'gmw-pro', None, 51.00, 6.50),
    'lng': ('longobardo', 'longob.', 'Lombardic', 'Lng.', 'indoeuropea', 'germanica', 'gmw-pro', None, 45.19, 9.16),
    'got': ('gotico', 'got.', 'Gothic', 'Goth.', 'indoeuropea', 'germanica', 'gem-pro', None, 43.50, 25.50),
    'non': ('norreno', 'norr.', 'Old Norse', 'ON', 'indoeuropea', 'germanica', 'gem-pro', None, 60.00, 10.00),
    'nl': ('olandese', 'oland.', 'Dutch', 'Du.', 'indoeuropea', 'germanica', 'dum', None, 52.37, 4.90),
    'dum': ('neerlandese medio', 'neerl. medio', 'Middle Dutch', 'MDu.', 'indoeuropea', 'germanica', 'gmw-pro', None, 51.05, 3.72),
    'gem': ('germanico', 'germ.', 'Germanic', 'Gmc.', 'indoeuropea', 'germanica', None, None, None, None),
    'cel-pro': ('protoceltico', 'protocelt.', 'Proto-Celtic', 'PCelt.', 'indoeuropea', 'celtica', 'ine-pro', None, None, None),
    'cel-gau': ('gallico', 'gall.', 'Gaulish', 'Gaul.', 'indoeuropea', 'celtica', 'cel-pro', None, 46.50, 3.50),
    'xtg': ('gallico transalpino', 'gall. transalp.', 'Transalpine Gaulish', 'TGaul.', 'indoeuropea', 'celtica', 'cel-pro', None, 46.50, 3.50),
    'xcg': ('gallico cisalpino', 'gall. cisalp.', 'Cisalpine Gaulish', 'CGaul.', 'indoeuropea', 'celtica', 'cel-pro', None, 45.46, 9.19),
    'he': ('ebraico', 'ebr.', 'Hebrew', 'Heb.', 'afroasiatica', 'semitica', 'hbo', None, 31.78, 35.22),
    'hbo': ('ebraico biblico', 'ebr. bibl.', 'Biblical Hebrew', 'BHeb.', 'afroasiatica', 'semitica', None, None, 31.78, 35.22),
    'arc': ('aramaico', 'aram.', 'Aramaic', 'Aram.', 'afroasiatica', 'semitica', None, None, 33.51, 36.29),
    'syc': ('siriaco', 'sir.', 'Classical Syriac', 'Syr.', 'afroasiatica', 'semitica', 'arc', None, 37.16, 38.79),
    'akk': ('accadico', 'acc.', 'Akkadian', 'Akk.', 'afroasiatica', 'semitica', None, None, 32.54, 44.42),
    'egy': ('egizio', 'eg.', 'Egyptian', 'Egy.', 'afroasiatica', 'egizia', None, None, 29.85, 31.25),
    'cop': ('copto', 'copto', 'Coptic', 'Copt.', 'afroasiatica', 'egizia', 'egy', None, 25.70, 32.64),
    'ota': ('turco ottomano', 'tur. ott.', 'Ottoman Turkish', 'Ott.', 'turca', 'oghuz', None, None, 41.01, 28.98),
    'tr': ('turco', 'turco', 'Turkish', 'Tr.', 'turca', 'oghuz', 'ota', None, 39.93, 32.86),
    'hi': ('hindi', 'hindi', 'Hindi', 'Hin.', 'indoeuropea', 'indoiranica', None, None, 28.61, 77.21),
    'ja': ('giapponese', 'giapp.', 'Japanese', 'Jpn.', 'giapponica', None, None, None, 35.68, 139.69),
    'zh': ('cinese', 'cin.', 'Chinese', 'Chi.', 'sinotibetana', None, None, None, 39.90, 116.40),
    'nah': ('nahuatl', 'nahuatl', 'Nahuatl', 'Nah.', 'uto-azteca', None, None, None, 19.43, -99.13),
    'qu': ('quechua', 'quechua', 'Quechua', 'Que.', 'quechua', None, None, None, -13.53, -71.97),
    'mul': ('translinguistico', 'transl.', 'Translingual', 'Transl.', None, None, None, None, None, None),
    'ett': ('etrusco', 'etr.', 'Etruscan', 'Etr.', 'tirrenica', None, None, None, 42.42, 11.87),
    'sq': ('albanese', 'alb.', 'Albanian', 'Alb.', 'indoeuropea', 'albanese', None, None, 41.33, 19.82),
    'hu': ('ungherese', 'ungh.', 'Hungarian', 'Hun.', 'uralica', None, None, None, 47.50, 19.04),
    'pl': ('polacco', 'pol.', 'Polish', 'Pol.', 'indoeuropea', 'slava', 'sla-pro', None, 52.23, 21.01),
    'cs': ('ceco', 'ceco', 'Czech', 'Cz.', 'indoeuropea', 'slava', 'sla-pro', None, 50.08, 14.44),
    'sl': ('sloveno', 'slov.', 'Slovene', 'Sln.', 'indoeuropea', 'slava', 'sla-pro', None, 46.06, 14.51),
    'sh': ('serbocroato', 'serbocr.', 'Serbo-Croatian', 'SC', 'indoeuropea', 'slava', 'sla-pro', None, 44.79, 20.45),
    'cu': ('slavo ecclesiastico antico', 'sl. eccl. ant.', 'Old Church Slavonic', 'OCS', 'indoeuropea', 'slava', 'sla-pro', None, 41.12, 20.80),
    'ine-bsl-pro': ('protobaltoslavo', 'protobaltosl.', 'Proto-Balto-Slavic', 'PBS', 'indoeuropea', 'slava', 'ine-pro', None, None, None),
    'iir-pro': ('protoindoiranico', 'protoindoir.', 'Proto-Indo-Iranian', 'PII', 'indoeuropea', 'indoiranica', 'ine-pro', None, None, None),
    'peo': ('antico persiano', 'ant. pers.', 'Old Persian', 'OPers.', 'indoeuropea', 'indoiranica', 'iir-pro', None, 29.94, 52.89),
    'sem-pro': ('protosemitico', 'protosem.', 'Proto-Semitic', 'PSem.', 'afroasiatica', 'semitica', None, None, None, None),
}
TRASMISSIONE = {'eredita', 'prestito', 'prestito_dotto', 'semidotto', 'calco', 'calco_semantico'}
# Prime attestazioni: template etydate e prosa («First attested in 1590», «Attested from the 1560s»)
ANNO = re.compile(r'^-?\d{3,4}$')
SECOLO = re.compile(r'(\d{1,2})(?:st|nd|rd|th)?[ -]?(?:century|c\b|c\.)', re.I)
# solo frasi che hanno per soggetto la parola: a inizio testo o di frase (non «Old French X (attested 1150)»)
PROSA_DATA = re.compile(r'(?:^|[.;]\s+)(?:first\s+)?attested\s+(?:(c\.|circa|around|about|before|after|since|from|in)\s+)*'
                        r'(?:the\s+)?(?:(\d{3,4})(s)?\b|(\d{1,2})(?:st|nd|rd|th)[ -]century)', re.I)


def data_etydate(a):
    vals = [x.strip() for x in (a.get(str(i), '') for i in range(1, 5)) if x and x.strip()]
    prec = 'esatta'
    if vals and vals[0].lower() in ('c', 'circa', 'ca'):
        prec, vals = 'circa', vals[1:]
    elif vals and vals[0].lower() in ('before', 'ante', 'bef'):
        prec, vals = 'ante', vals[1:]
    elif vals and vals[0].lower() in ('after', 'post', 'aft'):
        prec, vals = 'post', vals[1:]
    elif vals and vals[0].lower() in ('r', 'range'):
        prec, vals = 'intervallo', vals[1:]
    anni = [int(x) for x in vals if ANNO.match(x)]
    if prec == 'intervallo' and len(anni) >= 2:
        return anni[0], anni[1], 'intervallo'
    if anni:
        return anni[0], None, prec                # «1537, but in common usage only as of 1540»: conta la prima
    for x in vals:
        m = SECOLO.search(x)
        if m:
            c = int(m.group(1))
            return (c - 1) * 100 + 1, c * 100, 'secolo'
    return None


def data_prosa(testo):
    m = PROSA_DATA.search(testo or '')
    if not m:
        return None
    modo = (m.group(1) or '').lower()
    prec = {'c.': 'circa', 'circa': 'circa', 'around': 'circa', 'about': 'circa',
            'before': 'ante', 'after': 'post'}.get(modo, 'esatta')
    if m.group(4):
        c = int(m.group(4))
        return (c - 1) * 100 + 1, c * 100, 'secolo'
    anno = int(m.group(2))
    if m.group(3):                                   # «the 1560s»: un decennio
        return anno, anno + 9, 'intervallo'
    return anno, None, prec
# Forme non finite: per l'etimologia sono parole a sé (aperto viene da apertus, aprire da aperire)
NON_FINITE = {'participle', 'gerundive', 'gerund', 'supine', 'comparative', 'superlative'}   # anche fortissimus < fortis
# Codici storici di Wiktionary ancora presenti in alcune voci
ALIAS = {'LL.': 'la-lat', 'ML.': 'la-med', 'NL.': 'la-new', 'VL.': 'la-vul', 'EL.': 'la-ecc', 'CL.': 'la-cla',
         'OL.': 'la-pre', 'LL': 'la-lat', 'ML': 'la-med', 'VL': 'la-vul'}
# Famiglia e ramo per prefisso di codice (lingue non curate)
PREFISSO_FAMIGLIA = {'gem': ('indoeuropea', 'germanica'), 'gmw': ('indoeuropea', 'germanica'), 'gmq': ('indoeuropea', 'germanica'),
                     'gml': ('indoeuropea', 'germanica'), 'sla': ('indoeuropea', 'slava'), 'zlw': ('indoeuropea', 'slava'),
                     'zle': ('indoeuropea', 'slava'), 'zls': ('indoeuropea', 'slava'), 'itc': ('indoeuropea', 'italica'),
                     'roa': ('indoeuropea', 'italica'), 'grk': ('indoeuropea', 'ellenica'), 'cel': ('indoeuropea', 'celtica'),
                     'iir': ('indoeuropea', 'indoiranica'), 'ira': ('indoeuropea', 'indoiranica'), 'inc': ('indoeuropea', 'indoiranica'),
                     'sem': ('afroasiatica', 'semitica'), 'ber': ('afroasiatica', 'berbera'), 'egx': ('afroasiatica', 'egizia'),
                     'trk': ('turca', None), 'poz': ('austronesiana', None), 'sit': ('sinotibetana', None),
                     'mkh': ('austroasiatica', None), 'azc': ('uto-azteca', None)}
# Lingue singole frequenti fuori dalle curate: famiglia, ramo, varietà di
ALTRE = {'da': ('indoeuropea', 'germanica', None), 'sv': ('indoeuropea', 'germanica', None), 'no': ('indoeuropea', 'germanica', None),
         'is': ('indoeuropea', 'germanica', None), 'yi': ('indoeuropea', 'germanica', None), 'gsw': ('indoeuropea', 'germanica', 'de'),
         'bar': ('indoeuropea', 'germanica', 'de'), 'odt': ('indoeuropea', 'germanica', None), 'cim': ('indoeuropea', 'germanica', None),
         'mhn': ('indoeuropea', 'germanica', None), 'af': ('indoeuropea', 'germanica', None), 'sco': ('indoeuropea', 'germanica', None),
         'bg': ('indoeuropea', 'slava', None), 'uk': ('indoeuropea', 'slava', None), 'orv': ('indoeuropea', 'slava', None),
         'lt': ('indoeuropea', 'baltica', None), 'cy': ('indoeuropea', 'celtica', None), 'ga': ('indoeuropea', 'celtica', None),
         'gd': ('indoeuropea', 'celtica', None), 'br': ('indoeuropea', 'celtica', None), 'obt': ('indoeuropea', 'celtica', None),
         'hy': ('indoeuropea', 'armena', None), 'xcl': ('indoeuropea', 'armena', None), 'hit': ('indoeuropea', 'anatolica', None),
         'ur': ('indoeuropea', 'indoiranica', None), 'mr': ('indoeuropea', 'indoiranica', None), 'ps': ('indoeuropea', 'indoiranica', None),
         'rom': ('indoeuropea', 'indoiranica', None), 'si': ('indoeuropea', 'indoiranica', None), 'or': ('indoeuropea', 'indoiranica', None),
         'syl': ('indoeuropea', 'indoiranica', None), 'dv': ('indoeuropea', 'indoiranica', None),
         'an': ('indoeuropea', 'italica', None), 'frp': ('indoeuropea', 'italica', None), 'rm': ('indoeuropea', 'italica', None),
         'lld': ('indoeuropea', 'italica', None), 'mxi': ('indoeuropea', 'italica', None), 'sdc': ('indoeuropea', 'italica', None),
         'itk': ('indoeuropea', 'italica', 'it'), 'xil': ('indoeuropea', None, None), 'scx': ('indoeuropea', None, None),
         'mt': ('afroasiatica', 'semitica', None), 'am': ('afroasiatica', 'semitica', None), 'ti': ('afroasiatica', 'semitica', None),
         'phn': ('afroasiatica', 'semitica', None), 'so': ('afroasiatica', 'cuscitica', None),
         'arq': ('afroasiatica', 'semitica', 'ar'), 'ary': ('afroasiatica', 'semitica', 'ar'), 'arz': ('afroasiatica', 'semitica', 'ar'),
         'ayl': ('afroasiatica', 'semitica', 'ar'), 'acy': ('afroasiatica', 'semitica', 'ar'), 'xaa': ('afroasiatica', 'semitica', 'ar'),
         'fi': ('uralica', None, None), 'udm': ('uralica', None, None), 'sjd': ('uralica', None, None),
         'tk': ('turca', None, None), 'tt': ('turca', None, None), 'crh': ('turca', None, None), 'otk': ('turca', None, None),
         'cmn': ('sinotibetana', None, 'zh'), 'ltc': ('sinotibetana', None, 'zh'), 'och': ('sinotibetana', None, 'zh'),
         'nan-hbl': ('sinotibetana', None, 'zh'), 'wuu-sha': ('sinotibetana', None, 'zh'), 'bo': ('sinotibetana', None, None),
         'my': ('sinotibetana', None, None), 'ms': ('austronesiana', None, None), 'id': ('austronesiana', None, None),
         'jv': ('austronesiana', None, None), 'tl': ('austronesiana', None, None), 'mg': ('austronesiana', None, None),
         'haw': ('austronesiana', None, None), 'mi': ('austronesiana', None, None), 'ko': ('coreanica', None, None),
         'ojp': ('giapponica', None, 'ja'), 'nci': ('uto-azteca', None, 'nah')}
NOMI_MANCANTI = {'eo': 'Esperanto', 'ko': 'Korean', 'xng': 'Middle Mongolian'}
# Varietà con nome di pagina senza macron e brevi (convenzione di Wiktionary)
SENZA_QUANTITA = re.compile(r'^(la|la-\w+|grc|grc-\w+|gkm|itc-ola|osc|xum)$')
# Lingue già nel seme: non vanno ricreate, ma servono per riconoscere le ricostruite
NOTE = {'ine-pro', 'itc-pro', 'gem-pro', 'sla-pro', 'la', 'la-vul', 'la-med', 'grc', 'sa', 'it', 'fro', 'fr', 'es', 'pt',
        'ang', 'en', 'de', 'ru', 'pal', 'fa', 'ar'}


def pulisci_parte(p):
    """'cento<t:hundred>' -> ('cento', None); 'la:vitium' -> ('vitium', 'la')."""
    p = re.sub(r'<[^>]*>', '', p or '').strip()
    lingua = None
    m = re.match(r'^([a-z]{2,3}(?:-[a-z]{2,4})*):(.+)$', p)
    if m and not p.startswith('http'):
        lingua, p = m.group(1), m.group(2)
    return p.strip(), lingua


def senza_modificatori(t):
    """Il termine senza i modificatori in linea dei modelli di Wiktionary, anche annidati:
    'scorciare<t:to shorten>' → 'scorciare', 'pisciare<ref:<<name:garz>>>' → 'pisciare', 'Giappone>>' → 'Giappone'."""
    t = t or ''
    while True:
        u = re.sub(r'<[^<>]*>', '', t)
        if u == t:
            return u.replace('<', '').replace('>', '').strip()
        t = u


def codice_lingua(c):
    c = (c or '').split(',')[0].strip()
    return ALIAS.get(c, c)


# Segni vocalici che Wiktionary toglie dai titoli delle pagine nelle scritture semitiche: punti e cantillazione
# dell'ebraico (e dell'aramaico in scrittura ebraica), harakat dell'arabo, vocali del siriaco. La hamza resta: è una lettera.
SEGNI_VOCALICI = re.compile('[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7\u064b-\u0652\u0670\u0640\u0730-\u074a]')
SENZA_VOCALI = {'ar', 'arc', 'he', 'hbo', 'syc', 'fa', 'fa-cls', 'ota', 'ur'}


def nome_pagina(lingua, termine):
    """Il titolo della pagina: per latino e greco senza macron e brevi (carō → caro);
    per ebraico, aramaico, arabo e siriaco senza segni vocalici (אַבָּא → אבא)."""
    if SENZA_QUANTITA.match(lingua or ''):
        termine = unicodedata.normalize('NFC', ''.join(ch for ch in unicodedata.normalize('NFD', termine) if ch not in '\u0304\u0306'))
    elif (lingua or '').split('-')[0] in SENZA_VOCALI or lingua in SENZA_VOCALI:
        termine = SEGNI_VOCALICI.sub('', unicodedata.normalize('NFC', termine))
    return termine


# ---- traslitterazione del greco antico, per le parole che Wiktionary cita senza tr= ----
GRC = {'α': 'a', 'β': 'b', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'ζ': 'z', 'η': 'ē', 'θ': 'th', 'ι': 'i', 'κ': 'k', 'λ': 'l',
       'μ': 'm', 'ν': 'n', 'ξ': 'x', 'ο': 'o', 'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'ϲ': 's', 'τ': 't', 'υ': 'u',
       'φ': 'ph', 'χ': 'kh', 'ψ': 'ps', 'ω': 'ō', 'ϝ': 'w', 'ϙ': 'q', 'ϛ': 'st'}
VOC = set('αεηιουω')
DITT = {('α', 'ι'), ('ε', 'ι'), ('ο', 'ι'), ('υ', 'ι'), ('α', 'υ'), ('ε', 'υ'), ('η', 'υ'), ('ο', 'υ')}
ASPRO, DOLCE, ACUTO, GRAVE, CIRC, DIER, SOTT, MACR, BREVE = '\u0314', '\u0313', '\u0301', '\u0300', '\u0342', '\u0308', '\u0345', '\u0304', '\u0306'

def translit_grc(parola):
    """Traslitterazione del greco antico secondo lo schema di Wiktionary (χ kh, υ u, η ē, spirito aspro h)."""
    gruppi = []
    for ch in unicodedata.normalize('NFD', parola):
        if unicodedata.combining(ch) and gruppi:
            gruppi[-1][1].add(ch)
        else:
            gruppi.append([ch, set()])
    out, n, i = [], len(gruppi), 0
    def vocale(b, segni):
        v = GRC[b]
        if MACR in segni and v in 'aiu':
            v += MACR
        if CIRC in segni:
            v = v.replace('ē', 'e').replace('ō', 'o').replace(MACR, '') + '\u0302'
        if DIER in segni: v += DIER          # la dieresi prima dell'accento: ḯ
        if ACUTO in segni: v += ACUTO
        if GRAVE in segni: v += GRAVE
        if SOTT in segni: v += 'i'
        return v
    while i < n:
        base, segni = gruppi[i]
        b = base.lower()
        maiuscola = base != b
        if b not in GRC:
            out.append(base); i += 1; continue
        inizio = i == 0 or gruppi[i - 1][0].lower() not in GRC
        if b in VOC:
            dittongo = (i + 1 < n and (b, gruppi[i + 1][0].lower()) in DITT and DIER not in gruppi[i + 1][1])
            parte = vocale(b, segni) + (vocale(gruppi[i + 1][0].lower(), gruppi[i + 1][1]) if dittongo else '')
            if inizio and (ASPRO in segni or (dittongo and ASPRO in gruppi[i + 1][1])):
                parte = 'h' + parte
            i += 2 if dittongo else 1
        elif b == 'ρ':
            if ASPRO in segni or (i > 0 and gruppi[i - 1][0].lower() == 'ρ'):
                parte = 'rh'
            else:
                parte = 'r'
            i += 1
        elif b == 'γ' and i + 1 < n and gruppi[i + 1][0].lower() in 'γκξχ':
            parte = 'n'; i += 1
        else:
            parte = GRC[b]; i += 1
        out.append(parte[:1].upper() + parte[1:] if maiuscola else parte)
    return unicodedata.normalize('NFC', ''.join(out))


GRECO = re.compile('[\u0370-\u03ff\u1f00-\u1fff]')

# Le voci del dizionario sono parole. Per latino e greco: solo lettere del loro alfabeto, con i diacritici (23 lettere
# latine, più j, u, w delle grafie moderne e medievali; 24 greche), spazi, trattini e apostrofi interni. Fuori le lettere
# isolate (A, Ϝ), i simboli (☉), le abbreviazioni (A., ꝑ), i numeri (6tus), il sillabario cipriota, le lettere
# epicoriche (ϝοῖκος, ͷοῖκος) e i frammenti di testo che una citazione può trascinare («βάλλω (bállo, “to strike”)>»).
# Le lettere epicoriche (ϝ, ϙ, ϻ, ͷ, ͱ, ͳ, ϳ) sono ammesse nelle parole (ϝοῖκος, forma attestata), che però restano fuori
# dall'indice a 24 lettere; da sole no. Il sillabario cipriota è la scrittura del greco arcadocipriota (grc-arp).
CIPRIOTA = {chr(c) for c in range(0x10800, 0x10840)}
LETTERE = {'la': set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZæœÆŒ'),
           'grc': set('αβγδεζηθικλμνξοπρσςτυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩϝϜϙϘϻϺͷͶͱͰͳͲϳͿ'),
           'grc-arp': CIPRIOTA}
NON_LEMMA = re.compile(r'[()\[\]{}<>“”"=|]')


def lemma_valido(lingua, lemma, ricostruito=False):
    if not (lemma or '').strip('*- '):
        return False                    # un lemma vuoto («itc-pro:» da un termine senza parola) non è una voce
    if ricostruito:                                      # le ricostruzioni hanno la loro notazione: *(s)ker-
        return True
    if NON_LEMMA.search(lemma or ''):
        return False
    lettere = LETTERE.get(lingua) or LETTERE.get(base_lingua(lingua))
    if lettere is None:
        return True
    corpo = lemma.strip('-')
    basi = [c for c in unicodedata.normalize('NFD', corpo) if not unicodedata.combining(c)]
    if not basi or basi[0] not in lettere or basi[-1] not in lettere or any(c not in lettere and c not in " -'’" for c in basi):
        return False
    if sum(c in lettere for c in basi) == 1 and corpo == lemma:
        # una lettera sola è una parola solo con i suoi segni (ὁ, ὦ) o, in latino, minuscola (ā, ē, ō): A, α, Ϝ no
        return len(unicodedata.normalize('NFD', corpo)) > 1 if base_lingua(lingua) == 'grc' else basi[0].islower()
    return True


def norm(t):
    t = t.lower()
    for a, b in (('ß', 'ss'), ('æ', 'ae'), ('œ', 'oe'), ('þ', 'th'), ('ð', 'd'), ('ı', 'i')):
        t = t.replace(a, b)
    t = ''.join(ch for ch in unicodedata.normalize('NFKD', t) if not ('\u0300' <= ch <= '\u036f' or '\u064b' <= ch <= '\u065f' or ch == '\u0670'))
    t = t.replace('ς', 'σ').replace('ø', 'o').replace('ł', 'l').replace('đ', 'd').replace('ħ', 'h')
    t = re.sub(r"[ʿʾʼʹʺ'’‘\"*()\[\]{}<>\-‐–—.,;:!?·/]", '', t)
    return re.sub(r'\s+', ' ', t).strip()


BASE = {'roa-oit': 'it', 'grc-koi': 'grc', 'grk-ita': 'grc'}
# Periodi del latino e del greco: per Wiktionary sono la stessa voce (Late Latin pauso = Latin pauso).
# Le forme ricostruite del latino volgare restano a sé.
VARIETA_ATTESTATE = {'la-lat': 'la', 'la-med': 'la', 'la-cla': 'la', 'la-new': 'la', 'la-ecc': 'la', 'la-eme': 'la',
                     'la-pre': 'la', 'la-ren': 'la', 'grc-koi': 'grc'}
# Genealogia delle lingue indoeuropee, per i controlli di direzione: una parola non deriva da una lingua che discende
# dalla sua (*bʰoln- < longobardo *palla, laudo < italiano lodare sono archi rovesciati). Per gruppo, l'antenato
# immediato; le altre lingue usano l'antenato di CURATE, se c'è.
ROMANZE = {'it', 'fr', 'es', 'pt', 'ro', 'ca', 'oc', 'fro', 'frm', 'pro', 'gl', 'an', 'ast', 'sc', 'scn', 'nap', 'vec',
           'lmo', 'pms', 'lij', 'fur', 'rm', 'lld', 'co', 'egl', 'rgn', 'frp', 'dlm', 'ist', 'roa-opt', 'roa-oit', 'itk',
           'osp', 'roa-ole', 'wa', 'nrf', 'mfe', 'ht'}
GERMANICHE = {'en', 'ang', 'enm', 'sco', 'de', 'gmh', 'goh', 'gsw', 'lb', 'yi', 'nl', 'dum', 'odt', 'osx', 'nds', 'gml',
              'fy', 'ofs', 'lng', 'frk', 'got', 'non', 'is', 'fo', 'sv', 'da', 'no', 'nb', 'nn', 'gmw-pro', 'gmq-pro', 'gme-pro'}
CELTICHE = {'ga', 'sga', 'mga', 'gd', 'gv', 'cy', 'wlm', 'owl', 'br', 'xbm', 'obt', 'kw', 'xtg', 'xcg', 'xce', 'cel-bry-pro'}
SLAVE = {'ru', 'orv', 'uk', 'be', 'pl', 'cs', 'sk', 'sl', 'hr', 'sr', 'sh', 'bg', 'mk', 'cu', 'dsb', 'hsb', 'zlw-pro'}
INDOIRANICHE = {'sa', 'pi', 'pra', 'hi', 'ur', 'bn', 'inc-pro', 'fa', 'pal', 'peo', 'ae', 'xpr', 'ku', 'ps', 'os', 'ira-pro'}
FIGLIE_PIE = {'itc-pro', 'gem-pro', 'grk-pro', 'cel-pro', 'sla-pro', 'bsl-pro', 'bat-pro', 'iir-pro', 'ine-bsl-pro',
              'hyx-pro', 'alb-pro', 'ine-ana-pro', 'ine-toc-pro', 'hy', 'xcl', 'sq', 'hit', 'txb', 'xto', 'lt', 'lv', 'prg'}


def antenato_lingua(c):
    c = base_lingua(c)
    if c in ROMANZE:
        return 'la'
    if c in ('la', 'osc', 'xum', 'xfa', 'itc-ola'):
        return 'itc-pro'
    if c in ('el', 'gkm'):
        return 'grc'
    if c == 'grc':
        return 'grk-pro'
    if c in GERMANICHE:
        return 'gem-pro'
    if c in CELTICHE:
        return 'cel-pro'
    if c in SLAVE:
        return 'sla-pro'
    if c in INDOIRANICHE:
        return 'iir-pro'
    if c in FIGLIE_PIE:
        return 'ine-pro'
    cur = CURATE.get(c)
    return cur[6] if cur and cur[6] != c else None


def forma_ricostruita(l):
    """«radice» per una radice ricostruita (*meh₂-, *(s)ker-), «tema» per un tema con un trattino interno (*meh₂-tu-,
    *wréǵ-ye-), None per il resto. Una radice è la cima della sua famiglia; un tema deriva dalla sua radice."""
    if not l.get('ricostruito') or not l['lemma'].endswith('-'):
        return None
    return 'tema' if '-' in l['lemma'].strip('-') else 'radice'


def discende_da(a, b):
    """La lingua a discende (strettamente) dalla lingua b."""
    b, visti = base_lingua(b), set()
    a = antenato_lingua(a)
    while a and a not in visti:
        if a == b:
            return True
        visti.add(a)
        a = antenato_lingua(a)
    return False


def base_lingua(c):
    if c in BASE:
        return BASE[c]
    if c.startswith('la-') or c in ('la', 'itc-ola'):
        return 'la'
    if c.startswith('grc-'):
        return 'grc'
    return c


def chiave(lingua, termine, omografo=1):
    return f'enwikt:{lingua}:{termine}' + (f':{omografo}' if omografo and omografo != 1 else '')


def esc(v):
    if v is None:
        return r'\N'
    return str(v).replace('\\', '\\\\').replace('\t', ' ').replace('\n', ' ').replace('\r', ' ')


class Importatore:
    def __init__(self):
        self.lessemi = {}            # chiave -> dict
        self.nomi_lingua = defaultdict(Counter)
        self.ipotesi = {}            # chiave -> dict (voci italiane)
        self.relazioni = []          # archi delle voci italiane
        self.intermedi = defaultdict(Counter)   # esito -> Counter((etimo, tipo, conf, forma))
        self.doppioni, self.radici = set(), set()
        self.formazioni_ambigue = set()   # voci formate con un prefisso o da più basi (Εὔβοια = εὐ- + βοῦς)
        self.chiusura = {}           # lingua -> indici delle voci di chiusura
        self.participi = set()       # (lingua, pagina) dei participi citati come etimi
        self.attestazioni = {}       # chiave del lessema -> (anno_da, anno_a, precisione)
        self.intere = set()          # lingue di chiusura importate intere (--intere la,grc), non solo dove le catene arrivano
        self.stat = Counter()

    # ---- lessemi ----
    def lessema(self, lingua, termine, glossa=None, translit=None, pos=None, omografo=1, ident=None):
        lingua = codice_lingua(lingua)
        termine = nome_pagina(lingua, senza_modificatori(termine))
        ric = termine.startswith('*')
        if not ric and lingua in VARIETA_ATTESTATE:
            lingua = VARIETA_ATTESTATE[lingua]
        lemma = termine[1:] if ric else termine
        if not ric and base_lingua(lingua) == 'grc' and lemma and all(c in CIPRIOTA for c in lemma):
            lingua = 'grc-arp'          # sillabario cipriota: greco arcadocipriota, con il suo indice
        k = chiave(lingua, termine.lstrip('*') if not ric else termine, omografo)
        if ident and ric:
            k += '@' + ident            # radici omografe: *(s)ker-@cut e *(s)ker-@turn sono due nodi
        l = self.lessemi.get(k)
        if l is None:
            l = self.lessemi[k] = {'chiave': k, 'lingua': lingua, 'lemma': lemma, 'omografo': omografo, 'ricostruito': ric,
                                   'ident': ident if ric else None,
                                   'translit': translit, 'pos': pos or ('rad.' if lemma.endswith('-') and ric else None),
                                   'glosse': Counter()}
        if glossa:
            l['glosse'][glossa] += 1
        if translit and not l['translit']:
            l['translit'] = translit
        if pos and not l['pos']:
            l['pos'] = pos
        return k

    def chiave_di(self, lingua, termine):
        """La chiave che lessema() darebbe a questo termine, senza crearlo."""
        lingua = codice_lingua(lingua)
        termine = nome_pagina(lingua, termine)
        if not termine.startswith('*') and lingua in VARIETA_ATTESTATE:
            lingua = VARIETA_ATTESTATE[lingua]
        return chiave(lingua, termine)

    def nome_lingua(self, t, termine, mostra):
        codice = codice_lingua(t['a'].get('2'))
        e = t.get('e') or ''
        for pre in PREFISSI_ESPANSIONE:
            if e.startswith(pre):
                e = e[len(pre):]
                break
        for forma in (mostra, termine):
            if forma:
                i = e.find(forma)
                if i > 0:
                    nome = e[:i].strip()
                    if nome and ' and ' not in nome:
                        self.nomi_lingua[codice][nome] += 1
                    return

    # ---- una voce ----
    def voce(self, v, lingua_voce=None, parola=None):
        lingua_voce = lingua_voce or LINGUA
        parola, etimn = parola or v['w'], v.get('en')
        omo = int(etimn) if etimn and str(etimn).isdigit() else 1
        testo = v.get('t') or ''
        pos = POS.get(v.get('p'))
        if v.get('p') == 'noun':
            g = ((v.get('h') or [{}])[0].get('a') or {}).get('1', '')
            pos = 's.m.' if g.startswith('m') and 'f' not in g else 's.f.' if g.startswith('f') and 'm' not in g else 's.'
        glossa = (v.get('g') or [None])[0]
        k0 = self.lessema(lingua_voce, parola, glossa=glossa[:200] if glossa else None, pos=pos, omografo=omo)
        if k0 in self.ipotesi:          # stessa etimologia, altra parte del discorso
            self.stat['voci_duplicate'] += 1
            return
        self.stat['voci'] += 1
        tpl, visti = [], set()
        for t in v['tpl']:              # via i duplicati consecutivi (inh + inh+)
            a = t['a']
            if t['n'] in CATENA:
                firma = (a.get('2'), a.get('3'))
                if firma in visti:
                    continue
                visti.add(firma)
            tpl.append(t)
        cursore, archi, origine, ordine = 0, [], 'etimo', 0
        nudo = re.sub(r'[“"‘][^”"’]*[”"’]', ' ', testo)          # le glosse tra virgolette non sono dubbi
        while re.search(r'\([^()]*\)', nudo):
            nudo = re.sub(r'\([^()]*\)', ' ', nudo)
        conf_voce = 1 if DUBBIO_FORTE.search(nudo[:60]) else 2 if DUBBIO.search(nudo[:40]) else 3
        prec = k0
        catena_attiva = True
        primo = True
        for t in tpl:
            n, a, e = t['n'], t['a'], t.get('e') or ''
            pos_t = testo.find(e, cursore) if e else -1
            connettore = testo[cursore:pos_t] if pos_t >= 0 else ''
            # un inciso tra parentesi chiuse dentro il connettore non è un'interruzione: «from *gʷous
            # (compare Mycenaean qo-o), from *gʷṓws». Un etimo dentro le parentesi spezzerebbe il connettore
            # in due, quindi una parentesi chiusa qui contiene solo confronti e spiegazioni
            while True:
                senza = re.sub(r'\([^()]*\)', ' ', connettore)
                if senza == connettore:
                    break
                connettore = senza
            if pos_t >= 0:
                cursore = pos_t + len(e)
            if n in ('doublet', 'dbt'):
                for x in [a.get(str(i)) for i in range(2, 8)]:
                    if x:
                        self.doppioni.add((k0, chiave(codice_lingua(a.get('1')) or lingua_voce, nome_pagina(lingua_voce, pulisci_parte(x)[0]))))
                continue
            if n == 'root':
                for i in range(3, 6):
                    x = a.get(str(i))
                    if x and a.get('2'):
                        ident = (a.get(f'id{i - 2}') or (a.get('id') if i == 3 else '') or '').strip() or None
                        self.radici.add((k0, self.lessema(codice_lingua(a['2']), pulisci_parte(x)[0], ident=ident)))
                continue
            if n == 'etydate':
                d = data_etydate(a)
                if d and k0 not in self.attestazioni:
                    self.attestazioni[k0] = d
                continue
            if n in ('onom', 'onomatopoeic'):
                origine = 'onomatopea'; continue
            if n in ('unk', 'unc'):
                conf_voce = 1
                if n == 'unk':
                    origine = 'ignota'
                continue
            if not catena_attiva:
                continue
            if n in AFFISSI:
                if not primo:
                    catena_attiva = False
                    continue
                parti = self.parti_affissi(n, a)
                basi = [p for p, _ in parti if not p.startswith('-') and not p.endswith('-')]
                if any(p.endswith('-') and not p.startswith('-') for p, _ in parti) or len(basi) >= 2:
                    self.formazioni_ambigue.add(k0)
                basi = [p for p in parti if not (p[0].startswith('-') or p[0].endswith('-'))]
                affissi = [p[0] for p in parti if p[0].startswith('-') or p[0].endswith('-')]
                if not basi and len(parti) >= 2:
                    basi, affissi = parti, []        # fotografia = foto- + -grafia: i due elementi sono gli etimi
                    self.stat['composti_di_elementi'] += 1
                if not basi:
                    self.stat['solo_affissi'] += 1
                    catena_attiva = False
                    continue
                tipo = 'derivazione' if len(basi) == 1 else 'composizione'
                for i, (b, lb) in enumerate(basi, 1):
                    kb = self.lessema(lb or codice_lingua(a.get('1')) or lingua_voce, b)
                    if kb != k0:
                        archi.append({'etimo': kb, 'esito': k0, 'tipo': tipo, 'ordine': i,
                                      'affisso': ' '.join(affissi) or None, 'conf': 3, 'forma': None})
                primo = False
                prec = None             # la catena non prosegue oltre l'analisi in affissi
                continue
            if n == 'it-deverbal':
                b = (a.get('1') or '').strip()
                if b and primo:
                    m = re.search(r'\+ (-\w+)', e)
                    archi.append({'etimo': self.lessema(lingua_voce, b), 'esito': k0, 'tipo': 'derivazione', 'ordine': 1,
                                  'affisso': m.group(1) if m else None, 'conf': 3, 'forma': None})
                    primo, prec = False, self.lessema(lingua_voce, b)
                continue
            if n in LOCALI:
                b, lb = pulisci_parte(a.get('2') or '')
                if b and primo:
                    kb = self.lessema(lb or codice_lingua(a.get('1')) or lingua_voce, b)
                    archi.append({'etimo': kb, 'esito': k0, 'tipo': LOCALI[n], 'ordine': 1, 'affisso': None, 'conf': 3, 'forma': None})
                    primo, prec = False, kb
                continue
            if n in CATENA:
                lingua, termine = codice_lingua(a.get('2')), (a.get('3') or '').strip()
                if not termine:
                    termine = (a.get('4') or '').strip()     # {{inh|it|la-vul||*terraceus}}: forma senza pagina
                if not lingua or not termine or termine == '-':
                    continue
                termine = pulisci_parte(termine)[0]
                if ',' in termine:
                    # sintassi recente: più forme nello stesso template («ἀββα,ἀββᾶς»); vale quella già nota
                    parti = [x.strip() for x in termine.split(',') if x.strip()]
                    termine = next((x for x in parti if self.chiave_di(lingua, x) in self.lessemi), parti[0]) if parti else ''
                    self.stat['termini_multipli'] += 1
                    if not termine:
                        continue
                if '/' in termine or re.match(r'^[A-Z][a-z]+:', termine):
                    self.stat['termini_spuri'] += 1       # «i/languages A to L»: link interni di Wiktionary
                    continue
                testa = (v.get('w') or '').strip()
                voce_affisso = testa.startswith('-') or testa.endswith('-')
                if not termine.startswith('*') and (termine.startswith('-') or termine.endswith('-')) and not voce_affisso:
                    self.stat['affissi_in_catena'] += 1   # «ex-» non è una parola: un affisso resta testo
                    continue
                mostra = (a.get('4') or a.get('alt') or '').strip() or None
                if mostra and ',' in mostra:
                    mostra = None
                glossa_t = (a.get('5') or a.get('t') or a.get('gloss') or '').replace('”, “', ', ').strip() or None
                tr = (a.get('tr') or '').strip() or None
                if tr and ',' in tr:
                    tr = None
                if not tr and mostra is None and re.search(r'[^\x00-\u024f]', termine):
                    m = re.search(re.escape(termine) + r' \(([^,“”()]+)', e)
                    tr = m.group(1).strip() if m else None
                self.nome_lingua(t, termine, mostra)
                lingua, termine, omo_t, forma_extra = self.risolvi(lingua, termine, mostra)
                mostra = mostra or forma_extra
                kt = self.lessema(lingua, termine, glossa=glossa_t, translit=tr, omografo=omo_t, ident=(a.get('id') or '').strip() or None)
                tipo = CATENA[n]
                # der resta indeterminato anche al primo livello: Wiktionary lo usa sia per la stessa parola
                # per via non precisata sia per le derivazioni («from Latin vertō» per il composto verticollo)
                if termine.endswith('-'):
                    tipo = 'derivazione'        # una radice non è una parola
                if ELEMENTI.search(connettore):
                    self.stat['catene_ferme_agli_elementi'] += 1
                    catena_attiva = False
                    continue
                conf = 1 if DUBBIO_FORTE.search(connettore) else 2 if DUBBIO.search(connettore) else 3
                if primo and re.search(r'\bor\b', connettore, re.I):
                    conf = min(conf, 2)         # «From terra, or from Vulgar Latin *terraceus»: è un'alternativa
                    self.stat['primi_anelli_alternativi'] += 1
                if primo:
                    if kt != k0:
                        archi.append({'etimo': kt, 'esito': k0, 'tipo': tipo, 'ordine': 1, 'affisso': None,
                                      'conf': min(conf, conf_voce), 'forma': mostra})
                    primo, prec = False, kt
                    continue
                if prec is None or INTERROMPE.search(connettore) or not PROSEGUE.search(connettore):
                    self.stat['catene_interrotte'] += 1
                    catena_attiva = False
                    continue
                if prec in self.lessemi and tipo in TRASMISSIONE and \
                        base_lingua(self.lessemi[prec]['lingua']) == base_lingua(self.lessemi[kt]['lingua']) and \
                        norm(self.lessemi[prec]['lemma']) != norm(self.lessemi[kt]['lemma']):
                    tipo = 'generico'          # due parole diverse della stessa lingua: non è la stessa parola
                    self.stat['trasmissioni_declassate'] += 1
                if tipo == 'eredita' and prec in self.lessemi:
                    lp, lt = self.lessemi[prec], self.lessemi[kt]
                    np_, nt = norm(lp['lemma']), norm(lt['lemma'])
                    if len(nt) >= 3 and np_.startswith(nt[:max(3, len(nt) - 1)]) and len(np_) - len(nt) >= 3:
                        tipo = 'generico'      # terrassa < terra: la forma più recente aggiunge un suffisso, è un derivato
                        self.stat['eredita_declassate_derivati'] += 1
                if kt != prec:
                    self.intermedi[prec][(kt, tipo, conf, mostra)] += 1
                    self.stat['anelli_intermedi'] += 1
                prec = kt
        if k0 not in self.attestazioni:
            d = data_prosa(testo)
            if d:
                self.attestazioni[k0] = d
                self.stat['date_dalla_prosa'] += 1
        conf = min([x['conf'] for x in archi] + [conf_voce]) if archi else conf_voce
        if not archi and origine == 'etimo':
            if conf_voce == 1:
                origine = 'ignota'
            else:
                self.stat['senza_archi'] += 1
                return
        self.ipotesi[k0] = {'chiave': k0 + '#wikt', 'esito': k0, 'etichetta': 'Wiktionary',
                            'stato': 'accolta' if conf >= 3 else 'alternativa', 'confidenza': conf, 'origine': origine,
                            'nota': testo[:1200] or None}
        for i, x in enumerate(archi):
            x['ipotesi'] = k0 + '#wikt'
            x['chiave'] = f'{k0}#wikt#{i}'
            self.relazioni.append(x)

    # ---- chiusura delle catene: le voci delle lingue intermedie ----
    def carica_chiusura(self, lingua, lemmi, forme=None, glosse=None):
        """Indici di una lingua di chiusura, da caricare prima delle voci principali."""
        voci = [json.loads(r) for r in open(lemmi, encoding='utf-8')]
        idx = {'voci': voci, 'lemmi': set(), 'omografi': defaultdict(list), 'forme': {}, 'participi': {}, 'flesse': {},
               'file_glosse': glosse}
        forme_omografi = defaultdict(dict)
        if glosse and os.path.exists(glosse):
            # tutti i lemmi, anche senza etimologia: pugnō è un lemma, non il dativo di pugnus
            for riga in open(glosse, encoding='utf-8'):
                c = riga.rstrip('\n').split('\t') + ['', '', '', '', '']
                pagina = nome_pagina(lingua, c[0])
                idx['lemmi'].add(pagina)
                omo = int(c[1]) if c[1].isdigit() else 1
                forme_omografi[pagina].setdefault(omo, set()).update(
                    unicodedata.normalize('NFC', x.lower()) for x in c[4].split(',') if x)
        per_pagina = defaultdict(set)
        for v in voci:
            pagina = nome_pagina(lingua, v['w'])
            idx['lemmi'].add(pagina)
            etimn = v.get('en')
            omo = int(etimn) if etimn and str(etimn).isdigit() else 1
            if omo not in per_pagina[pagina]:
                per_pagina[pagina].add(omo)
                idx['omografi'][pagina].append((omo, {unicodedata.normalize('NFC', (v.get('c') or '').lower())}))
        # omografi: per ogni pagina con più etimologie, le forme che le distinguono (canonica, infinito, genitivo)
        for pagina, per_omo in forme_omografi.items():
            if len(per_omo) > 1:
                idx['omografi'][pagina] = [(o, f) for o, f in sorted(per_omo.items())]
        idx['omografi'] = {p: c for p, c in idx['omografi'].items() if len(c) > 1}
        if forme and os.path.exists(forme):
            migliori = {}
            for riga in open(forme, encoding='utf-8'):
                f, l, etichette = (riga.rstrip('\n').split('\t') + ['', ''])[:3]
                pf, pl = nome_pagina(lingua, f), nome_pagina(lingua, l)
                if not pf or not pl or pf == pl or pf in idx['lemmi']:
                    continue
                et = set(etichette.split(','))
                # solo le forme di citazione sono la parola stessa (noctem è nox); educere è sia congiuntivo di
                # ēducō sia infinito di ēdūcō: vince la forma di citazione
                if NON_FINITE & et:
                    rango = 3                            # apertus, fortissimus: parole a sé, derivate
                elif 'infinitive' in et:
                    rango = 0
                elif ('accusative' in et or 'nominative' in et) and 'plural' not in et:
                    rango = 1 if 'accusative' in et else 2
                else:
                    rango = 4                            # illōrum: un'altra forma di ille, non ille
                if pf not in migliori or rango < migliori[pf][0]:
                    migliori[pf] = (rango, l)
            for pf, (rango, l) in migliori.items():
                dove = 'forme' if rango <= 2 else 'participi' if rango == 3 else 'flesse'
                idx[dove][pf] = l                        # il lemma conserva i macron (ēdūcō)
        self.chiusura[lingua] = idx
        self.stat[f'chiusura_{lingua}_voci_disponibili'] = len(voci)

    def risolvi(self, lingua, termine, mostra):
        """Lingua, pagina e omografo di un etimo citato; più la forma da conservare come citata."""
        lingua = codice_lingua(lingua)
        ric = termine.startswith('*')
        if not ric and lingua in VARIETA_ATTESTATE:
            lingua = VARIETA_ATTESTATE[lingua]
        idx = self.chiusura.get(lingua)
        if not idx or ric:
            return lingua, termine, 1, None
        originale = termine
        pagina = nome_pagina(lingua, termine)
        forma_extra = None
        lemma_macron = None
        if pagina not in idx['lemmi'] and pagina in idx['forme']:
            lemma_macron = idx['forme'][pagina]
            pagina = nome_pagina(lingua, lemma_macron)   # noctem → nox: la forma flessa resta come forma citata
            forma_extra = originale
            self.stat[f'forme_ricondotte_al_lemma_{lingua}'] += 1
        elif pagina not in idx['lemmi'] and pagina in idx['participi']:
            self.participi.add((lingua, pagina, 'participi'))
        elif pagina not in idx['lemmi'] and pagina in idx['flesse']:
            self.participi.add((lingua, pagina, 'flesse'))
        omo = 1
        if pagina in idx['omografi']:
            cercate = {unicodedata.normalize('NFC', x.lower().lstrip('*')) for x in (originale, mostra, lemma_macron) if x}
            punti = [(len(forme & cercate), o) for o, forme in idx['omografi'][pagina]]
            migliore = max(punti)[0] if punti else 0
            scelti = sorted(o for p_, o in punti if p_ == migliore and p_ > 0)
            if scelti:
                omo = scelti[0]                 # a parità vince l'etimologia principale, la prima                 # mālum «mela», non malum «male»; fundere, non fundāre
                self.stat[f'omografi_distinti_{lingua}'] += 1
        return lingua, pagina, omo, forma_extra

    def chiudi(self, passi=1):
        """Importa le etimologie delle voci intermedie già presenti nel dizionario. Nelle lingue intere (--intere)
        il primo passaggio prende anche le voci attestate che nessuna catena raggiunge (lēvir, δαήρ): così le
        famiglie delle radici si completano. Le forme ricostruite entrano solo se una catena le cita."""
        fatte = set()
        for passo in range(passi):
            nuove = 0
            for lingua, idx in self.chiusura.items():
                intera = passo == 0 and lingua in self.intere
                for i, v in enumerate(idx['voci']):
                    if (lingua, i) in fatte:
                        continue
                    pagina = nome_pagina(lingua, v['w'])
                    etimn = v.get('en')
                    omo = int(etimn) if etimn and str(etimn).isdigit() else 1
                    if v.get('rec'):
                        candidati = [(c, '*' + pagina) for c in ((lingua + '-vul', lingua) if lingua == 'la' else (lingua,))]
                    else:
                        candidati = [(lingua, pagina)]
                    for lc, termine in candidati:
                        raggiunta = chiave(lc, termine, omo) in self.lessemi
                        if raggiunta or (intera and not v.get('rec')):
                            fatte.add((lingua, i))
                            self.voce(v, lingua_voce=lc, parola=termine)
                            nuove += 1
                            if not raggiunta:
                                self.stat[f'intere_{lingua}'] += 1
                            break
            self.stat[f'chiusura_passo_{passo + 1}'] = nuove
            if not nuove:
                break


    def togli_non_validi(self):
        """Le voci che non sono parole (lemma_valido) escono, con gli archi che le toccano; un'ipotesi che resta senza
        archi esce anch'essa: meglio nessuna etimologia che una catena attraverso un frammento di testo."""
        via = {k for k, l in self.lessemi.items() if not lemma_valido(l['lingua'], l['lemma'], l['ricostruito'])}
        self.togli(via, 'ipotesi_tolte_non_valide')
        self.stat['voci_non_valide'] = len(via)

    def togli(self, via, conto):
        """Toglie le voci in via, gli archi che le toccano e le ipotesi rimaste senza archi."""
        for k in via:
            del self.lessemi[k]
        prima = Counter(r['ipotesi'] for r in self.relazioni)
        self.relazioni = [r for r in self.relazioni if r['etimo'] not in via and r['esito'] not in via]
        dopo = Counter(r['ipotesi'] for r in self.relazioni)
        tolte = {h['chiave'] for h in self.ipotesi.values()
                 if h['esito'] in via or (prima[h['chiave']] and not dopo[h['chiave']])}
        self.ipotesi = {k: h for k, h in self.ipotesi.items() if h['chiave'] not in tolte}
        self.relazioni = [r for r in self.relazioni if r['ipotesi'] not in tolte]
        self.radici = {x for x in self.radici if x[0] not in via and x[1] not in via}
        self.doppioni = {x for x in self.doppioni if x[0] not in via and x[1] not in via}
        self.attestazioni = {k: v for k, v in self.attestazioni.items() if k not in via}
        self.stat[conto] += len(tolte)

    def aggiungi_lemmi_interi(self):
        """Nelle lingue intere entrano anche i lemmi senza etimologia, con glossa e parte del discorso: la lingua è
        completa, non solo le sue famiglie. Le forme ricostruite (sesta colonna di glosse.tsv) restano fuori."""
        for lingua in sorted(self.intere):
            percorso = (self.chiusura.get(lingua) or {}).get('file_glosse')
            if not percorso or not os.path.exists(percorso):
                continue
            for riga in open(percorso, encoding='utf-8'):
                c = riga.rstrip('\n').split('\t') + ['', '', '', '', '', '']
                parola, etimn, pos, glossa, ricostruita = c[0], c[1], c[2], c[3], c[5]
                if not parola or ricostruita == '1' or parola.startswith('*'):
                    continue
                omo = int(etimn) if etimn.isdigit() else 1
                pagina = nome_pagina(lingua, parola)
                if chiave(lingua, pagina, omo) in self.lessemi:
                    continue
                self.lessema(lingua, pagina, glossa=glossa[:200] if glossa else None,
                             pos=POS.get(pos) or ('s.' if pos == 'noun' else None), omografo=omo)
                self.stat[f'lemmi_interi_{lingua}'] += 1

    def collega_participi(self):
        """Le forme citate come etimi si legano al loro lemma: il participio (aperto < apertus < aperiō) per
        derivazione, le altre forme flesse (loro < illōrum < ille) con un legame indeterminato."""
        for lingua, pagina, dove in sorted(self.participi):
            k = chiave(lingua, pagina)
            if k not in self.lessemi or k in self.ipotesi:
                continue
            verbo = self.chiusura[lingua][dove][pagina]
            _, pv, omo_v, _ = self.risolvi(lingua, verbo, None)
            kv = self.lessema(lingua, pv, omografo=omo_v)
            if kv == k:
                continue
            kh = k + '#wikt'
            self.ipotesi[k] = {'chiave': kh, 'esito': k, 'etichetta': 'Wiktionary', 'stato': 'accolta', 'confidenza': 3,
                               'origine': 'etimo', 'nota': None}
            self.relazioni.append({'chiave': kh + '#0', 'ipotesi': kh, 'etimo': kv, 'esito': k,
                                   'tipo': 'derivazione' if dove == 'participi' else 'generico',
                                   'ordine': 1, 'affisso': None, 'conf': 3, 'forma': None})
            self.stat[f'{dove}_collegati_al_lemma_{lingua}'] += 1

    def parti_affissi(self, n, a):
        num = sorted((int(k), v) for k, v in a.items() if k.isdigit() and int(k) >= 2 and v)
        parti = [pulisci_parte(v) for _, v in num]
        lingue_parti = {int(k[4:]): v for k, v in a.items() if k.startswith('lang') and k[4:].isdigit()}
        parti = [(p, l or lingue_parti.get(i + 1)) for i, (p, l) in enumerate(parti)]
        if n == 'prefix' and parti:
            parti = [(parti[0][0].rstrip('-') + '-', None)] + parti[1:]
        elif n == 'suffix' and len(parti) >= 2:
            parti = parti[:-1] + [('-' + parti[-1][0].lstrip('-'), None)]
        elif n == 'confix' and len(parti) >= 2:
            parti = [(parti[0][0].rstrip('-') + '-', None)] + parti[1:-1] + [('-' + parti[-1][0].lstrip('-'), None)]
        return [(p, l) for p, l in parti if p]

    # ---- etimi intermedi: vince la spiegazione più frequente ----
    def arco_impossibile(self, etimo, esito):
        """Il motivo per cui un arco etimo → esito non può stare, o None. Una radice ricostruita è la cima della sua
        famiglia: non ha etimi automatici (*steh₂- < *stnéh₂ti mette la radice sotto un suo derivato). Una parola non
        deriva da una lingua che discende dalla sua (*bʰoln- < longobardo *palla)."""
        le, lx = self.lessemi.get(etimo), self.lessemi.get(esito)
        if not le or not lx:
            return None
        if forma_ricostruita(lx) == 'radice':
            return 'radice_con_un_etimo'
        if forma_ricostruita(lx) == 'tema' and (forma_ricostruita(le) != 'radice' or base_lingua(le['lingua']) != base_lingua(lx['lingua'])):
            return 'tema_da_una_non_radice'      # *meh₂-tu- viene da *meh₂-, non da una parola o da un altro tema
        if discende_da(le['lingua'], lx['lingua']):
            return 'etimo_in_una_lingua_figlia'
        return None

    def risolvi_intermedi(self):
        for esito, conta in self.intermedi.items():
            if esito in self.ipotesi:     # la voce ha già una sua etimologia
                continue
            # gli anelli impossibili non si offrono nemmeno come alternative
            for c in [c for c in conta if self.arco_impossibile(c[0], esito)]:
                self.stat[f'intermedi_scartati_{self.arco_impossibile(c[0], esito)}'] += 1
                del conta[c]
            if not conta:
                continue
            # tra due candidati vince il più vicino: se *rēks discende da *h₃rḗǵs, per rēx l'etimo è *rēks
            # anche quando più voci saltano il passaggio intermedio
            candidati = {c[0] for c in conta}
            def piu_vicino(voce):
                (etimo, _, _, _), _ = voce
                return any(e2 in candidati for (e2, _, _, _) in self.intermedi.get(etimo, {}))
            ordinati = sorted(conta.items(), key=lambda v: (not piu_vicino(v), -v[1]))
            for rango, ((etimo, tipo, conf, forma), freq) in enumerate(ordinati[:3]):
                kh = esito + ('#wikt' if rango == 0 else f'#wikt-alt{rango}')
                self.ipotesi[kh] = {'chiave': kh, 'esito': esito, 'etichetta': 'Wiktionary' if rango == 0 else f'Wiktionary (alternativa {rango})',
                                    'stato': 'accolta' if rango == 0 and conf >= 3 else 'alternativa',
                                    'confidenza': conf if rango == 0 else min(conf, 2), 'origine': 'etimo', 'nota': None}
                self.relazioni.append({'chiave': kh + '#0', 'ipotesi': kh, 'etimo': etimo, 'esito': esito, 'tipo': tipo,
                                       'ordine': 1, 'affisso': None, 'conf': conf, 'forma': forma})
            if len(conta) > 1:
                self.stat['intermedi_con_alternative'] += 1

    # ---- radici omografe: dal nodo generico alla radice precisa ----
    def precisa_omografe(self):
        """carne < caro < *karō < *(s)ker-: Wiktionary cita la radice senza dire quale delle omografe (*(s)ker-
        «tagliare», «girare»), e il nodo generico mescola famiglie diverse. Se le parole sotto un arco verso il nodo
        generico dichiarano tutte la stessa omografa ({{root}}: *(s)ker-@cut), l'arco passa a quella; se ne dichiarano
        di diverse, resta com'è."""
        varianti = defaultdict(set)
        for k in self.lessemi:
            if '@' in k:
                varianti[k.split('@', 1)[0]].add(k)
        if not varianti:
            return
        accolte = {h['esito']: h['chiave'] for h in self.ipotesi.values() if h['stato'] == 'accolta'}
        primo = {}
        for r in self.relazioni:
            if r['ordine'] == 1 and accolte.get(r['esito']) == r['ipotesi']:
                primo.setdefault(r['esito'], r)
        voti, archi = defaultdict(Counter), {}
        for parola, radice in self.radici:
            generica = radice.split('@', 1)[0]
            if radice not in varianti.get(generica, ()):
                continue
            k, visti = parola, {parola}
            while k in primo:
                r = primo[k]
                if r['etimo'] == generica:
                    voti[id(r)][radice] += 1
                    archi[id(r)] = r
                    break
                if r['etimo'] in visti:
                    break
                k = r['etimo']
                visti.add(k)
        for rid, conta in voti.items():
            if len(conta) == 1:
                archi[rid]['etimo'] = next(iter(conta))
                self.stat['omografe_precisate'] += 1
            else:
                self.stat['omografe_ambigue'] += 1

    def togli_archi_impossibili(self):
        """Ultimo controllo su tutti gli archi (arco_impossibile): quelli che non possono stare escono, e con loro le
        ipotesi rimaste senza archi; un'alternativa, se c'è, viene promossa alla scrittura."""
        via = set()
        for r in self.relazioni:
            motivo = self.arco_impossibile(r['etimo'], r['esito'])
            if motivo:
                via.add(id(r))
                self.stat[f'archi_tolti_{motivo}'] += 1
        if not via:
            return
        prima = Counter(r['ipotesi'] for r in self.relazioni)
        self.relazioni = [r for r in self.relazioni if id(r) not in via]
        dopo = Counter(r['ipotesi'] for r in self.relazioni)
        tolte = {h['chiave'] for h in self.ipotesi.values() if prima[h['chiave']] and not dopo[h['chiave']]}
        self.ipotesi = {k: h for k, h in self.ipotesi.items() if h['chiave'] not in tolte}
        self.stat['ipotesi_tolte_archi_impossibili'] += len(tolte)

    # ---- radici dichiarate: la catena si chiude in cima con un legame indeterminato ----
    def chiudi_su_radici(self):
        accolte = {h['esito']: h['chiave'] for h in self.ipotesi.values() if h['stato'] == 'accolta'}
        primo_etimo = {}
        for r in self.relazioni:
            if r['ordine'] == 1 and accolte.get(r['esito']) == r['ipotesi']:
                primo_etimo.setdefault(r['esito'], r['etimo'])
        voti = defaultdict(Counter)
        for parola, radice in self.radici:
            cima, visti = parola, {parola}
            while cima in primo_etimo and primo_etimo[cima] not in visti:
                cima = primo_etimo[cima]
                visti.add(cima)
            if radice in visti or cima == radice:
                self.stat['radici_gia_raggiunte'] += 1
                continue
            if visti & self.formazioni_ambigue and cima != parola:
                # Εὔβοια dichiara *h₁es- per il prefisso εὐ-, ma la catena sale per βοῦς: la radice non va in cima
                self.stat['radici_ambigue_non_attaccate'] += 1
                continue
            if cima in accolte or any(h['esito'] == cima for h in self.ipotesi.values() if h['stato'] == 'accolta'):
                continue
            if forma_ricostruita(self.lessemi[cima]) == 'radice':
                self.stat['radici_dichiarate_in_conflitto'] += 1   # una radice non discende da un'altra radice
                continue
            voti[cima][radice] += 1
        for cima, conta in voti.items():
            # *leǵ- e *leǵ-@gather sono la stessa radice: la forma generica conta per l'unica variante precisa
            for r in [r for r in conta if '@' in r]:
                generica = r.split('@', 1)[0]
                if generica in conta and sum(1 for x in conta if x.startswith(generica + '@')) == 1:
                    conta[r] += conta.pop(generica)
            # una maggioranza chiara, o niente: audience dichiara *h₂ew- e *dʰeh₁- (audiō = «mettere nell'orecchio»),
            # e scegliere a caso tra le due ha dato ad audientia la radice di «porre»
            (radice, n1), *resto = conta.most_common()
            if resto and n1 < 2 * resto[0][1]:
                self.stat['radici_dichiarate_senza_maggioranza'] += 1
                continue
            kh = cima + '#wikt-radice'
            self.ipotesi[kh] = {'chiave': kh, 'esito': cima, 'etichetta': 'Wiktionary (radice dichiarata)', 'stato': 'accolta',
                                'confidenza': 2, 'origine': 'etimo', 'nota': None}
            self.relazioni.append({'chiave': kh + '#0', 'ipotesi': kh, 'etimo': radice, 'esito': cima, 'tipo': 'generico',
                                   'ordine': 1, 'affisso': None, 'conf': 2, 'forma': None})
            self.stat['catene_chiuse_su_radice'] += 1

    # ---- niente cicli: si toglie l'arco che chiude il ciclo (tipicamente un prestito di ritorno) ----
    def togli_cicli(self):
        figli = defaultdict(list)
        for r in self.relazioni:
            figli[r['etimo']].append(r)
        stato, tolti = {}, set()

        def visita(u):
            pila = [(u, iter(figli.get(u, [])))]
            stato[u] = 1
            while pila:
                nodo, it = pila[-1]
                r = next(it, None)
                if r is None:
                    stato[nodo] = 2
                    pila.pop()
                    continue
                if id(r) in tolti:
                    continue
                w = r['esito']
                if stato.get(w) == 1:
                    tolti.add(id(r))
                elif w not in stato:
                    stato[w] = 1
                    pila.append((w, iter(figli.get(w, []))))
        for u in list(figli):
            if u not in stato:
                visita(u)
        prima = len(self.relazioni)
        self.relazioni = [r for r in self.relazioni if id(r) not in tolti]
        self.stat['archi_tolti_per_cicli'] = prima - len(self.relazioni)

    # ---- uscita ----
    def promuovi_alternative(self):
        """Una parola che ha solo alternative (etimologie dubbie) accoglie la più sicura: resta la sua certezza bassa,
        e il lettore vede l'etimologia con il suo dubbio invece del vuoto."""
        per_esito = defaultdict(list)
        for h in self.ipotesi.values():
            per_esito[h['esito']].append(h)
        for hs in per_esito.values():
            if any(h['stato'] == 'accolta' for h in hs):
                continue
            migliore = max(enumerate(hs), key=lambda x: (x[1]['confidenza'], -x[0]))[1]
            migliore['stato'] = 'accolta'
            self.stat['alternative_promosse'] += 1

    def scrivi(self, cartella):
        self.promuovi_alternative()
        os.makedirs(cartella, exist_ok=True)
        usate = Counter(l['lingua'] for l in self.lessemi.values())
        with open(os.path.join(cartella, 'lingue.tsv'), 'w', encoding='utf-8') as f:
            for c in sorted(usate):
                if c in NOTE:
                    continue
                nome_en = self.nomi_lingua[c].most_common(1)[0][0] if self.nomi_lingua[c] else c
                cur = CURATE.get(c)
                if cur:
                    nit, sit, nen, sen, fam, ramo, ant, var, lat, lon = cur
                else:
                    nome_en = NOMI_MANCANTI.get(c, nome_en)
                    nit, sit, nen, sen, fam, ramo, ant, var, lat, lon = nome_en, c, nome_en, c, None, None, None, None, None, None
                    if c in ALTRE:
                        fam, ramo, var = ALTRE[c]
                    else:
                        pref = c.split('-')[0]
                        if pref in PREFISSO_FAMIGLIA:
                            fam, ramo = PREFISSO_FAMIGLIA[pref]
                        if '-' in c and not c.endswith('-pro') and (pref in usate or pref in NOTE or pref in CURATE):
                            var = pref          # en-US, grc-dor, scn-old, fro-nor: varietà della lingua madre
                        if c in ('oc-pro', 'oc-pro-old'):
                            var = 'oc'
                # ricostruita: -pro su un codice di famiglia (oc-pro è il provenzale, non una protolingua)
                ric = c.endswith('-pro') and len(c.split('-')[0]) >= 3
                f.write('\t'.join(esc(x) for x in (c, nit, sit, nen, sen, fam, ramo, ant, var, 't' if ric else 'f', lat, lon)) + '\n')
        per_radice = defaultdict(set)
        for l in self.lessemi.values():
            if l.get('ident'):
                per_radice[(l['lingua'], l['lemma'])].add(l['ident'])
        for l in self.lessemi.values():
            if l.get('ident'):
                l['omografo'] = 2 + sorted(per_radice[(l['lingua'], l['lemma'])]).index(l['ident'])
        self.stat['radici_omografe_distinte'] = sum(len(v) for v in per_radice.values())
        for l in self.lessemi.values():
            if l.get('ident') and not l['glosse']:
                l['glosse'][l['ident']] += 1          # l'identificativo di Wiktionary è un'indicazione di senso: «cut»
            elif not l.get('ident') and l['ricostruito'] and (l['lingua'], l['lemma']) in per_radice:
                l['glosse'].clear()                   # nodo generico di radici omografe: nessuna glossa indovinata
        with open(os.path.join(cartella, 'lessemi.tsv'), 'w', encoding='utf-8') as f:
            for l in self.lessemi.values():
                g = l['glosse'].most_common(1)[0][0] if l['glosse'] else None
                tr = l['translit']
                if not tr and base_lingua(l['lingua']) == 'grc' and GRECO.search(l['lemma']):
                    tr = translit_grc(l['lemma'])     # senza tr= di Wiktionary: lo schema di Wiktionary, calcolato qui
                    self.stat['traslitterazioni_greche_calcolate'] += 1
                f.write('\t'.join(esc(x) for x in (l['chiave'], l['lingua'], l['lemma'], l['omografo'], 't' if l['ricostruito'] else 'f',
                                                   tr, l['pos'], g)) + '\n')
        with open(os.path.join(cartella, 'ipotesi.tsv'), 'w', encoding='utf-8') as f:
            for h in self.ipotesi.values():
                f.write('\t'.join(esc(x) for x in (h['chiave'], h['esito'], h['etichetta'], h['stato'], h['confidenza'], h['origine'], h['nota'])) + '\n')
        with open(os.path.join(cartella, 'relazioni.tsv'), 'w', encoding='utf-8') as f:
            for r in self.relazioni:
                f.write('\t'.join(esc(x) for x in (r['chiave'], r['ipotesi'], r['esito'], r['etimo'], r['tipo'], r['ordine'],
                                                   r['forma'], r['affisso'], r['conf'])) + '\n')
        with open(os.path.join(cartella, 'attestazioni.tsv'), 'w', encoding='utf-8') as f:
            for k, (da, a_, prec) in sorted(self.attestazioni.items()):
                f.write('\t'.join(esc(x) for x in (k + '#data', k, da, a_, prec)) + '\n')
        self.stat['attestazioni'] = len(self.attestazioni)
        with open(os.path.join(cartella, 'doppioni.tsv'), 'w', encoding='utf-8') as f:
            for a, b in sorted(self.doppioni):
                f.write(f'{esc(a)}\t{esc(b)}\n')
        with open(os.path.join(cartella, 'radici.tsv'), 'w', encoding='utf-8') as f:
            for a, b in sorted(self.radici):
                f.write(f'{esc(a)}\t{esc(b)}\n')
        self.stat.update({'lessemi': len(self.lessemi), 'ipotesi': len(self.ipotesi), 'relazioni': len(self.relazioni),
                          'lingue': len(usate), 'doppioni_dichiarati': len(self.doppioni), 'radici_dichiarate': len(self.radici)})
        json.dump(dict(self.stat), open(os.path.join(cartella, 'rapporto_parser.json'), 'w'), indent=1)
        return self.stat


def completa_glosse(imp, percorso, lingua=None):
    lingua = lingua or LINGUA
    """Glosse dei lemmi italiani senza etimologia: servono alle basi delle derivazioni (virus in retrovirus)."""
    gl = {}
    for riga in open(percorso, encoding='utf-8'):
        parola, etimn, pos, g = (riga.rstrip('\n').split('\t') + ['', '', '', ''])[:4]
        omo = int(etimn) if etimn.isdigit() else 1
        if g:
            gl.setdefault(chiave(lingua, nome_pagina(lingua, parola), omo), g)
    n = 0
    for k, l in imp.lessemi.items():
        if l['lingua'] == lingua and not l['glosse'] and k in gl:
            l['glosse'][gl[k]] += 1
            n += 1
    imp.stat[f'glosse_completate_{lingua}'] = n


if __name__ == '__main__':
    # wiktionary.py lemmi.jsonl uscita/ [glosse.tsv] [--chiudi la=lemmi.jsonl,glosse.tsv,forme.tsv]… [--passi N]
    #               [--intere la,grc]
    args, chiusure, passi, intere = [], [], 1, set()
    it_ = iter(sys.argv[1:])
    for x in it_:
        if x == '--chiudi':
            chiusure.append(next(it_))
        elif x == '--passi':
            passi = int(next(it_))
        elif x == '--intere':
            intere = {c for c in next(it_).split(',') if c}
        else:
            args.append(x)
    imp = Importatore()
    imp.intere = intere
    for c in chiusure:
        lingua, percorsi = c.split('=', 1)
        p = percorsi.split(',') + ['', '']
        imp.carica_chiusura(lingua, p[0], p[2] or None, p[1] or None)
    for riga in open(args[0], encoding='utf-8'):
        imp.voce(json.loads(riga))
    if len(args) > 2:
        completa_glosse(imp, args[2])
    imp.collega_participi()
    imp.chiudi(passi)
    imp.collega_participi()
    for c in chiusure:
        lingua, percorsi = c.split('=', 1)
        p = percorsi.split(',') + ['', '']
        if p[1]:
            completa_glosse(imp, p[1], lingua)
    imp.risolvi_intermedi()
    imp.precisa_omografe()
    imp.chiudi_su_radici()
    imp.togli_cicli()
    imp.aggiungi_lemmi_interi()
    imp.togli_archi_impossibili()
    imp.togli_non_validi()
    st = imp.scrivi(args[1])
    print(json.dumps(dict(st), indent=1))
