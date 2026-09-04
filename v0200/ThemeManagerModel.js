const stringValue = (value) => String(value || "")
const themeValues = (themes) => (themes && typeof themes === "object" ? themes : {})

const fileStem = (path) =>
  stringValue(path)
    .split("/")
    .pop()
    .replace(/\.[^/.]+$/, "")

const labelForThemeName = (name) =>
  stringValue(name)
    .replace(/[-_]+/g, " ")
    .replace(/\b\w/g, (match) => match.toUpperCase())

// LOCAL: `qs-theme preview-links` fills a directory with <name>.<ext>
// symlinks to each theme's first wallpaper, which is what makes a theme look
// like an image to the grid. The stem is then the theme name, exactly as it
// was under omarchy's theme-selector previews.
const isThemePreviewPath = (path) => /\/qs-theme\/previews\/[^/]+\.[^/.]+$/.test(stringValue(path))

const themeNameForPath = (path) => (isThemePreviewPath(path) ? fileStem(path) : "")

const isSafeThemeName = (name) => {
  const value = stringValue(name)
  return value !== "." && value !== ".." && /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value)
}

const themeMapFromText = (text) =>
  stringValue(text)
    .split("\n")
    .reduce((themes, rawName) => {
      const name = rawName.trim()
      if (isSafeThemeName(name)) themes[name] = true
      return themes
    }, {})

const themeInventoryFromText = (text) =>
  stringValue(text)
    .split("\n")
    .reduce(
      (inventory, row) => {
        const [kind, rawName, rawRepository = ""] = row.split("\t")
        const name = stringValue(rawName).trim()
        if (!isSafeThemeName(name)) return inventory

        if (kind === "user") {
          inventory.installedThemes[name] = true
          const repository = stringValue(rawRepository).trim()
          if (repository) inventory.installedRepositories.push(repository)
        } else if (kind === "stock") {
          inventory.stockThemes[name] = true
        }

        return inventory
      },
      { installedThemes: {}, stockThemes: {}, installedRepositories: [] }
    )

const hasTheme = (themes, name) => isSafeThemeName(name) && themeValues(themes)[name] === true

const withoutTheme = (themes, name) =>
  Object.keys(themeValues(themes)).reduce((remainingThemes, themeName) => {
    if (themeName !== name) remainingThemes[themeName] = true
    return remainingThemes
  }, {})

const withoutNamedImage = (images, name) => {
  const values = Array.isArray(images) ? images : []
  return values.filter((image) => fileStem(image && image.filePath) !== name)
}

if (typeof module !== "undefined") {
  module.exports = {
    fileStem,
    labelForThemeName,
    isThemePreviewPath,
    themeNameForPath,
    isSafeThemeName,
    themeMapFromText,
    themeInventoryFromText,
    hasTheme,
    withoutTheme,
    withoutNamedImage
  }
}
