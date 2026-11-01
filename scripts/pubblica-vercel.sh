#!/usr/bin/env bash
# Pubblica l'app su Vercel dalla riga di comando, senza GitHub.
#   VERCEL_TOKEN=… DATABASE_URL=… ./scripts/pubblica-vercel.sh
# DATABASE_URL può essere la stringa diretta o quella pooled di Neon: l'altra si ricava.
# Al primo deploy la build riempie il database (scripts/inizializza-db.mjs).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERCEL_TOKEN:?serve VERCEL_TOKEN}"
: "${DATABASE_URL:?serve DATABASE_URL}"
PROGETTO=${PROGETTO:-dizionario-etimologico}
# Neon: l'host pooled ha -pooler dopo l'identificativo dell'endpoint
diretta=$(printf '%s' "$DATABASE_URL" | sed -E 's/@(ep-[a-z0-9-]+)-pooler\./@\1./')
pooled=$(printf '%s' "$diretta" | sed -E 's/@(ep-[a-z0-9-]+)\./@\1-pooler./')
vercel() { npx --yes vercel@65 --token "$VERCEL_TOKEN" "$@"; }
vercel link --yes --project "$PROGETTO" > /dev/null
for coppia in "DATABASE_URL=$pooled" "DATABASE_URL_UNPOOLED=$diretta" "ANTEPRIMA=1"; do
  nome=${coppia%%=*}; valore=${coppia#*=}
  vercel env rm "$nome" production --yes > /dev/null 2>&1 || true
  printf '%s' "$valore" | vercel env add "$nome" production > /dev/null
done
vercel deploy --prod --yes
