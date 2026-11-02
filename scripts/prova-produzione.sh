#!/usr/bin/env bash
# Build di produzione in locale e server avviato, su un Postgres locale: per misurare pagine, peso dell'HTML, prefetch,
# mappa del sito. Non esegue inizializza-db.mjs (niente scritture nel database).
#   DATABASE_URL=postgres://utente:password@localhost:5432/db scripts/prova-produzione.sh [porta]
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DATABASE_URL:?serve un DATABASE_URL locale}"
case "$DATABASE_URL" in *@localhost*|*@127.0.0.1*) ;; *) echo "solo un database locale" >&2; exit 1;; esac
porta=${1:-3400}
registro=${TMPDIR:-/tmp}/prova-produzione
export NEON_AUTH_COOKIE_SECRET=${NEON_AUTH_COOKIE_SECRET:-prova-locale-solo-per-la-build-0123456789abcdef}
fuser -k "$porta/tcp" > /dev/null 2>&1 || true
npx next build > "$registro-build.log" 2>&1 || { tail -20 "$registro-build.log"; exit 1; }
nohup npx next start -p "$porta" > "$registro.log" 2>&1 &
for _ in $(seq 1 60); do grep -q Ready "$registro.log" && break; sleep 1; done
echo "pronto su http://localhost:$porta (registro: $registro.log; per fermarlo: fuser -k $porta/tcp)"
