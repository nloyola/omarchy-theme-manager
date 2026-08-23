const stringValue = (value) => String(value || "")
const imageValues = (images) => (Array.isArray(images) ? images : [])

const nameForPath = (path) =>
  stringValue(path)
    .split("/")
    .pop()
    .replace(/\.[^/.]+$/, "")

const labelForPath = (path) =>
  nameForPath(path)
    .replace(/[-_]+/g, " ")
    .replace(/\b\w/g, (match) => match.toUpperCase())

const loadRows = (rows) => {
  const seenFileNames = {}

  return stringValue(rows)
    .split("\n")
    .reduce((images, row) => {
      if (!row) return images

      const [filePath, thumbnailPath = filePath] = row.split("\t")
      if (!filePath) return images

      const fileName = filePath.split("/").pop()
      if (!fileName || seenFileNames[fileName]) return images

      seenFileNames[fileName] = true
      images.push({ filePath, fileName, thumbnailPath })
      return images
    }, [])
}

const itemMatches = (images, index, filterText) => {
  const values = imageValues(images)
  if (index < 0 || index >= values.length) return false

  const needle = stringValue(filterText).toLowerCase()
  if (!needle) return true

  const image = values[index] || {}
  const filePath = stringValue(image.filePath)
  const haystack = [
    nameForPath(filePath),
    labelForPath(filePath),
    image.displayName,
    image.searchText
  ]
    .map((value) => stringValue(value).toLowerCase())
    .join(" ")

  return haystack.includes(needle)
}

const firstMatchingIndex = (images, filterText) =>
  imageValues(images).findIndex((_, index) => itemMatches(images, index, filterText))

const filteredPosition = (images, index, filterText) => {
  if (!filterText) return index

  return imageValues(images)
    .slice(0, Math.max(0, index))
    .filter((_, candidateIndex) => itemMatches(images, candidateIndex, filterText)).length
}

const selectedFilteredPosition = (images, selectedIndex, filterText) => {
  if (!filterText) return selectedIndex
  return itemMatches(images, selectedIndex, filterText)
    ? filteredPosition(images, selectedIndex, filterText)
    : 0
}

const indexForSelectedImage = (images, selectedImage) => {
  const selectedIndex = imageValues(images).findIndex((image) => image.filePath === selectedImage)
  return selectedIndex >= 0 ? selectedIndex : 0
}

const nextSelectedIndexForFilter = (images, selectedIndex, filterText) =>
  itemMatches(images, selectedIndex, filterText)
    ? selectedIndex
    : firstMatchingIndex(images, filterText)

if (typeof module !== "undefined") {
  module.exports = {
    nameForPath,
    labelForPath,
    loadRows,
    itemMatches,
    firstMatchingIndex,
    filteredPosition,
    selectedFilteredPosition,
    indexForSelectedImage,
    nextSelectedIndexForFilter
  }
}
