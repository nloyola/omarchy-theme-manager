# Omarchy Theme Manager

Manage themes and browse Wallhaven wallpapers from Omarchy's native full-screen
picker. Both experiences live in the existing Theme Manager plugin, so Omarchy
still has exactly one replacement for `omarchy.image-picker`.

![Browse themes and Wallhaven from Omarchy's native picker](preview.webp)

## What it adds

### Themes

- Search a cached catalog with previews, authors, stars, notes, and an official
  Omarchy listing badge.
- Install through `omarchy theme install` after explicit confirmation.
- Uninstall non-active themes from `~/.config/omarchy/themes` through
  `omarchy theme remove`.
- Block stock-theme collisions, installed repositories, and removal of the
  active theme.
- Deduplicate catalog entries by canonical GitHub repository URL.

### Wallpapers

- Browse SFW Wallhaven results inside the regular background carousel.
- Type to search by Wallhaven keywords.
- Filter by category, sorting, direction, minimum resolution, and Wallhaven
  palette color.
- Continue browsing automatically near the end of loaded results, with an
  explicit **Load more** fallback.
- Download the selected full-resolution image and apply it through Omarchy's
  existing background-selection round trip.

The Wallhaven action is shown only for background-picker requests. Theme-picker
requests keep the theme catalog and uninstall controls; other image-picker
requests keep Omarchy's stock behavior.

## Aether integration

Wallhaven support deliberately uses Aether's implementation instead of shipping
another network client:

- `aether --wallhaven-thumbs` performs SFW searches and owns the thumbnail
  cache.
- `aether --wallhaven-download` downloads the selected original.
- Search defaults match Aether: all categories, newest first, descending,
  1920x1080 or larger, and two Wallhaven pages per request.
- Queries, filters, and wallpaper ids are separate process arguments; remote
  text is never evaluated by a shell.

Color is Wallhaven's indexed palette metadata, not a brightness or
dominant-color test. A light wallpaper can match **Black** when black appears in
its Wallhaven palette. Random sorting is omitted because Aether does not expose
Wallhaven's response seed across paginated requests.

## Requirements

- Omarchy 4.0 (Quattro)
- Aether 4.19 or newer for the optional Wallhaven browser
- `curl`, `git`, `jq`, and GNU core utilities from the standard Omarchy
  install

Theme browsing and the native picker continue to work if Aether is unavailable;
only a Wallhaven request shows the actionable Aether error.

The public SFW Wallhaven API does not require an API key. Theme Manager does not
expose authenticated purity controls.

## Install

```bash
omarchy plugin add https://github.com/mtolhuys/omarchy-theme-manager.git --enable
```

Existing installations update in place:

```bash
omarchy plugin update io.github.mtolhuys.theme-manager
```

The plugin intentionally declares
`omarchy.clonedFrom: omarchy.image-picker`. Disabling or removing it restores
Omarchy's built-in picker.

## Use

### Theme picker

Open the regular Omarchy theme switcher.

- Choose **Browse themes** or press `Ctrl+B`.
- Type to search, use the arrow keys to navigate, and press `Enter` to install.
- Select an installed theme and choose **Uninstall**, or press `Delete`.
- Press `Escape` to clear a search, leave the catalog, or close the picker.

Omarchy clones and applies an installed theme after confirmation. Change away
from the active theme before removing it.

Catalog metadata is cached for six hours. A previous valid cache remains usable
when refresh fails. See [CATALOG.md](CATALOG.md) for source, trust, and
deduplication details.

### Background picker

Open the regular background switcher with `Super+Ctrl+Space`.

- Choose **Browse Wallhaven** or press `Ctrl+B`.
- Type to search; results refresh after a short pause.
- Choose **Filters** or press `Ctrl+F`, stage the choices, then apply them in
  one request.
- Use Left/Right or Tab/Shift+Tab to move.
- Continue right to load more automatically, or choose **Load more** / press
  `Ctrl+N`.
- Press `Enter` to download and apply the selection.
- Press `Escape` to clear the search, return to local wallpapers, or close.

Inside the filter sheet, use Up/Down between rows, Left/Right between choices,
Space to toggle categories, `D` to reverse direction, `Enter` to apply,
`Backspace` to reset, and `Escape` to cancel.

Downloaded files stay in Aether's wallpaper directory and remain available
outside the plugin.

## Security and privacy

Omarchy shell plugins run unsandboxed with the current user's permissions.
Review plugin and theme sources before enabling them.

For themes, Theme Manager accepts only normalized GitHub repository URLs,
treats catalog fields as bounded plain text, caps remote downloads, records, and
QML output, and loads previews only from strict GitHub host/path allowlists. A
catalog entry or official badge is discovery metadata, not a security
endorsement.

For wallpapers, Theme Manager invokes only Aether and Omarchy's existing picker
helpers. It kills oversized Aether output while it is streaming, caps parsed
records and fields, enforces the requested SFW/category contract, validates
wallpaper ids, accepts previews only from Aether's thumbnail cache, and accepts
downloads only from Aether's wallpaper directory. Search terms are sent to
Wallhaven by Aether.

The plugin has no install hooks and never requests elevated privileges.

## Development and verification

Run the complete source check:

```bash
npm run quality
```

All activation and UI acceptance testing belongs in the disposable Omarchy
plugin lab, not on a daily desktop:

```bash
cd ~/Projects/omarchy/plugin-lab
./bin/lab plugin ~/Projects/plugins/omarchy-theme-manager/tests/lab/acceptance.sh
```

The scenario installs the candidate through Omarchy's real plugin lifecycle,
verifies the versioned runtime, exercises the theme catalog and the contextual
Wallhaven browse/search/filter/download path through real shortcuts, and proves
disable, re-enable, and removal cleanup.

To verify an exact public candidate, point the same scenario at the repository:

```bash
cd ~/Projects/omarchy/plugin-lab
THEME_MANAGER_INSTALL_SOURCE=https://github.com/mtolhuys/omarchy-theme-manager.git \
  ./bin/lab plugin ~/Projects/plugins/omarchy-theme-manager/tests/lab/acceptance.sh
```

Read [UPSTREAM.md](UPSTREAM.md) before rebasing the derived picker files.

## Remove

```bash
omarchy plugin remove io.github.mtolhuys.theme-manager
```

Removing the plugin restores the built-in picker. Installed themes and
downloaded wallpapers are left intact.

## License

MIT. Picker code derived from Omarchy retains its upstream copyright notice in
[LICENSE](LICENSE).
