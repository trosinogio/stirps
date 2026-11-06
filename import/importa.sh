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
ESTERNI=${ESTERNI-}   # e con l'elenco, anche le voci con l'etimo in un'altra lingua: ESTERNI=en
PRECEDENTI=${PRECEDENTI-}   # il lessemi.tsv.gz pubblicato: le glosse non cambiano se sono ancora tra le candidate
SOLO_ANALISI=${SOLO_ANALISI:-0}
DIZIONARI=${DIZIONARI:-1}   # i lemmi del Lewis & Short e dell'LSJ che Wiktionary non ha (Perseus, CC BY-SA 4.0)
PERSEUS=${PERSEUS:-1c34cdf756c63cf37db61bd366d733431dbd7aa0}   # commit di PerseusDL/lexica
DATI=dati/$LINGUA
mkdir -p "$DATI"

scarica() {   # scarica <nome inglese della lingua> : stampa il dump di Kaikki
  local pagina file
  pagina=$(printf '%s' "$1" | sed 's/ /%20/g'); file=$(printf '%s' "$1" | tr -d ' ')
  curl -sf "https://kaikki.org/dictionary/$pagina/kaikki.org-dictionary-$file.jsonl"
}

echo "1/4  scarico e filtro il dump di Kaikki ($NOME)"
scarica "$NOME" | SENZA="$DATI/senza_etimologia.tsv" python3 filtra.py "$DATI/lemmi.jsonl" "$DATI/glosse.tsv"
ARGOMENTI=()
for voce in $(printf '%s' "$CHIUSURA" | sed 's/ \([a-z][a-z-]*:\)/\n\1/g' | tr ' ' '~'); do
  codice=${voce%%:*}; nome=$(printf '%s' "${voce#*:}" | tr '~' ' ')
  echo "     chiusura delle catene: $nome"
  mkdir -p "dati/$codice"
  scarica "$nome" | LINGUA=$codice FORME="dati/$codice/forme.tsv" python3 filtra.py "dati/$codice/lemmi.jsonl" "dati/$codice/glosse.tsv"
  ARGOMENTI+=(--chiudi "$codice=dati/$codice/lemmi.jsonl,dati/$codice/glosse.tsv,dati/$codice/forme.tsv")
done

if [ "$WIKIZIONARIO" = 1 ]; then
  echo "     glosse italiane: Wikizionario"
  curl -sf "https://kaikki.org/itwiktionary/All%20languages%20combined/kaikki.org-dictionary-all.jsonl" | python3 filtra_wikizionario.py "$DATI/glosse_it.tsv"
fi

echo "2/4  leggo le etimologie"
python3 wiktionary.py "$DATI/lemmi.jsonl" "$DATI/tsv" "$DATI/glosse.tsv" ${ARGOMENTI[@]+"${ARGOMENTI[@]}"} --passi "$PASSI" \
  ${INTERE:+--intere "$INTERE"} ${CON_ETIMOLOGIA:+--con-etimologia "$CON_ETIMOLOGIA"} \
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
  if ! python3 filtra_perseus.py "$DATI/tsv/dizionari.tsv" --escludi "$DATI/tsv/lessemi.tsv" "${locali[@]}" 2> "$DATI/rapporto_perseus.txt"; then
    cat "$DATI/rapporto_perseus.txt" >&2; exit 1
  fi
  cat "$DATI/rapporto_perseus.txt"
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
fi

echo "4/4  fondo nel dizionario e ricalcolo allotropi e famiglie"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_wiktionary())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_dizionari())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_stime())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_glosse_wikizionario())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "refresh materialized view mv_allotropi" -c "refresh materialized view mv_famiglia" -c "analyze"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "select * from v_validazione_wiktionary"
