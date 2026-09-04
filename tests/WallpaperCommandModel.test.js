const test = require("node:test")
const assert = require("node:assert/strict")

const WallpaperCommandModel = require("../v0200/WallpaperCommandModel.js")

test("parses bounded absolute favorite paths and tolerates corrupt state", () => {
  assert.deepEqual(
    WallpaperCommandModel.parseState(
      JSON.stringify({ favorites: ["/walls/a.jpg", "relative.jpg", "/walls/a.jpg"] })
    ),
    { version: 1, favorites: ["/walls/a.jpg"] }
  )
  assert.deepEqual(WallpaperCommandModel.parseState("not json").favorites, [])
})

test("toggles favorites with the newest selection first", () => {
  assert.deepEqual(
    WallpaperCommandModel.toggleFavorite(["/walls/a.jpg"], "/walls/b.jpg"),
    ["/walls/b.jpg", "/walls/a.jpg"]
  )
  assert.deepEqual(
    WallpaperCommandModel.toggleFavorite(["/walls/a.jpg", "/walls/b.jpg"], "/walls/a.jpg"),
    ["/walls/b.jpg"]
  )
})

test("moves favorites into a stable front section without losing rows", () => {
  const images = ["a", "b", "c", "d"].map((name) => ({ filePath: `/walls/${name}.jpg` }))
  const result = WallpaperCommandModel.prioritizeFavorites(images, [
    "/walls/d.jpg",
    "/walls/b.jpg"
  ])

  assert.deepEqual(
    result.map((image) => image.filePath),
    ["/walls/d.jpg", "/walls/b.jpg", "/walls/a.jpg", "/walls/c.jpg"]
  )
})

test("serializes normalized forward-compatible state", () => {
  assert.deepEqual(JSON.parse(WallpaperCommandModel.serializeState(["/walls/a.jpg"])), {
    version: 1,
    favorites: ["/walls/a.jpg"]
  })
})
