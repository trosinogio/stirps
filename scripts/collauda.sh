#!/usr/bin/env bash
# Collaudo completo su un Postgres vuoto: i test del seme (db/04_test.sql) e quelli dell'import sul banco di prova
# di voci reali (db/06_test_import.sql). Crea e ricrea i database stirps_seme e stirps_import.
#   PGURL=postgres://utente:password@localhost:5432 scripts/collauda.sh
set -euo pipefail
cd "$(dirname "$0")/.."
BASE=${PGURL:?serve PGURL, per esempio postgres://postgres:postgres@localhost:5432}
crea() {
  psql "$BASE/postgres" -q -c "drop database if exists $1" \
       -c "create database $1 template template0 encoding 'UTF8' locale 'C.UTF-8'"
  for f in "${@:2}"; do psql "$BASE/$1" -q -v ON_ERROR_STOP=1 -f "$f" > /dev/null; done
}
echo '== test del seme'
crea stirps_seme db/01_schema.sql db/02_logica.sql db/03_seed_pilota.sql
psql "$BASE/stirps_seme" -q -v ON_ERROR_STOP=1 -f db/04_test.sql 2>&1 | grep -cE 'NOTICE: +OK' | sed 's/^/superati: /'
echo '== test dell’import'
crea stirps_import db/01_schema.sql db/02_logica.sql db/03_seed_pilota.sql db/05_import_wiktionary.sql
DATABASE_URL="$BASE/stirps_import" TEST_SQL="$PWD/db/06_test_import.sql" import/collauda.sh 2>&1 | grep -cE 'NOTICE: +OK' | sed 's/^/superati: /'
echo 'collaudo completato'
