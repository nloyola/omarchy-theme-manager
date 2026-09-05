const test = require("node:test")
const assert = require("node:assert/strict")

const model = require("../v0200/ThemeManagerModel.js")

// LOCAL: the preview cache is the one `qs-theme preview-links` fills, not
// omarchy's theme-selector. Same shape - a directory of <name>.<ext> - so the
// stem is still the theme name and everything downstream is unchanged.
test("recognizes only paths from the theme preview cache", () => {
  assert.equal(
    model.themeNameForPath("/home/test/.cache/qs-theme/previews/amberbyte.png"),
    "amberbyte"
  )
  assert.equal(model.themeNameForPath("/home/test/Pictures/backgrounds/amberbyte.png"), "")
  assert.equal(model.isThemePreviewPath("/tmp/qs-theme/previews/no-extension"), false)
  // A path from an omarchy install on the same machine is not this one.
  assert.equal(
    model.themeNameForPath("/home/test/.cache/omarchy/theme-selector/previews/amberbyte.png"),
    ""
  )
})

test("validates theme names before they can reach a destructive command", () => {
  for (const name of ["amberbyte", "tokyo-night", "catppuccin_mocha", "theme.v2"])
    assert.equal(model.isSafeThemeName(name), true, name)

  for (const name of ["", ".", "..", "../theme", "theme/name", " theme", "theme name", "-theme"])
    assert.equal(model.isSafeThemeName(name), false, name)
})

test("builds a de-duplicated inventory and ignores unsafe output", () => {
  const themes = model.themeMapFromText(
    ["amberbyte", "tokyo-night", "../outside", "amberbyte", ""].join("\n")
  )

  assert.deepEqual(themes, { amberbyte: true, "tokyo-night": true })
  assert.equal(model.hasTheme(themes, "amberbyte"), true)
  assert.equal(model.hasTheme(themes, "outside"), false)
  assert.equal(model.hasTheme(themes, "../outside"), false)
})

test("parses user, stock, and Git-origin inventory rows", () => {
  const inventory = model.themeInventoryFromText(
    [
      "user\tamberbyte\tgit@github.com:tahfizhabib/omarchy-amberbyte-theme.git",
      "stock\tmiasma\t",
      "user\t../outside\thttps://github.com/example/outside"
    ].join("\n")
  )

  assert.deepEqual(inventory.installedThemes, { amberbyte: true })
  assert.deepEqual(inventory.stockThemes, { miasma: true })
  assert.deepEqual(inventory.installedRepositories, [
    "git@github.com:tahfizhabib/omarchy-amberbyte-theme.git"
  ])
})

test("removes an inventory entry without mutating the source object", () => {
  const themes = { amberbyte: true, ash: true }
  const result = model.withoutTheme(themes, "amberbyte")

  assert.deepEqual(result, { ash: true })
  assert.deepEqual(themes, { amberbyte: true, ash: true })
})

test("removes only the named theme row without mutating the source array", () => {
  const images = [
    { filePath: "/cache/aetheria.png" },
    { filePath: "/cache/amberbyte.png" },
    { filePath: "/cache/ash.png" }
  ]

  const result = model.withoutNamedImage(images, "amberbyte")

  assert.deepEqual(
    result.map((item) => model.fileStem(item.filePath)),
    ["aetheria", "ash"]
  )
  assert.equal(images.length, 3)
})

test("finds a just-installed theme in rescanned rows by name", () => {
  const images = [
    { filePath: "/cache/qs-theme/previews/aetheria.png" },
    { filePath: "/cache/qs-theme/previews/mechanoonna.png" },
    { filePath: "/cache/qs-theme/previews/ash.png" }
  ]

  assert.equal(model.indexOfNamedImage(images, "mechanoonna"), 1)
  assert.equal(model.indexOfNamedImage(images, "aetheria"), 0)
})

test("reports a theme missing from the rows rather than a stray index", () => {
  const images = [{ filePath: "/cache/qs-theme/previews/aetheria.png" }]

  assert.equal(model.indexOfNamedImage(images, "mechanoonna"), -1)
  assert.equal(model.indexOfNamedImage([], "aetheria"), -1)
  assert.equal(model.indexOfNamedImage(null, "aetheria"), -1)
})

test("refuses to place the cursor from an unsafe theme name", () => {
  const images = [{ filePath: "/cache/qs-theme/previews/aetheria.png" }]

  assert.equal(model.indexOfNamedImage(images, ".."), -1)
  assert.equal(model.indexOfNamedImage(images, ""), -1)
})

test("matches the tile by stem, whatever extension preview-links gave it", () => {
  const images = [{ filePath: "/cache/qs-theme/previews/mechanoonna.jpg" }]

  assert.equal(model.indexOfNamedImage(images, "mechanoonna"), 0)
})

test("formats theme names for user-facing confirmation and errors", () => {
  assert.equal(model.labelForThemeName("catppuccin_mocha"), "Catppuccin Mocha")
  assert.equal(model.labelForThemeName("tokyo-night"), "Tokyo Night")
})
