const test = require("node:test")
const assert = require("node:assert/strict")

const WallpaperCommandModel = require("../v0200/WallpaperCommandModel.js")

const context = {
  themeRoot: "/home/user/.local/state/omarchy/current/theme/backgrounds",
  themeName: "Tokyo Night"
}

test("parses bounded favorite identities and migrates legacy paths", () => {
  assert.deepEqual(
    WallpaperCommandModel.parseState(
      JSON.stringify({ favorites: ["/walls/a.jpg", "relative.jpg", "/walls/a.jpg"] }),
      context
    ),
    { version: 2, favorites: ["path:%2Fwalls%2Fa.jpg"] }
  )
  assert.deepEqual(WallpaperCommandModel.parseState("not json").favorites, [])
})

test("toggles favorites with the newest selection first", () => {
  assert.deepEqual(
    WallpaperCommandModel.toggleFavorite(["path:%2Fwalls%2Fa.jpg"], "/walls/b.jpg"),
    ["path:%2Fwalls%2Fb.jpg", "path:%2Fwalls%2Fa.jpg"]
  )
  assert.deepEqual(
    WallpaperCommandModel.toggleFavorite(
      ["path:%2Fwalls%2Fa.jpg", "path:%2Fwalls%2Fb.jpg"],
      "/walls/a.jpg"
    ),
    ["path:%2Fwalls%2Fb.jpg"]
  )
})

test("keeps current-theme favorites bound to the theme identity", () => {
  const path = context.themeRoot + "/omarchy.webp"
  const favorite = WallpaperCommandModel.favoriteIdForPath(path, context)

  assert.equal(favorite, "theme:Tokyo%20Night:omarchy.webp")
  assert.equal(WallpaperCommandModel.isFavorite([favorite], path, context), true)
  assert.equal(
    WallpaperCommandModel.isFavorite([favorite], path, { ...context, themeName: "Nord" }),
    false
  )
})

test("moves favorites into a stable front section without losing rows", () => {
  const images = ["a", "b", "c", "d"].map((name) => ({ filePath: `/walls/${name}.jpg` }))
  const result = WallpaperCommandModel.prioritizeFavorites(images, [
    "path:%2Fwalls%2Fd.jpg",
    "path:%2Fwalls%2Fb.jpg"
  ])

  assert.deepEqual(
    result.map((image) => image.filePath),
    ["/walls/d.jpg", "/walls/b.jpg", "/walls/a.jpg", "/walls/c.jpg"]
  )
})

test("serializes normalized versioned state", () => {
  assert.deepEqual(JSON.parse(WallpaperCommandModel.serializeState(["path:%2Fwalls%2Fa.jpg"])), {
    version: 2,
    favorites: ["path:%2Fwalls%2Fa.jpg"]
  })
})
