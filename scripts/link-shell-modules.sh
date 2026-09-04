#!/usr/bin/env bash
# LOCAL: make qs.Commons and qs.Ui resolvable for a standalone run.
#
# The overlay imports qs.Commons and qs.Ui - Style, Color, Util, Border,
# BorderSurface, ConfirmDialog. Under omarchy those come from the shell it is
# a plugin of; here they come from this desktop's own quickshell config, which
# already declares every one of them with the same names and signatures.
#
# Symlinked rather than vendored, because Color reads the live palette that
# qs-theme writes: a copy would freeze the theme manager on whatever colours
# it was cloned with, which is a poor look for a theme manager. Both links are
# gitignored, so nothing machine-specific is committed.

set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell_dir=${QS_SHELL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/default}

for module in Commons Ui; do
    source_dir="$shell_dir/$module"
    if [[ ! -d $source_dir ]]; then
        echo "no $module module at $source_dir (set QS_SHELL_DIR)" >&2
        exit 1
    fi
    ln -sfn -- "$source_dir" "$project_dir/$module"
done
