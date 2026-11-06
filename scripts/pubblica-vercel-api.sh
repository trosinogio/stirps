#!/usr/bin/env bash
# Pubblica su Vercel con l'API REST, senza la CLI. Serve con i token di progetto (vcp_…): vedono il progetto ma
# non l'utente né i team, e con loro la CLI si ferma («User not found»).
#   VERCEL_TOKEN=… scripts/pubblica-vercel-api.sh production     (oppure preview)
# Carica i file tracciati da git, tranne quelli di .vercelignore, crea il deploy e aspetta che sia pronto:
# esce con 0 se è pronto, con 1 se la build fallisce. In produzione la build applica gli aggiornamenti datati.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERCEL_TOKEN:?serve VERCEL_TOKEN}"
destinazione=${1:-production}
progetto=${PROGETTO:-dizionario-etimologico}
api=https://api.vercel.com
aut="Authorization: Bearer $VERCEL_TOKEN"
lavoro=$(mktemp -d)

# le chiamate che si possono ripetere senza danni (letture, caricamento dei file per hash) riprovano dopo un guasto di
# rete passeggero: il 2 novembre 2026 GitHub non raggiungeva Vercel e la pubblicazione si è fermata al primo tentativo.
# La creazione del deploy non si ripete da sola: due deploy farebbero due import insieme sul database
riprova=(--retry 4 --retry-delay 15 --retry-all-errors --connect-timeout 30)
info=$(curl -sS --fail-with-body "${riprova[@]}" -H "$aut" "$api/v9/projects/$progetto")
id=$(jq -r .id <<< "$info")
squadra="teamId=$(jq -r .accountId <<< "$info")"

# i file: quelli tracciati da git, meno gli schemi di .vercelignore (cartelle, nomi, prefissi con *)
esclusi=()
if [ -f .vercelignore ]; then mapfile -t esclusi < <(grep -v -E '^[[:space:]]*(#|$)' .vercelignore); fi
: > "$lavoro/file.tsv"
while IFS= read -r -d '' f; do
  for e in "${esclusi[@]}"; do
    e=${e%/}
    # shellcheck disable=SC2254
    case "$f" in "$e"|"$e"/*|$e|$e/*) continue 2;; esac
  done
  sha=$(sha1sum "$f" | cut -d' ' -f1)
  curl -sS --fail-with-body "${riprova[@]}" -X POST -H "$aut" -H 'Content-Type: application/octet-stream' \
       -H "x-vercel-digest: $sha" --data-binary @"$f" "$api/v2/files?$squadra" > /dev/null
  printf '%s\t%s\t%s\n' "$f" "$sha" "$(stat -c %s "$f")" >> "$lavoro/file.tsv"
done < <(git ls-files -z)
echo "caricati $(wc -l < "$lavoro/file.tsv") file"

jq -Rn --arg nome "$progetto" --arg p "$id" --arg d "$destinazione" '
  {name: $nome, project: $p,
   files: [inputs | split("\t") | {file: .[0], sha: .[1], size: (.[2] | tonumber)}]}
  + (if $d == "production" then {target: "production"} else {} end)' < "$lavoro/file.tsv" > "$lavoro/deploy.json"
dep=$(curl -sS --fail-with-body --connect-timeout 30 -X POST -H "$aut" -H 'Content-Type: application/json' \
      "$api/v13/deployments?$squadra&forceNew=1&skipAutoDetectionConfirmation=1" --data-binary @"$lavoro/deploy.json")
did=$(jq -r .id <<< "$dep")
url=https://$(jq -r .url <<< "$dep")
echo "deploy $did ($destinazione): $url"

stato=""
for _ in $(seq 1 150); do
  stato=$(curl -sS "${riprova[@]}" -H "$aut" "$api/v13/deployments/$did?$squadra" | jq -r '.readyState // .status')
  case "$stato" in READY|ERROR|CANCELED) break;; esac
  sleep 4
done
echo "stato: $stato"
if [ "$stato" != READY ]; then
  # le ultime righe della build, per capire che cosa non va
  curl -sS "${riprova[@]}" -H "$aut" "$api/v3/deployments/$did/events?$squadra&limit=-1" \
    | jq -r '.[]? | (.text // .payload.text // empty)' | tail -40 || true
  exit 1
fi
echo "$url"
