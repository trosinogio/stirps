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
visto=""
# fino a 40 minuti di orologio: la build rifà l'import quando cambia il pacchetto dati (con le lingue germaniche, 17 novembre
# 2026, circa 17 minuti su Neon). Un guasto di rete mentre si aspetta non ferma l'attesa: il deploy va avanti su Vercel
# anche se GitHub non lo vede. Il 17 novembre 2026 GitHub ha perso Vercel per qualche minuto, curl ha esaurito i suoi
# tentativi e lo script, con set -e, si è fermato: il deploy è riuscito, ma la pubblicazione risultava fallita
fine=$(( $(date +%s) + 2400 ))
while [ "$(date +%s)" -lt "$fine" ]; do
  if risposta=$(curl -sS --fail-with-body --connect-timeout 30 --max-time 60 -H "$aut" "$api/v13/deployments/$did?$squadra" 2>&1); then
    stato=$(jq -r '.readyState // .status // empty' <<< "$risposta" 2>/dev/null || true)
    visto=$(date +%s)
    case "$stato" in READY|ERROR|CANCELED) break;; esac
  else
    echo "Vercel non risponde, riprovo: $(tail -1 <<< "$risposta")"
  fi
  sleep 10
done
echo "stato: ${stato:-sconosciuto}"
if [ "$stato" = READY ]; then
  echo "$url"
  exit 0
fi
# le ultime righe della build, per capire che cosa non va
curl -sS "${riprova[@]}" -H "$aut" "$api/v3/deployments/$did/events?$squadra&limit=-1" \
  | jq -r '.[]? | (.text // .payload.text // empty)' | tail -40 || true
if [ "$stato" = ERROR ] || [ "$stato" = CANCELED ]; then
  exit 1
fi
# né pronto né fallito: la build è ancora in corso, o Vercel non ha più risposto. Il deploy può riuscire da solo: non si
# rilancia la pubblicazione (due build farebbero due import sul database) prima di aver guardato il sito
echo "non so come è finito il deploy $did: ultimo stato ${stato:-sconosciuto}, ultima risposta di Vercel $( [ -n "$visto" ] && date -u -d "@$visto" +%H:%M:%S || echo mai)"
exit 2
