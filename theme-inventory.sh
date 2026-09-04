#!/bin/bash
# LOCAL: upstream walks omarchy's user and stock theme directories and reads a
# git remote out of each. This desktop has no such split - qs-theme owns the
# theme directory and already publishes the same three columns, including
# which themes came from a package and can be put back after removal.
#
# Kept as a script, rather than deleted, so anything still calling it by path
# gets the same answer the controller gets by calling qs-theme directly.

set -euo pipefail

exec "${QS_THEME_BIN:-$HOME/.local/bin/qs-theme}" inventory
