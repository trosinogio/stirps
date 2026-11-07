#!/usr/bin/env python3
"""Analisi della forma: le voci di latino e greco senza etimologia che sono un preverbo (o un prefisso) seguito da una
parola che il dizionario ha già. καταδάπτω = κατα- + δάπτω, συμφώνησις = συμ- + φώνησις, transtollo = trans- + tollo.

È un'analisi di superficie, come il modello {{surf}} di Wiktionary: lega la voce alla famiglia giusta, ma non sempre
per la strada storica (procuratrix viene da procuro, non da pro- + curatrix). Per questo entra come ipotesi «Analisi della
forma», con certezza 2 (possibile) e senza fonte, e solo dove non c'è altro: né un'etimologia di Wiktionary né una dei
dizionari (filtra_perseus.py --etimi). Le storie usano solo passaggi con certezza 3 o 4, e non la seguono.

Regole, per non legare a caso:
- la base è una parola comune (non un nome proprio, non un affisso), di almeno quattro lettere, e l'unica con quella
  forma (in greco senza accenti né spiriti, che nei composti cambiano: ἐφίστημι = ἐφ- + ἵστημι);
- in latino un prefisso assimilato vale solo davanti alla sua consonante (af-fero, col-loco, e-loquor, a-spicio);
- in greco ἀ- privativo solo davanti a consonante (davanti a vocale è ἀν-).

Per il greco anche i suffissi regolari (σκοτίζω = σκότος + -ίζω) e i composti di due parole note con la vocale -ο-
(μοσχομάγειρος = μόσχος + μάγειρος), con le regole di suffisso_o_composto().

Scrive righe nello stesso formato di filtra_perseus.py --etimi, con opera «analisi» e la chiave della voce:

    python3 analisi_composti.py etimi.tsv lessemi.tsv dizionari.tsv ipotesi.tsv     (aggiunge le righe a etimi.tsv)
"""
import sys, unicodedata
from collections import Counter, defaultdict

GRECI = ('ἀμφι ἀμφ ἀνα ἀντι ἀντ ἀνθ ἀπο ἀπ ἀφ δια δι εἰσ ἐκ ἐξ ἐν ἐμ ἐγ ἐπι ἐπ ἐφ κατα κατ καθ μετα μετ μεθ παρα παρ '
         'περι προσ προ συν συμ συλ συγ συσ συρ ὑπερ ὑπο ὑπ ὑφ εὐ δυσ ἀρχι αὐτο ἡμι παν παμ πολυ ὁμο φιλο μισο ψευδο ἀν ἀ').split()
# latino: forma → (prefisso, iniziali ammesse della base); None = qualunque
LATINI = {
    'ab': ('ab', None), 'abs': ('ab', 'ct'), 'au': ('ab', 'f'),
    'ad': ('ad', None), 'ac': ('ad', 'cq'), 'af': ('ad', 'f'), 'ag': ('ad', 'g'), 'al': ('ad', 'l'), 'an': ('ad', 'n'),
    'ap': ('ad', 'p'), 'ar': ('ad', 'r'), 'as': ('ad', 's'), 'at': ('ad', 't'),
    'con': ('con', None), 'com': ('con', 'bpm'), 'col': ('con', 'l'), 'cor': ('con', 'r'), 'co': ('con', 'aeiouh'),
    'de': ('de', None), 'dis': ('dis', None), 'di': ('dis', 'dglmnrv'), 'dif': ('dis', 'f'),
    'ex': ('ex', None), 'e': ('ex', 'bdglmnrv'), 'ef': ('ex', 'f'),
    'in': ('in', None), 'im': ('in', 'bpm'), 'il': ('in', 'l'), 'ir': ('in', 'r'),
    'ob': ('ob', None), 'oc': ('ob', 'c'), 'of': ('ob', 'f'), 'op': ('ob', 'p'), 'o': ('ob', 'm'),
    'per': ('per', None), 'prae': ('prae', None), 'pro': ('pro', None), 'prod': ('pro', 'aeiou'),
    're': ('re', None), 'red': ('re', 'aeiouh'),
    'sub': ('sub', None), 'suc': ('sub', 'c'), 'suf': ('sub', 'f'), 'sug': ('sub', 'g'), 'sum': ('sub', 'm'),
    'sup': ('sub', 'p'), 'sur': ('sub', 'r'), 'sus': ('sub', 'cpt'),
    'trans': ('trans', None), 'tra': ('trans', 'din'), 'inter': ('inter', None), 'intel': ('inter', 'l'),
    'circum': ('circum', None), 'super': ('super', None), 'ante': ('ante', None), 'post': ('post', None),
    'se': ('se', None), 'sed': ('se', 'aeiou'), 'contra': ('contra', None), 'praeter': ('praeter', None),
    'intro': ('intro', None),
}
VOCALI_GR = set('αεηιουω')
# greco: i suffissi regolari, con le finali che la base può avere sul suo tema (σκοτίζω = σκότος + -ίζω, σκοτεινότης =
# σκοτεινός + -ότης); il più lungo per primo. Nella forma senza accenti, e come si mostrano
_FIN = ['οσ', 'ον', 'η', 'α', 'ησ', 'υσ', 'ισ', 'ευσ', 'ω', 'εω', 'αω', 'οω', 'ιζω', 'μα', 'ια', 'ιον']
SUFFISSI_GR = sorted([
    ('ικωσ', '-ικῶς', ['ικοσ']), ('ισμοσ', '-ισμός', ['ιζω']), ('ιστησ', '-ιστής', ['ιζω']),
    ('ιδιον', '-ίδιον', ['οσ', 'ον', 'η', 'α', 'ισ']), ('ισκοσ', '-ίσκος', ['οσ', 'ον', 'η', 'α', 'ησ']),
    ('οτησ', '-ότης', ['οσ', 'υσ', 'ησ']), ('ωδησ', '-ώδης', _FIN), ('ικοσ', '-ικός', _FIN), ('ινοσ', '-ινος', ['οσ', 'ον', 'η', 'α']),
    ('ιζω', '-ίζω', ['οσ', 'ον', 'η', 'α', 'ησ']), ('ευω', '-εύω', ['ευσ', 'οσ']), ('ιοσ', '-ιος', _FIN),
    ('ιον', '-ιον', ['οσ', 'ον', 'η', 'α', 'ισ', 'ησ']), ('οω', '-όω', ['οσ', 'ον', 'η', 'α']), ('ια', '-ία', ['οσ', 'ησ', 'ον', 'η', 'α']),
    ('ωσ', '-ως', ['οσ', 'ησ', 'υσ', 'ον'])], key=lambda x: -len(x[0]))


def nudo(w):
    """Senza accenti, spiriti e quantità, in minuscolo: la forma su cui si confrontano i composti greci."""
    return ''.join(c for c in unicodedata.normalize('NFD', w.lower()) if not unicodedata.combining(c)).replace('ς', 'σ')


def leggi(percorso):
    with open(percorso, encoding='utf-8') as f:
        return [r.rstrip('\n').split('\t') for r in f if r.strip()]


def comune(lemma, pos):
    return pos != 'np' and lemma[:1] == lemma[:1].lower() and not lemma.startswith('-') and not lemma.endswith('-')


def suffisso_o_composto(n, lemma, basi):
    """Per una voce greca (n: senza accenti) che non comincia con un prefisso noto: la base e il suffisso (σκοτίζω = σκότος +
    -ίζω), o un composto di due parole note con la vocale di congiunzione -ο- (μοσχομάγειρος = μόσχος + μάγειρος), la
    seconda di almeno cinque lettere e con una consonante iniziale: i composti con elisione o con parole corte, nelle prove,
    sbagliavano una volta su due (ἄκραντος non è ἄκρος + ἄντος)."""
    def unica(forma):
        c = basi.get(('grc', forma), set()) - {lemma}
        return next(iter(c)) if len(c) == 1 else None
    for suf, mostra, finali in SUFFISSI_GR:
        if n.endswith(suf) and len(n) - len(suf) >= 3:
            tema = n[:-len(suf)]
            for f in finali:
                b = unica(tema + f)
                if b:
                    return (b, mostra)
    for k in range(4, len(n) - 4):
        if n[k - 1] != 'ο' or len(n) - k < 5 or n[k] in VOCALI_GR:
            continue
        seconda = unica(n[k:])
        if not seconda or len(n[:k - 1]) < 3:
            continue
        prima = next((unica(n[:k - 1] + f) for f in ('οσ', 'ον', 'η', 'α') if unica(n[:k - 1] + f)), None)
        if prima and prima != seconda:
            return (prima, seconda, 'composto')
    return None


def analizza(voci, coperte):
    """voci: [(chiave, lingua, lemma, pos)]; coperte: le chiavi e i (lingua, lemma) che un'etimologia ce l'hanno.
    Restituisce le righe dell'analisi: (chiave, lingua, lemma, 1, lingua, base, 'derivazione', prefisso, 'analisi')."""
    basi = defaultdict(set)                    # (lingua, forma di confronto) → lemmi
    for k, lingua, lemma, pos in voci:
        if comune(lemma, pos):
            basi[(lingua, nudo(lemma) if lingua == 'grc' else lemma)].add(lemma)
    greci = sorted({(nudo(p), p) for p in GRECI}, key=lambda x: -len(x[0]))
    latini = sorted(LATINI.items(), key=lambda x: -len(x[0]))
    righe, conta = [], Counter()
    for k, lingua, lemma, pos in voci:
        if k in coperte or (lingua, lemma) in coperte or not comune(lemma, pos):
            continue
        trovata = None
        if lingua == 'grc':
            n = nudo(lemma)
            for forma, prefisso in greci:
                resto = n[len(forma):]
                if not n.startswith(forma) or len(resto) < 4:
                    continue
                if prefisso == 'ἀ' and resto[0] in VOCALI_GR:
                    continue
                cand = basi.get(('grc', resto), set()) - {lemma}
                if len(cand) == 1:
                    trovata = (next(iter(cand)), prefisso + '-')
                    break
            if not trovata:
                trovata = suffisso_o_composto(n, lemma, basi)
                if trovata and len(trovata) == 3:            # un composto di due parole: due righe
                    a1, b1, _ = trovata
                    righe.append(('analisi:' + k, lingua, lemma, 1, lingua, a1, 'composizione', None, 'analisi'))
                    righe.append(('analisi:' + k, lingua, lemma, 2, lingua, b1, 'composizione', None, 'analisi'))
                    conta['grc_composti'] += 1
                    continue
        elif lingua == 'la':
            for forma, (prefisso, iniziali) in latini:
                resto = lemma[len(forma):]
                if not lemma.startswith(forma) or len(resto) < 4 or (iniziali and resto[0] not in iniziali):
                    continue
                if (('la', resto) in basi) and resto != lemma:
                    trovata = (resto, prefisso + '-')
                    break
        if trovata:
            righe.append(('analisi:' + k, lingua, lemma, 1, lingua, trovata[0], 'derivazione', trovata[1], 'analisi'))
            conta[lingua] += 1
    return righe, conta


def esc(v):
    return '\\N' if v is None or v == '' else str(v)


if __name__ == '__main__':
    etimi, lessemi, dizionari, ipotesi = sys.argv[1:5]
    voci = [(c[0], c[1], c[2], c[6]) for c in leggi(lessemi) + leggi(dizionari)
            if len(c) > 6 and c[1] in ('la', 'grc') and c[4] != 't']
    accolte = {c[1] for c in leggi(ipotesi) if len(c) > 3 and c[3] == 'accolta'}
    dai_dizionari = {(c[1], c[2]) for c in leggi(etimi)} | {c[0] for c in leggi(etimi)}
    righe, conta = analizza(voci, accolte | dai_dizionari)
    with open(etimi, 'a', encoding='utf-8') as out:
        for r in righe:
            out.write('\t'.join(esc(x) for x in r) + '\n')
    print(f'analisi della forma: {dict(conta)} voci composte di prefisso e base', file=sys.stderr)
