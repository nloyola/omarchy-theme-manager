#!/usr/bin/env bash
# LOCAL: open the theme manager, and act on what comes back.
#
#   theme-manager.sh [themes|wallpapers]
#
# Upstream never needs this: omarchy-shell summons the overlay over IPC and
# owns the selection protocol at both ends. Standalone, something has to play
# that part, and this is it - build the grid's directory, hand the overlay a
# request, wait for the process to finish, then do what the answer says.
#
# The protocol itself is not forked. openSelector() still writes the chosen
# path into the selection file and touches the done file, exactly as it does
# under omarchy; this only reads the other end of it.
#
# WHY THE GRID IS A DIRECTORY OF SYMLINKS. The overlay browses images, so a
# theme has to look like one. `qs-theme preview-links` fills a directory with
# <name>.<ext> pointing at each theme's first wallpaper, and the theme name is
# then the stem - which is the shape ThemeManagerModel.themeNameForPath reads,
# and the same shape omarchy's theme-selector previews had.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)

mode=${1:-themes}
qs_theme=${QS_THEME_BIN:-$HOME/.local/bin/qs-theme}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/qs-theme-manager
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/qs-theme-manager

thumbnails_are_stale() {
    local stamp=$1 dirs=$2 dir

    [[ -f $stamp ]] || return 0

    while IFS= read -r dir; do
        [[ -n $dir && -d $dir ]] || continue
        [[ -n $(find -L "$dir" -maxdepth 1 -newer "$stamp" -print -quit 2>/dev/null) ]] && return 0
    done <<<"$dirs"

    return 1
}

command -v quickshell >/dev/null 2>&1 || { echo "quickshell is not installed" >&2; exit 3; }
[[ -x $qs_theme ]] || { echo "no qs-theme at $qs_theme" >&2; exit 3; }

# The module links are not committed, so a fresh clone has none. Cheap enough
# to confirm on every open rather than making it a separate setup step people
# have to know about.
"$script_dir/link-shell-modules.sh"

mkdir -p "$state_dir" "$cache_dir"

case $mode in
    themes)
        # No directory argument: qs-theme's own default is
        # $XDG_CACHE_HOME/qs-theme/previews, and that "/qs-theme/previews/"
        # is what ThemeManagerModel.isThemePreviewPath matches on. Naming a
        # directory here would put the grid somewhere the model does not
        # recognise as themes, and every tile would come back as a wallpaper.
        image_dirs=$("$qs_theme" preview-links)
        show_labels=true
        ;;
    wallpapers)
        # LOCAL: WHY THE SUBJECT FOLDERS ARE NAMED ONE BY ONE. list.sh scans
        # every directory it is handed with `find -maxdepth 1`, and this host
        # files each wallpaper one level down, in a subject folder (Landscapes,
        # lotr, omarchy, 4k, ...). Naming only the roots therefore lists
        # nothing at all - which is what this mode did until the wallpaper keys
        # moved onto it. imageDirs is newline separated, so the answer is to
        # hand over the roots AND their immediate children, which is also the
        # shape isLocalWallpaperRequest already reads.
        #
        # Two roots, because this desktop has two: the library qs-theme install
        # copies a theme's backgrounds into, and the local tree beside it. The
        # library now lives inside that tree (~/wallpapers/library, a Syncthing
        # folder, next to the unsynced 4k stash), so the roots overlap - naming
        # it anyway is what puts its per-theme subdirectories in the grid,
        # since only a root's immediate children are listed. sort -u drops the
        # duplicate. QS_WALLPAPER_SOURCES overrides with a colon separated list
        # - the same variable, with the same meaning, as the picker this
        # replaced.
        sources=${QS_WALLPAPER_SOURCES:-${QS_THEME_WALLPAPER_LIB:-$HOME/wallpapers/library}:$HOME/wallpapers}
        image_dirs=$(
            while IFS= read -r root; do
                [[ -n $root && -d $root ]] || continue
                printf '%s\n' "$root"
                # -not -name '.*' because the library is a Syncthing folder:
                # .stfolder is an empty marker and .stversions holds deleted
                # wallpapers, neither of which belongs in the grid.
                find -L "$root" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print
            done <<<"${sources//:/$'\n'}" | sort -u
        )
        [[ -n $image_dirs ]] || { echo "no wallpaper directory in $sources" >&2; exit 3; }

        # THUMBNAILS. list.sh serves the original when it finds no thumbnail
        # cached, and nothing off Omarchy ever filled that cache - so the grid
        # was handed 658 full-size images, 2.4GB of them, loaded on the GUI
        # thread. scripts/sync-thumbs.sh is the missing half; see its header.
        #
        # Only when something moved: one `find -newer` per directory, stopping
        # at the first hit. Adding, deleting or renaming an image bumps its
        # folder's mtime and editing one in place bumps the file's, so both are
        # caught, and a new subject folder bumps the root's. The stamp is
        # written only on success, so an interrupted pass is redone rather than
        # leaving permanent gaps in the grid.
        stamp=$cache_dir/thumbs.stamp
        if thumbnails_are_stale "$stamp" "$image_dirs"; then
            printf '%s\n' "$image_dirs" | "$script_dir/sync-thumbs.sh" && touch "$stamp"
        fi

        show_labels=false
        ;;
    *)
        echo "usage: theme-manager.sh [themes|wallpapers]" >&2
        exit 2
        ;;
esac

selection_file=$(mktemp "$state_dir/selection.XXXXXX")
done_file=$(mktemp "$state_dir/done.XXXXXX")
trap 'rm -f "$selection_file" "$done_file"' EXIT

# Exactly the payload the plugin host passes, so openSelector() sees nothing
# unusual. selectedImage starts the cursor on the theme already in force.
selected=""
if [[ $mode == themes ]]; then
    current=$("$qs_theme" current 2>/dev/null || true)
    if [[ -n $current ]]; then
        selected=$(find "$image_dirs" -maxdepth 1 -name "$current.*" -print -quit 2>/dev/null || true)
    fi
fi

export QS_TM_ROOT=$project_dir
export QS_THEME_BIN=$qs_theme
QS_TM_PAYLOAD=$(
    IMAGE_DIRS=$image_dirs SELECTED=$selected \
    SELECTION_FILE=$selection_file DONE_FILE=$done_file SHOW_LABELS=$show_labels \
    python3 -c 'import json, os; print(json.dumps({
        "imageDirs": os.environ["IMAGE_DIRS"],
        "selectedImage": os.environ["SELECTED"],
        "selectionFile": os.environ["SELECTION_FILE"],
        "doneFile": os.environ["DONE_FILE"],
        "showLabels": os.environ["SHOW_LABELS"] == "true",
        "filterable": True,
    }))'
)
export QS_TM_PAYLOAD

# One at a time. Two overlays on the Overlay layer both taking exclusive
# keyboard focus is a session you have to kill from a TTY.
if command -v flock >/dev/null 2>&1; then
    flock -n "$state_dir/manager.lock" quickshell -p "$project_dir/Main.qml" || exit 0
else
    quickshell -p "$project_dir/Main.qml"
fi

# Nothing chosen is the ordinary way out of a picker, not a failure.
[[ -s $selection_file ]] || exit 0
choice=$(head -1 "$selection_file")
[[ -n $choice ]] || exit 0

case $mode in
    themes)
        name=${choice##*/}
        name=${name%.*}
        exec "$qs_theme" set "$name"
        ;;
    wallpapers)
        wallpaper=${QS_WALLPAPER_BIN:-$HOME/.local/bin/qs-wallpaper}

        # WHICH MONITOR. Wallpapers are per-monitor here, so a pick has to name
        # one. QS_WALLPAPER_OUTPUT is what the caller knew at open time - the
        # bar's display chip stamps the monitor its popup belongs to, because
        # by the time a pick lands focus may well have moved. Only trust it
        # while it still names an enabled output; qs-wallpaper's own list is
        # what decides which monitors count, under Hyprland and i3 alike.
        outputs=$("$wallpaper" list | jq -r '.outputs[].name') || exit 1
        known() { printf '%s\n' "$outputs" | grep -Fxq -- "$1"; }

        output=""
        if [[ -n ${QS_WALLPAPER_OUTPUT:-} ]] && known "$QS_WALLPAPER_OUTPUT"; then
            output=$QS_WALLPAPER_OUTPUT
        fi
        if [[ -z $output ]] && command -v hyprctl >/dev/null 2>&1; then
            focused=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name') || focused=""
            # An `a && b && c` statement here would be the script's exit status
            # when no monitor is focused, and `set -e` would take that as a
            # failure and quit before the fallback below ever ran.
            if [[ -n $focused ]] && known "$focused"; then
                output=$focused
            fi
        fi
        if [[ -z $output ]]; then
            output=$(printf '%s\n' "$outputs" | head -1)
            [[ -n $output ]] || { echo "no output to set the wallpaper on" >&2; exit 1; }
            echo "no monitor named, falling back to $output" >&2
        fi

        exec "$wallpaper" set "$output" "$choice"
        ;;
esac
