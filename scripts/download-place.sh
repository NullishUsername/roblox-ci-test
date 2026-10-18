#!/usr/bin/env bash
# Downloads the latest version of a place (the builders' map) via Roblox Open Cloud.
# The API key needs the legacy-asset system with the manage scope (legacy-asset:manage).
#
#   BASE_PLACE_ID=123 ./scripts/download-place.sh base.rbxl
#   BASE_PLACE_ID=123 BASE_VERSION=42 ./scripts/download-place.sh base.rbxl   # a specific version
#
# If ROBLOX_API_KEY isn't set, you'll be prompted for it (input hidden).
set -euo pipefail

OUT="${1:-base.rbxl}"
: "${BASE_PLACE_ID:?Set BASE_PLACE_ID to the build place ID}"

if [ -z "${ROBLOX_API_KEY:-}" ]; then
  read -rsp "Roblox API key: " ROBLOX_API_KEY; echo
fi

URL="https://apis.roblox.com/asset-delivery-api/v1/assetId/${BASE_PLACE_ID}"
if [ -n "${BASE_VERSION:-}" ]; then URL="${URL}/version/${BASE_VERSION}"; fi

META=$(mktemp)
echo "Fetching download location for place ${BASE_PLACE_ID}${BASE_VERSION:+ (version $BASE_VERSION)}"
HTTP=$(curl -sS -o "$META" -w '%{http_code}' "$URL" -H "x-api-key: ${ROBLOX_API_KEY}")
if [ "$HTTP" != "200" ]; then
  echo "HTTP $HTTP"; cat "$META"; echo
  case "$HTTP" in
    401) echo "Hint: key invalid, or missing the legacy-asset (manage) permission." ;;
    403) echo "Hint: the key's owner can't access this place (group game -> key must be owned by the group)." ;;
    404) echo "Hint: wrong place ID, or that version doesn't exist." ;;
  esac
  exit 1
fi

LOCATION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["location"])' "$META")

# The location is a short-lived CDN URL; it doesn't need the API key.
curl -sS --fail --compressed -o "$OUT" "$LOCATION"

# Sanity check: binary places start with "<roblox!", XML places with "<roblox"
MAGIC=$(head -c 7 "$OUT")
if [ "$MAGIC" != "<roblox" ]; then
  echo "::error::Downloaded file doesn't look like a place file (starts with: $(head -c 20 "$OUT" | od -c | head -n 1))"
  exit 1
fi

echo "Saved $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
