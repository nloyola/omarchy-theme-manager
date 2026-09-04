const maxFavorites = 512

const stringValue = (value) => String(value || "")

const safePath = (value) => {
  const path = stringValue(value).trim()
  if (!path.startsWith("/") || path.length > 4096 || path.includes("\0")) return ""
  return path
}

const normalizeFavorites = (values) => {
  const seen = new Set()
  const result = []

  for (const value of Array.isArray(values) ? values : []) {
    const path = safePath(value)
    if (!path || seen.has(path)) continue
    seen.add(path)
    result.push(path)
    if (result.length >= maxFavorites) break
  }

  return result
}

const parseState = (raw) => {
  try {
    const parsed = JSON.parse(stringValue(raw) || "{}")
    const values = Array.isArray(parsed) ? parsed : parsed.favorites
    return { version: 1, favorites: normalizeFavorites(values) }
  } catch (_error) {
    return { version: 1, favorites: [] }
  }
}

const serializeState = (favorites) =>
  JSON.stringify({ version: 1, favorites: normalizeFavorites(favorites) }, null, 2) + "\n"

const isFavorite = (favorites, path) => {
  const target = safePath(path)
  return !!target && normalizeFavorites(favorites).includes(target)
}

const toggleFavorite = (favorites, path) => {
  const target = safePath(path)
  const normalized = normalizeFavorites(favorites)
  if (!target) return normalized
  if (normalized.includes(target)) return normalized.filter((value) => value !== target)
  return [target, ...normalized].slice(0, maxFavorites)
}

// Favorites form a stable front section in most-recently-favorited order;
// everything else keeps the exact order supplied by Omarchy's picker.
const prioritizeFavorites = (images, favorites) => {
  const values = Array.isArray(images) ? images : []
  const order = new Map(normalizeFavorites(favorites).map((path, index) => [path, index]))
  const saved = []
  const rest = []

  for (const image of values) {
    const path = safePath(image && image.filePath)
    if (order.has(path)) saved.push({ image, order: order.get(path) })
    else rest.push(image)
  }

  saved.sort((left, right) => left.order - right.order)
  return saved.map((entry) => entry.image).concat(rest)
}

if (typeof module !== "undefined") {
  module.exports = {
    maxFavorites,
    safePath,
    normalizeFavorites,
    parseState,
    serializeState,
    isFavorite,
    toggleFavorite,
    prioritizeFavorites
  }
}
