# Changelog

## 0.4.0 - 2026-09-04

- Add persistent, theme-aware local wallpaper favorites with favorite-first
  ordering and a favorites-only view.
- Add live wallpaper palette extraction and palette-driven picker atmosphere
  without changing the active desktop theme.
- Add native mouse controls and smooth, no-overshoot carousel motion.
- Keep palette sampling bounded to one attempt per selected source and fall
  back cleanly when an image cannot be sampled.
- Extend disposable-VM acceptance to cover favorite persistence, public
  shortcuts, live palette readiness, and the complete plugin lifecycle.
- Thanks to [Fred Nix](https://github.com/nixfred) for the wallpaper command
  center contribution.

## 0.2.0 - 2026-08-29

- Add contextual SFW Wallhaven browse, keyword search, staged filters,
  continuous pagination, full-resolution download, and apply to the native
  background-picker path.
- Delegate Wallhaven search, thumbnail caching, and downloads to Aether 4.19+
  with bounded output, strict record validation, and cache/data path checks.
- Keep theme catalog, safe uninstall, and generic image selection independent
  by classifying every row-backed picker request instead of retaining stale
  directories between invocations.
- Use Wallhaven's official palette values and document that color is a metadata
  palette match rather than dominant color or brightness.
- Version the complete QML/JavaScript runtime graph to prevent mixed Qt caches
  during updates.
- Add combined contract, model, source-quality, and disposable-VM acceptance
  coverage for both theme and wallpaper journeys.

## 0.1.0

- Add catalog browsing, search, previews, trust metadata, and confirmed theme
  installation through Omarchy's CLI.
- Add safe uninstall controls for non-active user themes.
- Deduplicate by canonical GitHub repository and block installed or stock-theme
  collisions.
- Add validated caching with offline fallback.
- Bound remote downloads, catalog records, and the QML payload, and allowlist
  GitHub preview hosts and paths.
- Preserve the native theme and background picker behavior.
- Add model tests and reproducible JavaScript, shell, QML, formatting, and
  manifest checks.
