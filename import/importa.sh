#!/usr/bin/env bash
# Import delle etimologie di Wiktionary (via Kaikki) nel database indicato da DATABASE_URL.
#   DATABASE_URL=postgres://… ./importa.sh                                   # italiano, chiuso su latino, francese antico e greco antico
#   LINGUA=fr NOME=French CHIUSURA="la:Latin fro:Old French" DATABASE_URL=… ./importa.sh
#   CHIUSURA="" DATABASE_URL=… ./importa.sh                                  # senza chiusura delle catene
#   WIKIZIONARIO=0 DATABASE_URL=… ./importa.sh                               # senza glosse italiane del Wikizionario
#   INTERE="" DATABASE_URL=… ./importa.sh                                    # latino e greco solo dove le catene arrivano
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
SOLO_ANALISI=${SOLO_ANALISI:-0}
DATI=dati/$LINGUA
mkdir -p "$DATI"

scarica() {   # scarica <nome inglese della lingua> : stampa il dump di Kaikki
  local pagina file
  pagina=$(printf '%s' "$1" | sed 's/ /%20/g'); file=$(printf '%s' "$1" | tr -d ' ')
  curl -sf "https://kaikki.org/dictionary/$pagina/kaikki.org-dictionary-$file.jsonl"
}

echo "1/4  scarico e filtro il dump di Kaikki ($NOME)"
scarica "$NOME" | python3 filtra.py "$DATI/lemmi.jsonl" "$DATI/glosse.tsv"
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
  ${INTERE:+--intere "$INTERE"} > "$DATI/rapporto_parser.json"
if [ "$SOLO_ANALISI" = 1 ]; then
  echo "     analisi finita: le tabelle sono in $DATI/tsv"
  exit 0
fi

echo "3/4  carico le tabelle di appoggio"
cd "$DATI/tsv"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
truncate stg_lingua, stg_lessema, stg_ipotesi, stg_relazione, stg_doppione, stg_radice, stg_attestazione, stg_wikizionario;
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

echo "4/4  fondo nel dizionario e ricalcolo allotropi e famiglie"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_wiktionary())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -At -c "select jsonb_pretty(importa_glosse_wikizionario())"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "refresh materialized view mv_allotropi" -c "refresh materialized view mv_famiglia" -c "analyze"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c "select * from v_validazione_wiktionary"
