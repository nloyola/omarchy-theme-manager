const test = require("node:test")
const assert = require("node:assert/strict")

const model = require("../ThemeCatalogModel.js")

test("normalizes supported GitHub repository URL variants", () => {
  const expected = "https://github.com/example/omarchy-night-theme"

  assert.equal(
    model.normalizeRepositoryUrl("https://GitHub.com/Example/Omarchy-Night-Theme.git/"),
    expected
  )
  assert.equal(
    model.normalizeRepositoryUrl("git@github.com:Example/Omarchy-Night-Theme.git"),
    expected
  )
  assert.equal(
    model.normalizeRepositoryUrl("git://github.com/Example/Omarchy-Night-Theme"),
    expected
  )
  assert.equal(model.normalizeRepositoryUrl("https://gitlab.com/example/theme"), "")
  assert.equal(model.normalizeRepositoryUrl("https://github.com/example/repo/tree/main"), "")
})

test("derives the same destination slug as the Omarchy installer", () => {
  assert.equal(
    model.installSlugForRepositoryUrl("https://github.com/example/omarchy-amberbyte-theme.git"),
    "amberbyte"
  )
  assert.equal(model.installSlugForRepositoryUrl("https://github.com/example/aetheria"), "aetheria")
  assert.equal(model.isSafeThemeSlug("theme.v2"), true)
  assert.equal(model.isSafeThemeSlug("../outside"), false)
})

test("deduplicates by canonical repository instead of display name", () => {
  const rows = model.catalogRows({
    officialRepositories: ["https://github.com/example/omarchy-night-theme"],
    themes: [
      {
        name: "Night",
        repositoryUrl: "https://github.com/Example/Omarchy-Night-Theme.git",
        stars: 4
      },
      {
        name: "Night Theme",
        repositoryUrl: "git@github.com:example/omarchy-night-theme.git",
        stars: 9
      },
      {
        name: "Night",
        repositoryUrl: "https://github.com/another/night-theme"
      }
    ]
  })

  assert.equal(rows.length, 2)
  assert.equal(rows[0].official, true)
  assert.equal(rows[0].stars, 9)
  assert.equal(rows[1].repositoryUrl, "https://github.com/another/night-theme")
})

test("blocks installed repositories and stock-slug collisions", () => {
  const payload = {
    themes: [
      {
        name: "Installed elsewhere",
        repositoryUrl: "https://github.com/example/omarchy-installed-theme"
      },
      {
        name: "Miasma fork",
        repositoryUrl: "https://github.com/example/omarchy-miasma-theme"
      },
      {
        name: "Fresh",
        repositoryUrl: "https://github.com/example/omarchy-fresh-theme"
      }
    ]
  }

  const rows = model.catalogRows(payload, {
    installedThemes: {},
    installedRepositories: ["git@github.com:example/omarchy-installed-theme.git"],
    stockThemes: { miasma: true }
  })

  const bySlug = Object.fromEntries(rows.map((row) => [row.installSlug, row]))
  assert.equal(bySlug.installed.installed, true)
  assert.equal(bySlug.installed.canInstall, false)
  assert.equal(bySlug.miasma.stockConflict, true)
  assert.equal(bySlug.miasma.canInstall, false)
  assert.equal(bySlug.fresh.canInstall, true)
})

test("sanitizes remote display values and rejects non-HTTPS previews", () => {
  assert.equal(model.plainTextValue("<b>Night</b>\nTheme"), "b Night /b Theme")
  assert.deepEqual(model.parsedArray("not-json"), [])
  assert.equal(
    model.safePreviewUrl("https://example.com/preview.png"),
    "https://example.com/preview.png"
  )
  assert.equal(model.safePreviewUrl("file:///etc/passwd"), "")
  assert.equal(model.safePreviewUrl("https://example.com/a b.png"), "")
})

test("surfaces catalog warnings in an explicit installation confirmation", () => {
  const [row] = model.catalogRows({
    officialRepositories: ["https://github.com/example/omarchy-safe-theme"],
    themes: [
      {
        name: "Safe",
        owner: "example",
        repositoryUrl: "https://github.com/example/omarchy-safe-theme",
        securityWarnings: '["installs an editor <extension>"]'
      }
    ]
  })

  const message = model.installConfirmationMessage(row)
  assert.match(message, /cloned and applied immediately/)
  assert.match(message, /Officially listed by Omarchy/)
  assert.match(message, /Catalog note: installs an editor extension/)
})

test("sorts installable themes ahead of blocked catalog entries", () => {
  const rows = model.catalogRows(
    {
      officialRepositories: [
        "https://github.com/example/omarchy-blocked-theme",
        "https://github.com/example/omarchy-fresh-theme"
      ],
      themes: [
        {
          name: "Blocked",
          repositoryUrl: "https://github.com/example/omarchy-blocked-theme",
          stars: 100
        },
        {
          name: "Fresh",
          repositoryUrl: "https://github.com/example/omarchy-fresh-theme",
          stars: 1
        }
      ]
    },
    { stockThemes: { blocked: true } }
  )

  assert.equal(rows[0].installSlug, "fresh")
  assert.equal(rows[1].installSlug, "blocked")
})
