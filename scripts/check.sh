#!/usr/bin/env bash
# Checks whether the Paad Tak YouTube live stream is on air.
# Opens a GitHub issue (label "off-air") when it is not, closes it when it is back.
# Env: GH_TOKEN (for gh), GITHUB_REPOSITORY, DRY_RUN=true|false,
#      CHECKS (default 3), GAP_SECONDS (default 240)
set -u

LIVE_URL="https://www.youtube.com/@paadtak/live"
CHANNEL_ID="UCS40zhxggcmiYmJFtAmoHaw"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
CHECKS="${CHECKS:-3}"
GAP_SECONDS="${GAP_SECONDS:-240}"
DRY_RUN="${DRY_RUN:-false}"
TMP="$(mktemp -d)"

ist_now() { TZ=Asia/Kolkata date '+%Y-%m-%d %H:%M IST'; }

# Prints LIVE, OFF or UNKNOWN (plus a short reason) for one fetch.
classify() {
  local body="$TMP/page.html" code
  code=$(curl -sS -L --max-time 30 --connect-timeout 10 \
    -A "$UA" -H "Accept-Language: en" \
    -o "$body" -w '%{http_code}' "$LIVE_URL" 2>"$TMP/curl.err") || {
    echo "UNKNOWN (curl error: $(tr -d '\n' <"$TMP/curl.err" | cut -c1-100))"; return; }
  if [ "$code" != "200" ]; then echo "UNKNOWN (HTTP $code)"; return; fi
  local size; size=$(wc -c <"$body" | tr -d ' ')
  if [ "$size" -lt 1000 ]; then echo "UNKNOWN (tiny body, $size bytes)"; return; fi
  # LIVE: YouTube marks a running stream with isLiveNow:true in the page data.
  if grep -q '"isLiveNow":true' "$body"; then echo "LIVE"; return; fi
  # OFF: a normal YouTube page with real page data (ytInitialData), recognisably
  # the Paad Tak channel (or a watch page that says it is not live now), no isLiveNow:true.
  # Consent / bot-check pages have none of these markers, so they stay UNKNOWN.
  if grep -q 'ytInitialData' "$body" && {
       grep -q 'channelMetadataRenderer' "$body" ||
       grep -q '"isLiveNow":false' "$body" ||
       grep -q "rel=\"canonical\" href=\"https://www.youtube.com/channel/$CHANNEL_ID\"" "$body" ||
       grep -q 'rel="canonical" href="https://www.youtube.com/@paadtak"' "$body"; }; then
    echo "OFF"; return
  fi
  echo "UNKNOWN (page loaded but no YouTube channel/live markers, $size bytes)"
}

results=()
status="UNKNOWN"
for i in $(seq 1 "$CHECKS"); do
  r="$(classify)"
  word="${r%% *}"
  echo "Check $i/$CHECKS at $(ist_now): $r"
  results+=("$i: $r")
  if [ "$word" = "LIVE" ]; then status="LIVE"; break; fi
  # Once any check is UNKNOWN the final answer cannot be OFF.
  [ "$word" = "UNKNOWN" ] && any_unknown=1
  [ "$i" -lt "$CHECKS" ] && sleep "$GAP_SECONDS"
done

if [ "$status" != "LIVE" ]; then
  if [ "${any_unknown:-0}" = "1" ]; then status="UNKNOWN"; else status="OFF"; fi
fi
echo "Final result: $status (dry_run=$DRY_RUN)"

open_issue_number() {
  gh issue list --repo "$GITHUB_REPOSITORY" --label off-air --state open \
    --json number --jq '.[0].number // empty'
}

case "$status" in
  OFF)
    existing="$(open_issue_number)"
    if [ -n "$existing" ]; then
      echo "Off air, and issue #$existing is already open. Nothing to do."
    elif [ "$DRY_RUN" = "true" ]; then
      echo "DRY RUN: would open issue 'Paad Tak stream is off air'."
    else
      gh label create off-air --repo "$GITHUB_REPOSITORY" --color D93F0B \
        --description "Paad Tak live stream is not on air" 2>/dev/null || true
      {
        echo "The Paad Tak YouTube live stream looked off air at $(ist_now)."
        echo
        echo "Checks (about 4 minutes apart):"
        for r in "${results[@]}"; do echo "- $r"; done
        echo
        echo "Live page: $LIVE_URL"
        echo
        echo "The streamer on the Umbrel tries to repair itself. If this issue stays open, check the Umbrel (\"Paad Tak Stream\" app)."
        echo
        echo "This issue closes by itself when the stream is back on air."
      } >"$TMP/body.md"
      gh issue create --repo "$GITHUB_REPOSITORY" --title "Paad Tak stream is off air" \
        --label off-air --body-file "$TMP/body.md"
    fi
    ;;
  LIVE)
    existing="$(open_issue_number)"
    if [ -z "$existing" ]; then
      echo "Live, and no open off-air issue. Nothing to do."
    elif [ "$DRY_RUN" = "true" ]; then
      echo "DRY RUN: would comment on and close issue #$existing."
    else
      gh issue comment "$existing" --repo "$GITHUB_REPOSITORY" --body "Back on air at $(ist_now)."
      gh issue close "$existing" --repo "$GITHUB_REPOSITORY"
    fi
    ;;
  *)
    echo "Could not tell if the stream is live (UNKNOWN). Doing nothing."
    ;;
esac
