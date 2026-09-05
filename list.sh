#!/bin/bash

image_dirs=${1:-}
# LOCAL: this fork keeps its own thumbnail cache rather than sharing
# omarchy's, so an omarchy install on the same machine is untouched.
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/qs-theme-manager/image-selector
index_file="$cache_dir/index.tsv"

mkdir -p "$cache_dir"

# LOCAL: WHY THIS IS ONE PASS AND NOT A LOOP OF COMMANDS. The picker cannot
# show anything until this script has answered, so its cost is the wait before
# the grid appears. The obvious shape - `stat` and `awk` per image, the way
# upstream's handful of theme backgrounds could afford - is two forks and a
# linear scan of the index per file; over this desktop's 658 wallpapers that
# came to 1300 processes and 4.4 seconds of dead time on every open.
#
# So: `find` reports the signature itself (-printf, dereferencing like -L
# does, so it matches the `stat -L` the index was built with), the index is
# read once into a map, and the loop below forks for nothing at all in the
# ordinary case. The only survivors are the two cold paths - an image the
# index has never seen, and the legacy content-keyed thumbnail - which are
# rare by construction once scripts/sync-thumbs.sh has run.
declare -A thumbnail_by_signature
declare -A thumbnail_is_indexed

if [[ -f $index_file ]]; then
  while IFS=$'\t' read -r path signature hash; do
    [[ -n $path && -n $hash ]] || continue
    thumbnail_by_signature["$path"$'\t'"$signature"]=$hash
    thumbnail_is_indexed["$hash.jpg"]=1
  done <"$index_file"
fi

# LOCAL: and WHY THE LEGACY LOOKUP IS ASKED ABOUT ONCE RATHER THAN PER IMAGE.
# The fallback below hashes the image's own bytes, hunting for a thumbnail an
# older picker cached under that name. Nothing on this desktop has one, so it
# was 24MB of PNG hashed on every theme-picker open to prove a negative.
#
# A legacy thumbnail can only be a file in this cache that the index does not
# account for. That is one glob and a lookup per cached file - no forks, no
# reading of image data - and it answers for the whole run.
legacy_possible=0
for cached in "$cache_dir"/*.jpg; do
  [[ -e $cached ]] || break
  if [[ -z ${thumbnail_is_indexed["${cached##*/}"]:-} ]]; then
    legacy_possible=1
    break
  fi
done

while IFS= read -r dir; do
  [[ -n $dir && -d $dir ]] || continue
  find -L "$dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
    -printf '%p\t%s:%Ts\0' 2>/dev/null
done <<<"$image_dirs" | sort -z | while IFS= read -r -d '' record; do
  image=${record%%$'\t'*}
  signature=${record#*$'\t'}
  [[ -n $image && $signature != "$record" ]] || continue

  hash=${thumbnail_by_signature["$image"$'\t'"$signature"]:-}
  if [[ -z $hash ]]; then
    hash=$(printf '%s\t%s' "$image" "$signature" | md5sum | cut -d ' ' -f 1)
  fi

  thumbnail="$cache_dir/$hash.jpg"

  if [[ ! -f $thumbnail && $legacy_possible = 1 ]]; then
    # Older on-demand picker code keyed fallback thumbnails by file content.
    # Keep finding those if a user still has them cached.
    legacy_hash=$(md5sum "$image" 2>/dev/null | cut -d ' ' -f 1)
    if [[ -n $legacy_hash && -f $cache_dir/$legacy_hash.jpg ]]; then
      thumbnail="$cache_dir/$legacy_hash.jpg"
    fi
  fi

  [[ -f $thumbnail ]] || thumbnail=$image
  printf '%s\t%s\n' "$image" "$thumbnail"
done
