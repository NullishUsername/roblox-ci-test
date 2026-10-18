#!/usr/bin/env bash
# Publishes a place file via Roblox Open Cloud. Used by CI, and handy locally
# to check your API key works before involving GitHub.
#
#   UNIVERSE_ID=123 PLACE_ID=456 ./scripts/publish.sh game.rbxl            # Saved (safe test)
#   UNIVERSE_ID=123 PLACE_ID=456 VERSION_TYPE=Published ./scripts/publish.sh game.rbxl
#
# If ROBLOX_API_KEY isn't set, you'll be prompted for it (input hidden, not saved to history).
set -euo pipefail

FILE="${1:-game.rbxl}"
VERSION_TYPE="${VERSION_TYPE:-Saved}"
: "${UNIVERSE_ID:?Set UNIVERSE_ID}"
: "${PLACE_ID:?Set PLACE_ID}"

if [ -z "${ROBLOX_API_KEY:-}" ]; then
  read -rsp "Roblox API key: " ROBLOX_API_KEY; echo
fi

[ -f "$FILE" ] || { echo "File not found: $FILE" >&2; exit 1; }

case "$FILE" in
  *.rbxlx) CONTENT_TYPE="application/xml" ;;
  *)       CONTENT_TYPE="application/octet-stream" ;;
esac

SIZE=$(wc -c < "$FILE" | tr -d ' ')
echo "Uploading $FILE ($SIZE bytes) to universe $UNIVERSE_ID / place $PLACE_ID as $VERSION_TYPE"
if [ "$SIZE" -gt 10485760 ]; then
  echo "::warning::Place file is over 10 MiB - Roblox may reject or time out on it."
fi

RESP=$(mktemp)
HTTP=$(curl -sS -o "$RESP" -w '%{http_code}' -X POST \
  "https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=${VERSION_TYPE}" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: ${CONTENT_TYPE}" \
  -H "Accept: application/json" \
  --data-binary @"$FILE")

echo "HTTP $HTTP"
cat "$RESP"; echo

if [ "$HTTP" != "200" ]; then
  case "$HTTP" in
    401) echo "Hint: 'Invalid API Key' = key copied wrong/expired/disabled. Otherwise the key lacks universe-places Write for this experience, or is IP-restricted." ;;
    403) echo "Hint: publishing not allowed on this place, or the key owner can't publish it." ;;
    404) echo "Hint: universe or place ID doesn't exist (check you didn't swap them)." ;;
    409) echo "Hint: that place isn't part of that universe - IDs are mixed up." ;;
    400) echo "Hint: invalid file - did Rojo build a model instead of a place?" ;;
  esac
  exit 1
fi

VERSION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["versionNumber"])' "$RESP")
echo "Published version ${VERSION} (${VERSION_TYPE})"

if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "version=${VERSION}" >> "$GITHUB_OUTPUT"; fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "### Place ${PLACE_ID} → version ${VERSION} (${VERSION_TYPE})" >> "$GITHUB_STEP_SUMMARY"
fi
