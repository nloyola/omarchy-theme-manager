#!/bin/bash

set -euo pipefail

cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-theme-manager
catalog_cache="$cache_dir/themes-data.json"
official_cache="$cache_dir/official-themes.html"
catalog_url=https://raw.githubusercontent.com/limehawk/omarchy-theme-website/main/src/data/themes-data.json
official_url=https://omarchy.org/themes/
max_age=${OMARCHY_THEME_CATALOG_MAX_AGE:-21600}
force_refresh=${1:-}
catalog_max_bytes=$((8 * 1024 * 1024))
official_max_bytes=$((2 * 1024 * 1024))
output_max_bytes=$((4 * 1024 * 1024))
catalog_max_items=2000
official_max_items=1000
official_repository_pattern='href="https://github\.com/[A-Za-z0-9-]{1,39}/[A-Za-z0-9_.-]{1,100}'

if [[ ! $max_age =~ ^[0-9]+$ ]]; then
  echo "OMARCHY_THEME_CATALOG_MAX_AGE must be a non-negative integer." >&2
  exit 2
fi

if [[ -n $force_refresh && $force_refresh != "--refresh" ]]; then
  echo "Usage: catalog.sh [--refresh]" >&2
  exit 2
fi

mkdir -p "$cache_dir"

is_fresh() {
  local path=$1
  local modified now

  [[ -f $path ]] || return 1
  modified=$(stat -c '%Y' "$path")
  now=$(date +%s)
  ((now - modified < max_age))
}

download() {
  local url=$1
  local destination=$2
  local validator=$3
  local max_bytes=$4
  local temporary

  temporary=$(mktemp "$cache_dir/.download.XXXXXX")
  if curl --fail --location --silent --show-error \
    --proto '=https' --max-filesize "$max_bytes" \
    --connect-timeout 10 --max-time 45 \
    --output "$temporary" "$url" \
    && [[ $(stat -c '%s' "$temporary") -le $max_bytes ]] \
    && "$validator" "$temporary"; then
    mv "$temporary" "$destination"
    return 0
  fi

  rm -f "$temporary"
  return 1
}

valid_catalog() {
  [[ $(stat -c '%s' "$1") -le $catalog_max_bytes ]] || return 1
  jq -e \
    --argjson maxItems "$catalog_max_items" \
    'type == "array"
      and length > 0
      and length <= $maxItems
      and all(.[];
        type == "object"
        and (.name | type) == "string"
        and (.name | length) <= 120
        and (.github_url | type) == "string"
        and (.github_url | length) <= 512)' \
    "$1" >/dev/null
}

valid_official_page() {
  local repository_count

  [[ $(stat -c '%s' "$1") -le $official_max_bytes ]] || return 1
  repository_count=$(grep -oE "$official_repository_pattern" "$1" | wc -l)
  ((repository_count > 20 && repository_count <= official_max_items))
}

refresh_if_needed() {
  local path=$1
  local url=$2
  local validator=$3
  local max_bytes=$4

  if [[ $force_refresh == "--refresh" ]] || ! is_fresh "$path" || ! "$validator" "$path"; then
    if ! download "$url" "$path" "$validator" "$max_bytes"; then
      [[ -f $path ]] && "$validator" "$path" || return 1
      echo "Theme catalog refresh failed; using cached data." >&2
    fi
  fi
}

refresh_if_needed "$catalog_cache" "$catalog_url" valid_catalog "$catalog_max_bytes"
refresh_if_needed "$official_cache" "$official_url" valid_official_page "$official_max_bytes"

official_repositories=$(
  grep -oE "$official_repository_pattern" "$official_cache" \
    | cut -d '"' -f 2 \
    | sed -E 's/\.git$//; s#/$##' \
    | grep -vFx 'https://github.com/omacom-io/omarchy-site' \
    | sort -fu \
    | head -n "$official_max_items"
)

output_file=$(mktemp "$cache_dir/.catalog-output.XXXXXX")
trap 'rm -f "$output_file"' EXIT

jq \
  --arg officialRepositories "$official_repositories" \
  --arg fetchedAt "$(date --iso-8601=seconds)" \
  --argjson maxItems "$catalog_max_items" \
  'def bounded_string($maximum):
    if type == "string" then .[0:$maximum] else "" end;
  {
    sourceUrl: "https://omarchytheme.com/",
    fetchedAt: $fetchedAt,
    officialRepositories: ($officialRepositories | split("\n") | map(select(length > 0))),
    themes: [
      limit($maxItems; .[])
      | select(.is_builtin != 1)
      | {
          name: (.name | bounded_string(120)),
          repositoryUrl: ((.canonical_github_url // .github_url) | bounded_string(512)),
          owner: (.github_owner | bounded_string(80)),
          description: (.description | bounded_string(500)),
          stars: (if (.stars | type) == "number" then .stars else 0 end),
          apps: (.apps_json | bounded_string(4096)),
          securityWarnings: (.security_warnings | bounded_string(8192)),
          # The default Quickshell Qt image stack does not necessarily include
          # the optional WebP decoder. Prefer the repository preview so the
          # catalog works on a stock Omarchy installation.
          previewUrl: (.preview_url | bounded_string(512))
        }
    ]
  }' "$catalog_cache" >"$output_file"

if [[ $(stat -c '%s' "$output_file") -gt $output_max_bytes ]]; then
  echo "Theme catalog output exceeds the safe size limit." >&2
  exit 1
fi

jq -e --argjson maxItems "$catalog_max_items" \
  'type == "object" and (.themes | type) == "array" and (.themes | length) <= $maxItems' \
  "$output_file" >/dev/null

cat "$output_file"
