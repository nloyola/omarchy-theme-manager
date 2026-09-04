const test = require("node:test")
const assert = require("node:assert/strict")
const { readFile } = require("node:fs/promises")
const { dirname, join } = require("node:path")
const process = require("node:process")

const read = (path) => readFile(join(process.cwd(), path), "utf8")

test("keeps the published Theme Manager identity as the sole picker clone", async () => {
  const manifest = JSON.parse(await read("manifest.json"))
  assert.equal(manifest.id, "io.github.mtolhuys.theme-manager")
  assert.equal(manifest.version, "0.3.0")
  assert.deepEqual(manifest.kinds, ["overlay"])
  assert.match(manifest.entryPoints.overlay, /^v[0-9]{4}\/ImagePicker\.qml$/)
  assert.equal(manifest.omarchy.clonedFrom, "omarchy.image-picker")
  assert.equal(manifest.keepLoaded, true)
})

test("versions the complete QML and JavaScript runtime graph", async () => {
  const manifest = JSON.parse(await read("manifest.json"))
  const runtimeDir = dirname(manifest.entryPoints.overlay)
  const picker = await read(manifest.entryPoints.overlay)

  assert.match(
    picker,
    new RegExp('readonly property string buildIdentity: "' + manifest.version + '"')
  )
  assert.match(picker, /function runtimeIdentity\(\)/)

  for (const file of [
    "ImagePickerModel.js",
    "ThemeManagerController.qml",
    "ThemeManagerModel.js",
    "ThemeCatalogController.qml",
    "ThemeCatalogModel.js",
    "WallpaperBrowserController.qml",
    "WallpaperBrowserModel.js",
    "WallpaperCommandModel.js",
    "WallhavenFilterBar.qml",
    "WallhavenFilterSheet.qml"
  ]) {
    assert.ok((await read(join(runtimeDir, file))).length > 0, file)
  }
})

test("routes theme and wallpaper features by request context", async () => {
  const manifest = JSON.parse(await read("manifest.json"))
  const runtimeDir = dirname(manifest.entryPoints.overlay)
  const picker = await read(join(runtimeDir, "ImagePicker.qml"))
  const themeModel = await read(join(runtimeDir, "ThemeManagerModel.js"))
  const wallpaperModel = await read(join(runtimeDir, "WallpaperBrowserModel.js"))

  assert.match(themeModel, /themeNameForPath/)
  assert.match(wallpaperModel, /isWallpaperPickerRequest/)
  assert.match(picker, /wallpaperPickerRequest = WallpaperBrowserModel\.isWallpaperPickerRequest/)
  assert.match(picker, /themeManager\.themePickerActive/)
  assert.match(picker, /root\.openCatalog\(\)/)
  assert.match(picker, /root\.openWallhaven\(\)/)
  assert.match(picker, /if \(catalogMode\).*themeCatalog\.requestInstall/s)
  assert.match(picker, /if \(wallhavenMode\).*wallhaven\.download/s)
  assert.doesNotMatch(picker, /io\.github\.mtolhuys\.wallpaper-manager/)
})

test("delegates SFW Wallhaven traffic exclusively to bounded Aether processes", async () => {
  const manifest = JSON.parse(await read("manifest.json"))
  const runtimeDir = dirname(manifest.entryPoints.overlay)
  const sources = await Promise.all(
    [
      "ImagePicker.qml",
      "WallpaperBrowserController.qml",
      "WallpaperBrowserModel.js",
      "WallhavenFilterBar.qml",
      "WallhavenFilterSheet.qml"
    ].map((file) => read(join(runtimeDir, file)))
  )
  const [picker, controller, model, filterBar, filterSheet] = sources

  assert.match(model, /"--wallhaven-thumbs"/)
  assert.match(model, /"--wallhaven-download"/)
  assert.match(model, /"--purity",\s*"100"/)
  assert.match(controller, /maxSearchOutputBytes:\s*4 \* 1024 \* 1024/)
  assert.match(controller, /maxDownloadOutputBytes:\s*8 \* 1024/)
  assert.match(controller, /maxErrorOutputBytes:\s*64 \* 1024/)
  assert.equal((controller.match(/onDataChanged:/g) || []).length, 4)
  assert.equal((controller.match(/\.signal\(9\)/g) || []).length, 4)
  assert.match(filterBar, /Filters/)
  assert.match(filterSheet, /selected color need not dominate/)
  assert.match(picker, /filterSheet\.openWith/)
  assert.doesNotMatch(sources.join("\n"), /wallhaven\.cc\/api/)
  assert.doesNotMatch(sources.join("\n"), /\bcurl\b/)
})
