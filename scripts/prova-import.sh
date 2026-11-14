#!/usr/bin/env bash
# Prova di un import su una copia del database: fotografia prima (db/prove/prima.sql), import con
# scripts/inizializza-db.mjs, confronto dopo (db/prove/dopo.sql) con i cancelli che fermano. È il passo obbligato
# prima di pubblicare un pacchetto dati, un cambiamento di db/05 o un aggiornamento datato (import/PROGRAMMA.md).
#
#   DATABASE_URL=postgres://utente:password@localhost:5432/copia scripts/prova-import.sh
#   DATABASE_URL=<ramo di prova su Neon> HOST_PRODUZIONE=<host della produzione> scripts/prova-import.sh
#
# Mai sulla produzione: l'import cambia i dati e la fotografia scrive lo schema «prova». Fuori da localhost serve
# HOST_PRODUZIONE, e la prova si rifiuta se il database è quello. Soglie in percento: PERSE, ETIMI, INDIRIZZI (0.5);
# LIMITE_MB ferma se dopo l'import il database supera quello spazio (0, il valore di partenza: nessun limite).
# Esce con 0 se tutti i cancelli passano, con 3 se uno ferma, con 1 se l'import fallisce. TIENI=1 lascia lo schema «prova».
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DATABASE_URL:?serve il DATABASE_URL di una copia del database}"
host=$(node -e 'console.log(new URL(process.argv[1]).hostname)' "$DATABASE_URL")
case "$host" in
  localhost|127.0.0.1) ;;
  *) : "${HOST_PRODUZIONE:?fuori da localhost serve HOST_PRODUZIONE, per non sbagliare database}"
     # il ramo di prova e la produzione hanno host diversi; anche l'host «-pooler» della produzione è la produzione
     if [ "${host/-pooler/}" = "${HOST_PRODUZIONE/-pooler/}" ]; then echo "prova-import: questo è il database di produzione, mi fermo" >&2; exit 2; fi ;;
esac
command -v psql > /dev/null || { echo "prova-import: serve psql" >&2; exit 2; }
sql() { psql "$DATABASE_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
registro=${REGISTRO:-${TMPDIR:-/tmp}/prova-import.log}

echo "== PRIMA"
sql -At -f db/prove/prima.sql

echo "== IMPORT"
inizio=$(date +%s)
# tutte le variabili verso la copia: .env.local punta alla produzione, e le variabili già impostate vincono
if ! DATABASE_URL_UNPOOLED="$DATABASE_URL" POSTGRES_URL="$DATABASE_URL" POSTGRES_URL_NON_POOLING="$DATABASE_URL" \
     node scripts/inizializza-db.mjs > "$registro" 2>&1; then
  echo "prova-import: l'import è fallito (il database della prova resta com'era: l'import è in una transazione)" >&2
  tail -25 "$registro" >&2
  exit 1
fi
echo "import riuscito in $(( $(date +%s) - inizio )) s"
echo "aggiornamenti datati applicati: $(grep -c '^\[db\] aggiornamento' "$registro" || true)"
grep -E "^\[db\] (dati già|fusione|pulizia|dizionari|etimologie|glosse|definizioni|pronunce|sensi|forme|aree|mv_|commit|spazio)" "$registro" | cut -c1-260 || true
if grep -q "dati già alla versione" "$registro"; then
  echo "nota: il pacchetto dati è lo stesso già importato in questa copia; sono stati applicati solo gli aggiornamenti datati"
fi

echo "== DOPO"
sql -v perse="${PERSE:-0.5}" -v etimi="${ETIMI:-0.5}" -v indirizzi="${INDIRIZZI:-0.5}" -v limite_mb="${LIMITE_MB:-0}" -f db/prove/dopo.sql
fermi=$(sql -At -c "select count(*) from prova.esito where misura > soglia")
[ "${TIENI:-0}" = 1 ] || sql -c "set client_min_messages = warning; drop schema prova cascade"
if [ "$fermi" != 0 ]; then
  echo "prova-import: $fermi cancelli fermano la pubblicazione (vedi sopra)" >&2
  exit 3
fi
echo "prova-import: tutti i cancelli passano"
