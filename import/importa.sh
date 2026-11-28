#!/usr/bin/env bash
# Import delle etimologie di Wiktionary (via Kaikki) nel database indicato da DATABASE_URL.
#   DATABASE_URL=postgres://… ./importa.sh                                   # italiano, chiuso su latino, francese antico e greco antico
#   LINGUA=fr NOME=French CHIUSURA="la:Latin fro:Old French" DATABASE_URL=… ./importa.sh
#   CHIUSURA="" DATABASE_URL=… ./importa.sh                                  # senza chiusura delle catene
#   WIKIZIONARIO=0 DATABASE_URL=… ./importa.sh                               # senza glosse italiane del Wikizionario
#   INTERE="" DATABASE_URL=… ./importa.sh                                    # latino e greco solo dove le catene arrivano
#   CHIUSURA="… en:English enm:Middle English ang:Old English" CON_ETIMOLOGIA=en ./importa.sh   # anche l'inglese con etimologia
#   DIZIONARI=0 DATABASE_URL=… ./importa.sh                                  # senza i lemmi del Lewis & Short e dell'LSJ
#   SOLO_ANALISI=1 ./importa.sh                                              # si ferma alle tabelle (dati/it/tsv), senza database
# Richiede python3, curl e psql. Lo schema (01–03) e db/05_import_wiktionary.sql devono essere già caricati.
set -euo pipefail
cd "$(dirname "$0")"
export LINGUA=${LINGUA:-it}
NOME=${NOME:-Italian}
CHIUSURA=${CHIUSURA-la:Latin fro:Old French grc:Ancient Greek}
PASSI=${PASSI:-5}   # la chiusura si ripete finché trova voci nuove: βούτυρον → βοῦς → *gʷṓws
WIKIZIONARIO=${WIKIZIONARIO:-1}
INTERE=${INTERE-la,grc}   # lingue di chiusura importate intere: anche le voci che nessuna catena raggiunge
CON_ETIMOLOGIA=${CON_ETIMOLOGIA-}   # lingue di chiusura di cui entrano tutte le voci con un'etimologia (en), senza i lemmi vuoti
ELENCHI=${ELENCHI-}   # per quelle lingue, i soli lemmi ammessi: ELENCHI="en=../dati/frequenze_en.tsv.gz" (il lessico comune)
COMUNI=${COMUNI-}     # nella lingua principale, anche i lemmi senza etimologia del lessico comune: COMUNI="it=../dati/frequenze_it.tsv.gz"
ESTERNI=${ESTERNI-}   # e con l'elenco, anche le voci con l'etimo in un'altra lingua: ESTERNI=en
IN_FAMIGLIA=${IN_FAMIGLIA-}   # e con l'elenco, anche le voci il cui primo etimo è nel pacchetto pubblicato: IN_FAMIGLIA=en (con DERIVATI)
DERIVATI=${DERIVATI-}   # e i derivati trasparenti senza etimologia di una voce che c'è (aeration < aerate): DERIVATI=en
PRECEDENTI=${PRECEDENTI-}   # il lessemi.tsv.gz pubblicato: le glosse non cambiano se sono ancora tra le candidate
SOLO_ANALISI=${SOLO_ANALISI:-0}
DIZIONARI=${DIZIONARI:-1}   # i lemmi del Lewis & Short e dell'LSJ che Wiktionary non ha (Perseus, CC BY-SA 4.0)
PERSEUS=${PERSEUS:-1c34cdf756c63cf37db61bd366d733431dbd7aa0}   # commit di PerseusDL/lexica
DATI=dati/$LINGUA
mkdir -p "$DATI"

scarica() {   # scarica <nome inglese della lingua> : stampa il dump di Kaikki
  local pagina file
  pagina=$(printf '%s' "$1" | sed 's/ /%20/g'); file=$(printf '%s' "$1" | tr -d ' ')
  # Kaikki toglie dal nome del file gli spazi e, per le proto-lingue, anche i trattini (ProtoGermanic)
  curl -sf "https://kaikki.org/dictionary/$pagina/kaikki.org-dictionary-$file.jsonl" \
    || curl -sf "https://kaikki.org/dictionary/$pagina/kaikki.org-dictionary-$(printf '%s' "$file" | tr -d '-').jsonl"
}

echo "1/4  scarico e filtro il dump di Kaikki ($NOME)"
scarica "$NOME" | SENZA="$DATI/senza_etimologia.tsv" FORME="$DATI/forme.tsv" ANALISI="$DATI/forme_analisi.tsv" DISCENDENTI="$DATI/discendenti.tsv" python3 filtra.py "$DATI/lemmi.jsonl" "$DATI/glosse.tsv"
ARGOMENTI=()
MANCANTI=()
for voce in $(printf '%s' "$CHIUSURA" | sed 's/ \([a-z][a-z-]*:\)/\n\1/g' | tr ' ' '~'); do
  codice=${voce%%:*}; nome=$(printf '%s' "${voce#*:}" | tr '~' ' ')
  echo "     chiusura delle catene: $nome"
  mkdir -p "dati/$codice"
  # un dump che Kaikki non ha per lingua (protoellenico, francone…) si cerca dopo nel dump grezzo di tutte le lingue
  if ! scarica "$nome" | LINGUA=$codice FORME="dati/$codice/forme.tsv" VARIANTI="dati/$codice/varianti.tsv" DISCENDENTI="dati/$codice/discendenti.tsv" RADICI_CORRISPONDENTI="dati/$codice/radici_corrispondenti.tsv" MEMBRI_RADICE="dati/$codice/membri_radice.tsv" python3 filtra.py "dati/$codice/lemmi.jsonl" "dati/$codice/glosse.tsv"; then
    MANCANTI+=("$codice")
    continue
  fi
  ARGOMENTI+=(--chiudi "$codice=dati/$codice/lemmi.jsonl,dati/$codice/glosse.tsv,dati/$codice/forme.tsv,dati/$codice/varianti.tsv")
  ARGOMENTI+=(--discendenti "$codice=dati/$codice/discendenti.tsv")
done
if [ ${#MANCANTI[@]} -gt 0 ]; then
  # il dump grezzo di Wiktionary inglese ha tutte le lingue: si scarica una volta, per tutte quelle che mancano, e se ne
  # tengono solo le righe con il loro codice; un dump che manca anche lì è un avviso, e la lingua resta fuori
  echo "     dump mancanti (${MANCANTI[*]}): li cerco nel dump grezzo di tutte le lingue"
  codici=$(printf '%s|' "${MANCANTI[@]}"); codici=${codici%|}
  if curl -sf "https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz" | gunzip \
       | grep -E "\"lang_code\": ?\"($codici)\"" > dati/grezzi.jsonl; then
    for codice in "${MANCANTI[@]}"; do
      grep -E "\"lang_code\": ?\"$codice\"" dati/grezzi.jsonl \
        | LINGUA=$codice FORME="dati/$codice/forme.tsv" VARIANTI="dati/$codice/varianti.tsv" DISCENDENTI="dati/$codice/discendenti.tsv" RADICI_CORRISPONDENTI="dati/$codice/radici_corrispondenti.tsv" MEMBRI_RADICE="dati/$codice/membri_radice.tsv" python3 filtra.py "dati/$codice/lemmi.jsonl" "dati/$codice/glosse.tsv" || true
      if [ -s "dati/$codice/lemmi.jsonl" ]; then
        echo "     $codice: $(wc -l < "dati/$codice/lemmi.jsonl") voci dal dump grezzo"
        ARGOMENTI+=(--chiudi "$codice=dati/$codice/lemmi.jsonl,dati/$codice/glosse.tsv,dati/$codice/forme.tsv,dati/$codice/varianti.tsv")
        ARGOMENTI+=(--discendenti "$codice=dati/$codice/discendenti.tsv")
  ARGOMENTI+=(--discendenti "$codice=dati/$codice/discendenti.tsv")
      else
        echo "::warning title=Chiusura::nessuna voce per $codice, nemmeno nel dump grezzo: la lingua resta fuori"
      fi
    done
    rm -f dati/grezzi.jsonl
  else
    echo "::warning title=Chiusura::dump grezzo non disponibile: ${MANCANTI[*]} restano fuori"
    # Kaikki che non risponde non dà un pacchetto piccolo: lo ferma. Il 20 novembre 2026 mancavano quasi tutte le lingue
    # di chiusura e il workflow ha scritto sul ramo un pacchetto di 502 mila voci invece di 1,35 milioni
    if [ ${#MANCANTI[@]} -gt 10 ]; then
      echo "::error title=Chiusura::mancano ${#MANCANTI[@]} dump e il dump grezzo non si scarica: Kaikki non risponde, il pacchetto non si scrive"
      exit 1
    fi
  fi
fi

if [ "$WIKIZIONARIO" = 1 ]; then
  echo "     glosse italiane: Wikizionario"
  curl -sf "https://kaikki.org/itwiktionary/All%20languages%20combined/kaikki.org-dictionary-all.jsonl" | python3 filtra_wikizionario.py "$DATI/glosse_it.tsv"
fi

# i derivati trasparenti senza etimologia (aeration < aerate): le regole di stima_derivati.py, imparate dalle coppie
# parola–base dichiarate e misurate sul 20% tenuto da parte; le basi sono le voci del pacchetto pubblicato. Con
# IN_FAMIGLIA anche l'elenco delle voci il cui primo etimo è nel pacchetto pubblicato (abolitionist < abolition)
for d in $(echo "$DERIVATI" | tr ',' ' '); do
  if [ -s "dati/$d/glosse.tsv" ] && [ -s ../dati/lessemi.tsv.gz ]; then
    ETIMI_D=()
    case ",$IN_FAMIGLIA," in *",$d,"*) ETIMI_D=(--scrivi-etimi "$DATI/in_famiglia_$d.tsv") ;; esac
    python3 stima_derivati.py "$d" "dati/$d/glosse.tsv" "dati/$d/lemmi.jsonl" ../dati/lessemi.tsv.gz "../dati/frequenze_$d.tsv.gz" \
      --scrivi "$DATI/derivati_$d.tsv" ${ETIMI_D[@]+"${ETIMI_D[@]}"} ${MOSTRA_DERIVATI:+--mostra "$MOSTRA_DERIVATI"} | tee "$DATI/rapporto_derivati_$d.txt"
    ARGOMENTI+=(--derivati "$d=$DATI/derivati_$d.tsv")
    if [ ${#ETIMI_D[@]} -gt 0 ]; then ARGOMENTI+=(--in-famiglia "$d=$DATI/in_famiglia_$d.tsv"); fi
  fi
done

echo "2/4  leggo le etimologie"
python3 wiktionary.py "$DATI/lemmi.jsonl" "$DATI/tsv" "$DATI/glosse.tsv" ${ARGOMENTI[@]+"${ARGOMENTI[@]}"} --passi "$PASSI" \
  --forme-base "$LINGUA=$DATI/forme.tsv" --discendenti "$LINGUA=$DATI/discendenti.tsv" \
  ${INTERE:+--intere "$INTERE"} ${SEMINA_DISCENDENTI:+--semina-discendenti "$SEMINA_DISCENDENTI"} ${RISALI:+--risali "$RISALI"} ${CON_ETIMOLOGIA:+--con-etimologia "$CON_ETIMOLOGIA"} ${SENZA_NOMI:+--senza-nomi "$SENZA_NOMI"} ${COMUNI:+--comuni "$COMUNI"} \
  $(for e in $ELENCHI; do printf -- "--elenco %s " "$e"; done) ${ESTERNI:+--esterni "$ESTERNI"} \
  ${PRECEDENTI:+--glosse-precedenti "$PRECEDENTI"} > "$DATI/rapporto_parser.json"
if [ "$DIZIONARI" = 1 ]; then
  echo "     dizionari del Perseus: Lewis & Short e Liddell–Scott–Jones"
  mkdir -p dati/perseus
  file=(lat/ls/lat.ls.perseus-eng2.xml)
  for i in $(seq 1 27); do file+=("grc/lsj/grc.lsj.perseus-eng$i.xml"); done
  locali=()
  for f in "${file[@]}"; do
    locale="dati/perseus/$(basename "$f")"; locali+=("$locale")
    [ -s "$locale" ] || curl -sfL --retry 3 -o "$locale" \
      "https://raw.githubusercontent.com/PerseusDL/lexica/$PERSEUS/CTS_XML_TEI/perseus/pdllex/$f"
  done
  if ! python3 filtra_perseus.py "$DATI/tsv/dizionari.tsv" --escludi "$DATI/tsv/lessemi.tsv" --etimi "$DATI/tsv/etimi_dizionari.tsv" \
       "${locali[@]}" 2> "$DATI/rapporto_perseus.txt"; then
    cat "$DATI/rapporto_perseus.txt" >&2; exit 1
  fi
  cat "$DATI/rapporto_perseus.txt"
  # le voci di latino e greco ancora senza etimologia che sono un prefisso e una parola nota (analisi della forma)
  python3 analisi_composti.py "$DATI/tsv/etimi_dizionari.tsv" "$DATI/tsv/lessemi.tsv" "$DATI/tsv/dizionari.tsv" "$DATI/tsv/ipotesi.tsv"
  # per il greco restano solo le regole che, misurate sulle voci di etimologia nota, indovinano la famiglia (apprendi_greco.py)
  if ! python3 apprendi_greco.py "$DATI/tsv/etimi_dizionari.tsv" "$DATI/tsv/lessemi.tsv" "$DATI/tsv/dizionari.tsv" \
       "$DATI/tsv/ipotesi.tsv" "$DATI/tsv/relazioni.tsv" 2> "$DATI/rapporto_greco.txt"; then
    cat "$DATI/rapporto_greco.txt" >&2; exit 1
  fi
  cat "$DATI/rapporto_greco.txt"
  # i derivati trasparenti senza etimologia nelle altre lingue (aerazione < aerare): regole imparate e misurate per
  # lingua, solo dove mettono la parola nella famiglia giusta almeno l'85% delle volte (apprendi_derivati.py)
  if ! python3 apprendi_derivati.py "$DATI/tsv/etimi_dizionari.tsv" "$DATI/tsv/lessemi.tsv" "$DATI/tsv/ipotesi.tsv" \
       "$DATI/tsv/relazioni.tsv" 2> "$DATI/rapporto_derivati.txt"; then
    cat "$DATI/rapporto_derivati.txt" >&2; exit 1
  fi
  cat "$DATI/rapporto_derivati.txt"
  # e i derivati trasparenti di DERIVATI: la loro etimologia è l'analisi della forma (parola < base, con l'affisso);
  # dove apprendi_derivati.py ha già scritto la sua analisi (la lingua passa la misura sul dizionario), vale quella
  for d in $(echo "$DERIVATI" | tr ',' ' '); do
    if [ -s "$DATI/derivati_$d.tsv" ]; then
      awk -F'\t' -v l="$d" 'BEGIN{OFS="\t"} NR==FNR {c[$1]; next} !(("analisi:enwikt:" l ":" $1) in c) {print "analisi:enwikt:" l ":" $1, l, $1, 1, l, $2, "derivazione", $3, "analisi"}' \
        "$DATI/tsv/etimi_dizionari.tsv" "$DATI/derivati_$d.tsv" > "$DATI/derivati_$d.righe"
      cat "$DATI/derivati_$d.righe" >> "$DATI/tsv/etimi_dizionari.tsv"
      echo "     derivati trasparenti ($d): $(wc -l < "$DATI/derivati_$d.righe") analisi della forma dall'elenco della stima"
    fi
  done
  # stime della prima attestazione: l'autore datato più antico citato nella voce (DATAZIONI.md, passo 1)
  python3 datatore_dizionari.py autori "$DATI/tsv/autori.tsv"
  python3 datatore_dizionari.py stime "$DATI/tsv/autori.tsv" "$DATI/tsv/stime.tsv" "${locali[@]}"
fi
if [ "$SOLO_ANALISI" = 1 ]; then
  echo "     analisi finita: le tabelle sono in $DATI/tsv"
  exit 0
fi

echo "3/4  carico le tabelle di appoggio"
cd "$DATI/tsv"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
truncate stg_lingua, stg_lessema, stg_ipotesi, stg_relazione, stg_doppione, stg_radice, stg_attestazione, stg_wikizionario,
         stg_dizionario;
\copy stg_lingua from 'lingue.tsv'
\copy stg_lessema from 'lessemi.tsv'
\copy stg_ipotesi from 'ipotesi.tsv'
\copy stg_relazione from 'relazioni.tsv'
\copy stg_doppione from 'doppioni.tsv'
\copy stg_radice from 'radici.tsv'
\copy stg_attestazione from 'attestazioni.tsv'
SQL
if [ -f ../glosse_it.tsv ]; then
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "\\copy stg_wikizionario from '../glosse_it.tsv'"
fi
if [ "$DIZIONARI" = 1 ] && [ -f dizionari.tsv ]; then
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "\\copy stg_dizionario from 'dizionari.tsv'" \
    -c "truncate stg_autore, stg_stima" -c "\\copy stg_autore from 'autori.tsv'" -c "\\copy stg_stima from 'stime.tsv'"
  if [ -f etimi_dizionari.tsv ]; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "truncate stg_etimo_dizionario" -c "\\copy stg_etimo_dizionario from 'etimi_dizionari.tsv'"
  fi
fi

echo "4/4  fondo nel dizionario e ricalcolo allotropi e famiglie"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_wiktionary())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_dizionari())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_stime())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_etimi_dizionari())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_glosse_wikizionario())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "refresh materialized view mv_allotropi" -c "refresh materialized view mv_famiglia" -c "analyze"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "select * from v_validazione_wiktionary"
