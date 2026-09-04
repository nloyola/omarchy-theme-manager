const test = require("node:test")
const assert = require("node:assert/strict")

const Palette = require("../v0200/WallpaperPaletteModel.js")

const histogram = `
  1057: (14,20,36) #0E1424 srgb(5%,8%,14%)
   763: (37,50,79) #25324F srgb(15%,20%,31%)
   305: (82,160,190) #52A0BE srgb(32%,63%,74%)
   260: (168,102,183) #A866B7 srgb(66%,40%,72%)
`

test("parses a bounded ImageMagick histogram", () => {
  assert.deepEqual(
    Palette.parseHistogram(histogram).map(({ count, hex }) => ({ count, hex })),
    [
      { count: 1057, hex: "#0E1424" },
      { count: 763, hex: "#25324F" },
      { count: 305, hex: "#52A0BE" },
      { count: 260, hex: "#A866B7" }
    ]
  )
  assert.equal(Palette.parseHistogram("garbage").length, 0)
})

test("keeps the populous field as the base and promotes a vivid accent", () => {
  const palette = Palette.paletteFromHistogram(histogram)
  assert.equal(palette.base, "#0E1424")
  assert.ok(["#52A0BE", "#A866B7"].includes(palette.accent))
  assert.notEqual(palette.secondary, palette.accent)
})

test("measures hue across the wraparound boundary", () => {
  assert.equal(Palette.hueDistance(350, 10), 20 / 180)
  assert.equal(Palette.paletteFromHistogram("not a histogram"), null)
})
