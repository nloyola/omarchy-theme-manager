# Running this fork off Omarchy

Upstream is an [Omarchy](https://omarchy.org) shell plugin: `omarchy-shell`
loads `v0200/ImagePicker.qml` as an overlay, hands it a manifest, and drives it
over the shell's IPC. This fork runs the same overlay on a desktop that has no
Omarchy at all, against [`qs-theme`](https://gitlab.com/nloyola/linux-user-config)
instead of the `omarchy` CLI.

Every deviation is marked `LOCAL:` in a comment, so `git grep 'LOCAL:'` is the
complete list and a merge from upstream is readable.

## Open it

    scripts/theme-manager.sh            # themes      ($mod+SHIFT+T)
    scripts/theme-manager.sh wallpapers # wallpapers  ($mod+SHIFT+W)

Both keys, the bar's display chip and the two `style.*` menu entries come here.
They used to go to `qs-wallpaper-picker`, which carried its own theme grid,
wallpaper grid and Wallhaven browser over a separate cache - and whose theme
mode would download a Wallhaven image and then pass its filename to `qs-theme
set`, which is not a theme name, so the pick silently did nothing. One app now
owns all of it.

Wallpapers mode needed two things before it could carry those keys. It scans
the library roots **and their subject folders**, because `list.sh` walks each
directory it is given with `find -maxdepth 1` and every wallpaper here lives one
level down - named only the roots, the grid came up empty. And
`scripts/sync-thumbs.sh` fills the thumbnail cache `list.sh` reads, which off
Omarchy nothing else ever wrote: without it the grid was handed 658 originals
averaging 3.6MB. Both roots come from `QS_WALLPAPER_SOURCES` (colon separated,
defaulting to `$QS_THEME_WALLPAPER_LIB` and `~/wallpapers`).

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

| upstream                                          | here                                |
| ------------------------------------------------- | ----------------------------------- |
| `omarchy theme install <url>`                     | `qs-theme install <url>`            |
| `omarchy theme remove <name>`                     | `qs-theme remove <name>`            |
| `theme-inventory.sh` walking two theme trees      | `qs-theme inventory`                |
| `~/.local/state/omarchy/current/theme.name`       | `~/.local/state/theme/theme.name`   |
| `~/.config/omarchy/wallpaper-command-center.json` | `~/.local/state/qs-theme-manager/…` |
| omarchy's theme-selector previews                 | `qs-theme preview-links`            |

`qs-theme install` refuses a package unless it has a `colors.toml` at its root
that resolves, records the URL to track it by, and copies its `backgrounds/`
into the wallpaper library. `qs-theme remove` refuses the live theme and the
fallback. So the guards at both ends agree rather than one trusting the other.

**The browser asks before it offers.** The catalog can say a package exists; it
cannot say whether `qs-theme` can read it. Plenty of older packages ship a file
per application - `alacritty.toml`, `waybar.css`, `hyprland.conf` - and no
palette at all, and the first sign of that used to be an install that failed
after cloning the whole thing. So the cursor landing on a tile runs `qs-theme
check <url>`, which fetches only that repository's `colors.toml` off `HEAD` and
puts it through the same `resolve` install vets with, writing nothing:

| exit          | the button                             |
| ------------- | -------------------------------------- |
| 0             | `Install`                              |
| 4             | `No palette in this package`, disabled |
| anything else | `Install (unchecked)`, still offered   |

The last row is why there are three states rather than two. An unknown forge or
a dropped connection is not a verdict about the package - install itself is
still the real guard - so a check that learned nothing may not be allowed to
hide a theme that would install fine.

One check runs at a time, and a single queued slot holds only the tile the
cursor is on now, so arrowing across the grid does not line up a fetch for
every tile it passed over. Verdicts are remembered for as long as the picker is
open.

The verdict is applied to the selected entry, in `entryState`, rather than
built into the rows. `enterCatalog` hands the grid its rows once and the answer
arrives long after that, so rebuilding the rows behind the grid would never
reach it - and rebuilding the grid would move the tiles about under the cursor
as each answer landed. Only the footer ever shows a verdict, so only the footer
needs to know one.

Installing and removing write real files into the theme directory, which is a
git repository of its own ([qs-themes](https://github.com/nloyola/qs-themes)) -
so a theme added here shows up as an uncommitted change there, waiting to be
committed, and never in the dotfiles repo that carries it. Only the images
escape: `backgrounds/` goes to the wallpaper library outside any repository.
Switching a theme writes nothing there at all.

The theme grid is a directory of `<name>.<ext>` symlinks that
`qs-theme preview-links` fills, one per theme, pointing at that theme's first
wallpaper - the same shape omarchy's preview cache had, so the theme name is
still the file stem and `ThemeManagerModel` reads it unchanged.

**An install ends on the new theme, not on a closed overlay.** Because the grid
is that directory and `qs-theme install` mints no symlink into it, a finished
install has produced a theme the grid cannot yet show - so closing the picker,
which is what a successful install used to do, made installing look exactly
like doing nothing. A successful install therefore runs `qs-theme preview-links`
before it reports itself finished, and the browser stays busy across the pair:
the two together are what "installed" means to the grid. The picker then leaves
the catalog, rescans the previews directory, and puts the cursor on the theme
that was just installed - found by stem, since the catalog knows the theme's
name and not what its preview turned out to be. A failed `preview-links` still
returns to the grid and says so from there; the theme is installed either way,
only its tile is in doubt.

**Not forked at all:** the Wallhaven browser, its filter sheet and the palette
sampler. `aether` and `magick` are what those shell out to, and both are already
here.

## Requirements

`quickshell`, `qs-theme`, `aether`, `magick`, `jq`, `curl`, `git`, `python3`.
