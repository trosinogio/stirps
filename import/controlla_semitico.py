#!/usr/bin/env python3
"""Le parole semitiche e le loro radici: quante arrivano al protosemitico, e che cosa potrebbe portarcele.

Le voci arabe, ebraiche e aramaiche dichiarano la loro radice ({{ar-root}}, {{he-root}}), e radice_semitica() in
filtra.py ne fa un passaggio di derivazione: la catena si ferma lì, a ك ت ب o כ־ת־ב, se la pagina non dà anche un
etimo storico (كَلْب < *kalb-). Due fonti di Wiktionary possono portarla oltre, e qui si misurano prima di usarle:

1. i discendenti dichiarati dalle pagine protosemitiche (*kalb- → Arabic كَلْب, Hebrew כֶּלֶב): per ogni figlio semitico,
   se ha già l'etimo, se l'ha solo dalla radice, se non ne ha; e dove ha un etimo storico, quante volte l'albero concorda;
2. le radici corrispondenti dichiarate dalle pagine delle radici («ש־ל־ם: From Proto-Semitic *š-l-m. Cognate with Arabic
   root س ل م», RADICI_CORRISPONDENTI di filtra.py): quante radici con un etimo protosemitico dichiarano la radice di
   un'altra lingua, e se quella radice c'è e ha già un etimo.

    python3 controlla_semitico.py dati/it/tsv 'dati/*/discendenti.tsv' 'dati/*/radici_corrispondenti.tsv' 'dati/*/membri_radice.tsv'

3. la regola delle radici: una radice senza etimo prende la parola protosemitica da cui eredita una sua parola, se ne
   ha le consonanti nell'ordine (ب ي ت e بَيْت < *bayt-), misurata sulle radici con un etimo dichiarato.
"""
import glob
import os
import re
import sys
import unicodedata
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wiktionary import codice_lingua, nome_pagina      # noqa: E402
from controlla_discendenti import leggi                  # noqa: E402

SEMITICHE = {'ar', 'he', 'hbo', 'arc', 'syc', 'akk', 'uga', 'phn', 'mt', 'am', 'gez', 'tmr', 'jpa'}
PROTO = {'sem-pro', 'sem-wes-pro'}
RADICE = re.compile(r'^\S( \S)+$|^\S(־\S)+$')      # ك ت ب, כ־ת־ב


def main():
    tsv = sys.argv[1]
    lemma, per_pagina = {}, defaultdict(list)
    for c in leggi(os.path.join(tsv, 'lessemi.tsv')):
        lemma[c[0]] = (c[1], c[2])
        per_pagina[(c[1], ('*' if c[4] == 't' and not c[2].startswith('*') else '') + c[2])].append(c[0])
    accolte = {c[0] for c in leggi(os.path.join(tsv, 'ipotesi.tsv')) if c[3] == 'accolta'}
    etimi = defaultdict(set)
    for c in leggi(os.path.join(tsv, 'relazioni.tsv')):
        if c[1] in accolte:
            etimi[c[2]].add(c[3])

    def radice(k):
        return bool(RADICE.match(lemma.get(k, ('', ''))[1]))

    def cima(k):
        visti = {k}
        while True:
            su = sorted(etimi.get(k, set()) - visti)
            if not su:
                return k
            k = su[0]
            visti.add(k)

    def antenati(k):
        visti, giro = set(), {k}
        for _ in range(15):
            giro = {e for x in giro for e in etimi.get(x, ())} - visti
            if not giro:
                break
            visti |= giro
        return visti

    def chiavi(lingua, parola):
        lingua = codice_lingua(lingua)
        parola = parola.strip()
        if lingua.endswith('-pro') and not parola.startswith('*'):
            parola = '*' + parola
        return per_pagina.get((lingua, nome_pagina(lingua, parola)), [])

    # quante parole semitiche arrivano oggi al protosemitico, e dove si fermano
    print('dove si fermano le catene semitiche (lingua della cima, per lingua della parola):')
    for L in ('ar', 'he', 'arc', 'syc', 'akk'):
        ks = [k for k, (l, w) in lemma.items() if l == L and not RADICE.match(w)]
        cime = Counter()
        for k in ks:
            if etimi.get(k):
                c = cima(k)
                cime['radice della lingua' if radice(c) and lemma[c][0] == L else lemma.get(c, ('?',))[0]] += 1
            else:
                cime['senza etimologia'] += 1
        print(f'  {L}: {len(ks)} parole; ' + ', '.join(f'{x} {n}' for x, n in cime.most_common(8)))

    # 1. i discendenti dichiarati dalle pagine protosemitiche
    esiti, per_lingua, esempi = Counter(), defaultdict(Counter), defaultdict(list)
    visti = set()
    for percorso in sorted(glob.glob(sys.argv[2])):
        lingua_pagina = os.path.basename(os.path.dirname(percorso))
        if lingua_pagina not in PROTO:
            continue
        pila, corrente = [], None
        for c in leggi(percorso):
            if len(c) < 7:
                continue
            parola, ric, prof, lf, pf = c[0], c[2], int(c[3] or 1), c[4], c[5]
            if parola != corrente:
                corrente, pila = parola, [(0, lingua_pagina, ('*' if not parola.startswith('*') else '') + parola)]
            while pila and pila[-1][0] >= prof:
                pila.pop()
            if not pila:
                continue
            _, lg, pg = pila[-1]
            if not pf.strip():
                pila.append((prof, lg, pg))
                continue
            pila.append((prof, lf, pf))
            if codice_lingua(lf) not in SEMITICHE or (lg, pg, lf, pf) in visti:
                continue
            visti.add((lg, pg, lf, pf))
            kg, kf = chiavi(lg, pg), chiavi(lf, pf)
            if not kf:
                esito = 'figlio assente'
            elif not kg:
                esito = 'genitore assente'
            else:
                dirette = {e for k in kf for e in etimi.get(k, ())}
                if not dirette:
                    esito = 'senza etimologia'
                elif all(radice(e) for e in dirette):
                    esito = 'solo la radice'
                elif dirette & set(kg) or set(kg) & {a for k in kf for a in antenati(k)}:
                    esito = 'concorde'
                else:
                    esito = 'diverso'
            esiti[esito] += 1
            per_lingua[codice_lingua(lf)][esito] += 1
            if len(esempi[esito]) < 12 and esito in ('solo la radice', 'diverso', 'senza etimologia'):
                ora = ', '.join(sorted(lemma.get(e, ('', e))[1] for k in kf for e in etimi.get(k, ()))[:2])
                esempi[esito].append(f'{lf}:{pf} < {lg}:{pg}' + (f' (ora: {ora})' if ora else ''))
    conc, div = esiti['concorde'], esiti['diverso']
    print(f'discendenti delle pagine protosemitiche: {dict(esiti)}; dove la parola ha un etimo storico l\'albero '
          f'concorda nel {100 * conc / max(1, conc + div):.0f}% su {conc + div}')
    for L, c in sorted(per_lingua.items(), key=lambda x: -sum(x[1].values())):
        print(f'  {L}: {dict(c)}')
    for e, xs in esempi.items():
        print(f'  esempi, {e}: ' + ' · '.join(xs))

    # 2. le radici corrispondenti dichiarate
    corr = []
    for percorso in sorted(glob.glob(sys.argv[3])):
        la = os.path.basename(os.path.dirname(percorso))      # la lingua della pagina della radice
        for c in leggi(percorso):
            if len(c) >= 3:
                corr.append((la, c[0], c[1], c[2]))
    conti, esempi_c = Counter(), []
    for la, ra, lb, rb in dict.fromkeys(corr):
        conti['dichiarate'] += 1
        ka, kb = chiavi(la, ra), chiavi(lb, rb)
        et_a = {e for k in ka for e in etimi.get(k, ())}
        proto_a = {e for e in et_a if lemma.get(e, ('',))[0] in PROTO}
        if not proto_a:
            conti['la radice dichiarante non ha un etimo protosemitico'] += 1
            continue
        conti['con un etimo protosemitico'] += 1
        if not kb:
            conti['… e la radice corrispondente non c\'è'] += 1
            continue
        et_b = {e for k in kb for e in etimi.get(k, ())}
        if not et_b:
            conti['… e la radice corrispondente c\'è, senza etimo: l\'arco nuovo'] += 1
            if len(esempi_c) < 15:
                esempi_c.append(f'{lb}:{rb} < {lemma[sorted(proto_a)[0]][1]} (da {la}:{ra})')
        elif et_b & proto_a:
            conti['… e la radice corrispondente ha già lo stesso etimo'] += 1
        else:
            conti['… e la radice corrispondente ha un altro etimo'] += 1
    print(f'radici corrispondenti dichiarate: {dict(conti)}')
    if esempi_c:
        print('  archi nuovi possibili: ' + ' · '.join(esempi_c))

    # 3. la radice dalla parola protosemitica che una sua parola continua (MEMBRI_RADICE di filtra.py)
    membri = []
    for percorso in sorted(glob.glob(sys.argv[4])) if len(sys.argv) > 4 else []:
        L = os.path.basename(os.path.dirname(percorso))
        for c in leggi(percorso):
            if len(c) >= 3:
                membri.append((L, c[0], c[2]))
    if membri:
        misura_radici(lemma, etimi, chiavi, radice, membri)


# Le consonanti protosemitiche che ogni lettera continua (le corrispondenze regolari: *š > arabo س, ebraico ש;
# *ś > arabo ش; *ṯ > arabo ث, ebraico ש, aramaico ת; *ṣ́ > arabo ض, ebraico צ, aramaico ע; *p > arabo ف)
def _nfd(s):
    return unicodedata.normalize('NFD', s)


_ARABO = {'ء': 'ʔ', 'أ': 'ʔ', 'إ': 'ʔ', 'آ': 'ʔ', 'ؤ': 'ʔ', 'ئ': 'ʔ', 'ا': 'ʔ w y', 'ب': 'b', 'ت': 't', 'ث': 'ṯ', 'ج': 'g',
          'ح': 'ḥ', 'خ': 'ḫ', 'د': 'd', 'ذ': 'ḏ', 'ر': 'r', 'ز': 'z', 'س': 's š', 'ش': 'ś', 'ص': 'ṣ', 'ض': 'ṣ́', 'ط': 'ṭ',
          'ظ': 'ṯ̣', 'ع': 'ʕ', 'غ': 'ġ', 'ف': 'p f', 'ق': 'q ḳ', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h',
          'و': 'w', 'ي': 'y', 'ى': 'y'}
_EBRAICO = {'א': 'ʔ', 'ב': 'b', 'ג': 'g', 'ד': 'd', 'ה': 'h', 'ו': 'w', 'ז': 'z ḏ', 'ח': 'ḥ ḫ', 'ט': 'ṭ', 'י': 'y',
            'כ': 'k', 'ך': 'k', 'ל': 'l', 'מ': 'm', 'ם': 'm', 'נ': 'n', 'ן': 'n', 'ס': 's', 'ע': 'ʕ ġ', 'פ': 'p', 'ף': 'p',
            'צ': 'ṣ ṣ́ ṯ̣', 'ץ': 'ṣ ṣ́ ṯ̣', 'ק': 'q ḳ', 'ר': 'r', 'ש': 'š ś ṯ', 'ת': 't'}
_ARAMAICO = {**_EBRAICO, 'ת': 't ṯ', 'ד': 'd ḏ', 'ט': 'ṭ ṯ̣', 'ע': 'ʕ ġ ṣ́'}
LETTERE = {L: {k: {_nfd(x) for x in v.split()} for k, v in m.items()}
           for L, m in (('ar', _ARABO), ('he', _EBRAICO), ('arc', _ARAMAICO), ('syc', _ARAMAICO))}
VOCALI = set('aeiouəV')


def consonanti_proto(lemma):
    """Le consonanti di una forma protosemitica, in ordine: *bayt- → b y t; *š-l-m → š l m; *ṯ̣urr- → ṯ̣ r r."""
    out, s = [], _nfd(lemma.split('//')[0].replace('ʾ', 'ʔ').replace('ʿ', 'ʕ'))
    s = re.sub(r'\([^)]*\)', '', s)
    i = 0
    while i < len(s):
        ch = s[i]
        j = i + 1
        while j < len(s) and unicodedata.combining(s[j]):
            j += 1
        tok = s[i:j]
        if ch.isalpha() or ch in 'ʔʕ':
            if ch not in VOCALI:
                out.append(tok)
        i = j
    return out


def consonanti_radice(lingua, radice):
    lettere = LETTERE.get(lingua)
    if not lettere:
        return None
    segni = [c for c in _nfd(radice) if not unicodedata.combining(c) and c not in ' ־-']
    return [lettere.get(c) for c in segni] if all(c in lettere for c in segni) else None


def ha_le_consonanti(lingua, radice, proto):
    r, p = consonanti_radice(lingua, radice), consonanti_proto(proto)
    return bool(r) and len(r) == len(p) and all(x in s for x, s in zip(p, r))


def misura_radici(lemma, etimi, chiavi, radice, membri):
    """La regola: una radice prende come etimo la parola protosemitica da cui eredita una sua parola, se ne ha le
    consonanti nell'ordine. Si misura sulle radici che hanno già un etimo protosemitico dichiarato."""
    candidati = defaultdict(set)
    for (L, parola, r) in membri:
        for kr in chiavi(L, r):
            for km in chiavi(L, parola):
                for e in etimi.get(km, ()):
                    if lemma.get(e, ('',))[0] in PROTO and ha_le_consonanti(L, r, lemma[e][1]):
                        candidati[kr].add(e)
    esiti, nuove, esempi = Counter(), Counter(), defaultdict(list)
    for kr, cs in candidati.items():
        L = lemma[kr][0]
        dichiarati = {e for e in etimi.get(kr, ()) if lemma.get(e, ('',))[0] in PROTO}
        if dichiarati:
            esito = ('giusta' if cs == dichiarati else 'giusta tra più candidati' if dichiarati & cs and len(cs) > 1
                     else 'sbagliata')
            esiti[esito] += 1
            if len(esempi[esito]) < 10 and esito != 'giusta':
                esempi[esito].append(f"{L}:{lemma[kr][1]} dichiara {', '.join(lemma[e][1] for e in dichiarati)}, la regola "
                                     f"{', '.join(lemma[e][1] for e in cs)}")
        elif not etimi.get(kr) and len(cs) == 1:
            nuove[L] += 1
            if len(esempi['nuova']) < 20:
                esempi['nuova'].append(f'{L}:{lemma[kr][1]} < {lemma[next(iter(cs))][1]}')
        elif not etimi.get(kr):
            nuove[f'{L} con più candidati'] += 1
    giuste = esiti['giusta']
    print(f"radici e parole protosemitiche: sulle radici con un etimo dichiarato {dict(esiti)}, giusta nel "
          f"{100 * giuste / max(1, sum(esiti.values())):.0f}%; radici senza etimo che lo prenderebbero: {dict(nuove)}")
    for e, xs in esempi.items():
        print(f'  esempi, {e}: ' + ' · '.join(xs))


if __name__ == '__main__':
    main()
