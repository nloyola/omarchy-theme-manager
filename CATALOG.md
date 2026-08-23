# Catalog policy

Theme Manager combines two sources:

- [omarchytheme.com](https://omarchytheme.com/) supplies searchable discovery
  metadata and repository preview URLs through its versioned
  [theme dataset](https://github.com/limehawk/omarchy-theme-website/blob/main/src/data/themes-data.json).
- [Omarchy's official themes page](https://omarchy.org/themes/) supplies the
  **Official Omarchy listing** badge.

[omarchythemes.com](https://omarchythemes.com/) is not consumed because it does
not currently publish a documented, stable machine-readable feed.

## Identity and safety

The normalized GitHub repository URL is the primary identity. Protocol, `.git`,
trailing-slash, query, fragment, and URL-case variants collapse into one entry.
Different repositories with the same display name remain separate.

Before enabling **Install**, Theme Manager checks the destination slug used by
Omarchy against stock themes, user themes, and the Git origins of installed
themes. Remote text is sanitized and bounded, preview URLs must use HTTPS, and
the repository URL is passed as a separate argument to Omarchy's installer.

Catalog records and badges are not security endorsements. Installation always
requires confirmation, states that Omarchy applies the theme immediately, and
shows catalog notes when present.

## Cache

Validated downloads are written atomically under
`$XDG_CACHE_HOME/omarchy-theme-manager`, normally
`~/.cache/omarchy-theme-manager`. The cache refreshes every six hours and falls
back to the last valid copy when a source is unavailable. Run
`catalog.sh --refresh` for an immediate refresh.

## Source licensing

The `omarchytheme.com` README labels the project MIT, but its repository
currently lacks the referenced `LICENSE` file. Theme Manager fetches rather
than bundles the dataset and links previews from their source repositories.
Before marketplace submission, confirm this use with the source owner or wait
for the stated license file to be added.
