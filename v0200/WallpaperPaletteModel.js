const maxHistogramEntries = 16

const clamp = (value, minimum = 0, maximum = 1) =>
  Math.max(minimum, Math.min(maximum, Number(value) || 0))

const rgbForHex = (hex) => {
  const match = String(hex || "").match(/^#?([0-9a-fA-F]{6})$/)
  if (!match) return null
  const value = match[1]
  return {
    r: parseInt(value.slice(0, 2), 16) / 255,
    g: parseInt(value.slice(2, 4), 16) / 255,
    b: parseInt(value.slice(4, 6), 16) / 255
  }
}

const metricsForHex = (hex) => {
  const rgb = rgbForHex(hex)
  if (!rgb) return null
  const maximum = Math.max(rgb.r, rgb.g, rgb.b)
  const minimum = Math.min(rgb.r, rgb.g, rgb.b)
  const delta = maximum - minimum
  let hue = 0

  if (delta > 0) {
    if (maximum === rgb.r) hue = ((rgb.g - rgb.b) / delta) % 6
    else if (maximum === rgb.g) hue = (rgb.b - rgb.r) / delta + 2
    else hue = (rgb.r - rgb.g) / delta + 4
    hue = ((hue * 60) + 360) % 360
  }

  return {
    r: rgb.r,
    g: rgb.g,
    b: rgb.b,
    hue,
    saturation: maximum === 0 ? 0 : delta / maximum,
    luminance: 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
  }
}

const parseHistogram = (raw) => {
  const entries = []
  for (const line of String(raw || "").split("\n")) {
    const match = line.match(/^\s*([0-9]+):.*#([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?\b/)
    if (!match) continue
    const count = clamp(parseInt(match[1], 10), 1, 10000000)
    const hex = "#" + match[2].toUpperCase()
    const metrics = metricsForHex(hex)
    if (!metrics) continue
    entries.push({
      count,
      hex,
      r: metrics.r,
      g: metrics.g,
      b: metrics.b,
      hue: metrics.hue,
      saturation: metrics.saturation,
      luminance: metrics.luminance
    })
    if (entries.length >= maxHistogramEntries) break
  }
  return entries
}

const hueDistance = (left, right) => {
  const distance = Math.abs(left - right) % 360
  return Math.min(distance, 360 - distance) / 180
}

const paletteFromHistogram = (raw) => {
  const entries = parseHistogram(raw)
  if (entries.length === 0) return null

  const total = entries.reduce((sum, entry) => sum + entry.count, 0)
  const population = (entry) => Math.pow(entry.count / total, 0.38)
  const base = entries.reduce((best, entry) =>
    entry.count > best.count ? entry : best
  )

  const accent = entries.reduce((best, entry) => {
    const usableLight = 1 - Math.min(1, Math.abs(entry.luminance - 0.58) / 0.58)
    const contrast = Math.min(1, Math.abs(entry.luminance - base.luminance) * 2.4)
    const score = population(entry)
      * (0.18 + entry.saturation * 0.82)
      * (0.42 + usableLight * 0.58)
      * (0.62 + contrast * 0.38)
    return !best || score > best.score ? { entry, score } : best
  }, null)

  const secondary = entries.reduce((best, entry) => {
    if (entry.hex === accent.entry.hex) return best
    const separation = hueDistance(entry.hue, accent.entry.hue)
    const score = population(entry)
      * (0.22 + entry.saturation * 0.78)
      * (0.48 + separation * 0.52)
    return !best || score > best.score ? { entry, score } : best
  }, null)

  return {
    base: base.hex,
    accent: accent.entry.hex,
    secondary: secondary ? secondary.entry.hex : base.hex
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    maxHistogramEntries,
    rgbForHex,
    metricsForHex,
    parseHistogram,
    hueDistance,
    paletteFromHistogram
  }
}
