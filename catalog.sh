#!/bin/bash

set -euo pipefail

cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-theme-manager
catalog_cache="$cache_dir/themes-data.json"
official_cache="$cache_dir/official-themes.html"
catalog_url=https://raw.githubusercontent.com/limehawk/omarchy-theme-website/main/src/data/themes-data.json
official_url=https://omarchy.org/themes/
max_age=${OMARCHY_THEME_CATALOG_MAX_AGE:-21600}
force_refresh=${1:-}

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
  local temporary

  temporary=$(mktemp "$cache_dir/.download.XXXXXX")
  if curl --fail --location --silent --show-error \
    --connect-timeout 10 --max-time 45 \
    --output "$temporary" "$url" \
    && "$validator" "$temporary"; then
    mv "$temporary" "$destination"
    return 0
  fi

  rm -f "$temporary"
  return 1
}

valid_catalog() {
  jq -e 'type == "array" and length > 0 and all(.[]; (.name | type) == "string" and (.github_url | type) == "string")' "$1" >/dev/null
}

valid_official_page() {
  [[ $(grep -oE 'href="https://github\.com/[^"/]*/[^"/]+' "$1" | wc -l) -gt 20 ]]
}

refresh_if_needed() {
  local path=$1
  local url=$2
  local validator=$3

  if [[ $force_refresh == "--refresh" ]] || ! is_fresh "$path"; then
    if ! download "$url" "$path" "$validator"; then
      [[ -f $path ]] || return 1
      echo "Theme catalog refresh failed; using cached data." >&2
    fi
  fi
}

refresh_if_needed "$catalog_cache" "$catalog_url" valid_catalog
refresh_if_needed "$official_cache" "$official_url" valid_official_page

official_repositories=$(
  grep -oE 'href="https://github\.com/[^"/]*/[^"/]+' "$official_cache" \
    | cut -d '"' -f 2 \
    | sed -E 's/\.git$//; s#/$##' \
    | grep -vFx 'https://github.com/omacom-io/omarchy-site' \
    | sort -fu
)

jq \
  --arg officialRepositories "$official_repositories" \
  --arg fetchedAt "$(date --iso-8601=seconds)" \
  '{
    sourceUrl: "https://omarchytheme.com/",
    fetchedAt: $fetchedAt,
    officialRepositories: ($officialRepositories | split("\n") | map(select(length > 0))),
    themes: [
      .[]
      | select(.is_builtin != 1)
      | {
          name,
          repositoryUrl: (.canonical_github_url // .github_url),
          owner: .github_owner,
          description,
          stars,
          apps: .apps_json,
          securityWarnings: .security_warnings,
          # The default Quickshell Qt image stack does not necessarily include
          # the optional WebP decoder. Prefer the repository preview so the
          # catalog works on a stock Omarchy installation.
          previewUrl: .preview_url
        }
    ]
  }' "$catalog_cache"
