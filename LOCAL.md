# Running this fork off Omarchy

Upstream is an [Omarchy](https://omarchy.org) shell plugin: `omarchy-shell`
loads `v0200/ImagePicker.qml` as an overlay, hands it a manifest, and drives it
over the shell's IPC. This fork runs the same overlay on a desktop that has no
Omarchy at all, against [`qs-theme`](https://gitlab.com/nloyola/linux-user-config)
instead of the `omarchy` CLI.

Every deviation is marked `LOCAL:` in a comment, so `git grep 'LOCAL:'` is the
complete list and a merge from upstream is readable.

## Open it

    scripts/theme-manager.sh            # themes
    scripts/theme-manager.sh wallpapers # the wallpaper library

## What changed, and why

**There is a host now.** `Main.qml` is a Quickshell config root that
instantiates the overlay, opens it once and exits when it closes, and
`scripts/theme-manager.sh` plays the part omarchy-shell used to: it builds the
grid's directory, hands over a request, and reads the answer back. The request
protocol itself is untouched - `openSelector()` still writes the chosen path to
a selection file and touches a done file.

**`qs.Commons` and `qs.Ui` are symlinked, not vendored.** They come from the
desktop's own Quickshell config, which already declares `Style`, `Color`,
`Util`, `Border`, `BorderSurface` and `ConfirmDialog` with the same names and
signatures - `Style.space(px)` included. `scripts/link-shell-modules.sh` makes
the links and the launcher calls it on every open; both are gitignored. Copies
would freeze a theme manager on the colours it was cloned with, since `Color`
reads the palette `qs-theme` writes.

The one type that had to be written was `Button`, which lives in that config's
`Ui` module rather than here, so nothing in `v0200/` needed changing for it.

**Every theme operation goes through `qs-theme`.**

| upstream | here |
| --- | --- |
| `omarchy theme install <url>` | `qs-theme install <url>` |
| `omarchy theme remove <name>` | `qs-theme remove <name>` |
| `theme-inventory.sh` walking two theme trees | `qs-theme inventory` |
| `~/.local/state/omarchy/current/theme.name` | `~/.local/state/theme/theme.name` |
| `~/.config/omarchy/wallpaper-command-center.json` | `~/.local/state/qs-theme-manager/…` |
| omarchy's theme-selector previews | `qs-theme preview-links` |

`qs-theme install` refuses a package unless it has a `colors.toml` at its root
that resolves, records the URL to track it by, and copies its `backgrounds/`
into the wallpaper library. `qs-theme remove` refuses the live theme and the
fallback. So the guards at both ends agree rather than one trusting the other.

The theme grid is a directory of `<name>.<ext>` symlinks that
`qs-theme preview-links` fills, one per theme, pointing at that theme's first
wallpaper - the same shape omarchy's preview cache had, so the theme name is
still the file stem and `ThemeManagerModel` reads it unchanged.

**Not forked at all:** the Wallhaven browser, its filter sheet and the palette
sampler. `aether` and `magick` are what those shell out to, and both are already
here.

## Requirements

`quickshell`, `qs-theme`, `aether`, `magick`, `jq`, `curl`, `git`, `python3`.
