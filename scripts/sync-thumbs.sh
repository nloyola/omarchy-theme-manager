#!/usr/bin/env bash
# LOCAL: fill the thumbnail cache list.sh reads.
#
#   sync-thumbs.sh <<<"$image_dirs"      # newline separated, on stdin
#
# list.sh already LOOKS for a thumbnail per image and falls back to the image
# itself when there is none. Under Omarchy something else fills that cache;
# standalone, nothing did - it was empty, so the wallpaper grid was handed 658
# full-size originals averaging 3.6MB (one is 62MB), loaded synchronously on
# the GUI thread. This is the missing half.
#
# THE NAMING IS list.sh's, NOT OURS. It keys a thumbnail by
#
#     md5( "<path>\t<size>:<mtime>" ).jpg
#
# so the name changes by itself when an image is edited in place, and a stale
# thumbnail can never be served for new content. Recomputing the same hash here
# is what makes the two halves meet; index.tsv is written as well, purely so
# list.sh can look the hash up instead of forking md5sum per image.
#
# Missing thumbnails are also why a cold run was slow: list.sh's fallback for a
# missing thumbnail is an md5 of the FILE CONTENT, hunting for one cached by an
# older on-demand picker - 2.4GB of hashing on every open. With the cache full
# that branch is never reached.
set -euo pipefail

cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/qs-theme-manager/image-selector
index_file=$cache_dir/index.tsv

command -v magick >/dev/null 2>&1 || {
    echo "sync-thumbs: no magick; leaving the cache alone" >&2
    exit 0
}

mkdir -p "$cache_dir"

expected=$(mktemp)
index_new=$(mktemp)
trap 'rm -f "$expected" "$index_new"' EXIT

while IFS= read -r dir; do
    [[ -n $dir && -d $dir ]] || continue
    # -L, matching list.sh: the wallpaper library is real directories here, but
    # a theme's backgrounds can be linked in and the two must agree on what a
    # file is.
    find -L "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
        -print0 2>/dev/null
done | while IFS= read -r -d '' image; do
    signature=$(stat -Lc '%s:%Y' "$image") || continue
    hash=$(printf '%s\t%s' "$image" "$signature" | md5sum | cut -d ' ' -f 1)
    thumbnail=$cache_dir/$hash.jpg

    printf '%s\n' "$hash.jpg" >>"$expected"
    printf '%s\t%s\t%s\n' "$image" "$signature" "$hash" >>"$index_new"

    [[ -f $thumbnail ]] && continue

    temporary=$thumbnail.tmp.jpg
    if magick "$image" -auto-orient -thumbnail '1280x720>' -quality 82 "$temporary" 2>/dev/null; then
        mv -f "$temporary" "$thumbnail"
    else
        rm -f "$temporary"
    fi
done

# The index is rewritten whole rather than appended to, so an image that left
# the library leaves no line behind to be matched by a later file of the same
# name.
mv -f "$index_new" "$index_file"

# Prune. A thumbnail whose name is not expected is one whose image was edited,
# renamed or removed - its hash moved with it, and nothing will ask for this
# name again.
while IFS= read -r -d '' thumbnail; do
    name=${thumbnail##*/}
    grep -Fqx -- "$name" "$expected" || rm -f "$thumbnail"
done < <(find "$cache_dir" -maxdepth 1 -type f -name '*.jpg' -print0)
