import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui
import "ImagePickerModel.js" as ImagePickerModel
import "ThemeManagerModel.js" as ThemeManagerModel
import "WallpaperBrowserModel.js" as WallpaperBrowserModel
import "WallpaperCommandModel.js" as WallpaperCommandModel

Item {
  id: root

  readonly property string buildIdentity: "0.4.0"
  // Injected by omarchy-shell; defaults to the session OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var manifest: null
  // LOCAL: this fork runs as its own quickshell config, launched by
  // scripts/theme-manager.sh, rather than inside the omarchy plugin host. The
  // host used to hand it a source directory and an OMARCHY_PATH; here the
  // scripts sit beside this file, so the root is either named outright by the
  // launcher or worked out from where this QML was loaded from.
  property string pluginRoot: Quickshell.env("QS_TM_ROOT")
    || String(Qt.resolvedUrl("..")).replace(/^file:\/\//, "").replace(/\/$/, "")
  // LOCAL: every theme operation goes through qs-theme, which is this
  // desktop's resolver and the only thing that knows what a theme is here.
  readonly property string themeBin: Quickshell.env("QS_THEME_BIN")
    || (Quickshell.env("HOME") + "/.local/bin/qs-theme")
  // LOCAL: where qs-theme install puts a package's backgrounds.
  readonly property string wallpaperLib: Quickshell.env("QS_THEME_WALLPAPER_LIB")
    || (Quickshell.env("HOME") + "/Dropbox/wallpapers")
  // LOCAL: XDG_STATE_HOME honoured, because qs-theme writes there under it.
  property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  // LOCAL: last resort is the wallpaper library rather than the current
  // theme's backgrounds directory - a theme here owns a list of globs, not a
  // folder, so there is no such directory to fall back on.
  property string imageDirs: Quickshell.env("OMARCHY_IMAGE_SELECTOR_DIRS") || Quickshell.env("OMARCHY_IMAGE_SELECTOR_DIR") || Quickshell.env("OMARCHY_STOCK_BACKGROUNDS_DIR") || wallpaperLib
  property string imageRows: ""
  property string loadedImageRows: ""
  property string selectionFile: Quickshell.env("OMARCHY_IMAGE_SELECTOR_SELECTION_FILE") || Quickshell.env("OMARCHY_BACKGROUND_SELECTION_FILE")
  property string selectedImage: Quickshell.env("OMARCHY_IMAGE_SELECTOR_SELECTED")
  property int selectedIndex: 0
  property bool imagesLoaded: false
  property bool opened: false
  property bool showLabels: false
  property bool filterable: false
  property bool layoutSettled: false
  property bool requestActive: false
  property int requestSerial: 0
  property int applySerial: 0
  property string doneFile: ""
  property string filterText: ""
  property var doneFilesToRelease: []
  property bool catalogMode: false
  property var catalogPreviousImages: []
  property int catalogPreviousIndex: 0
  property string catalogPreviousFilter: ""
  property bool catalogPreviousFilterable: false
  property bool catalogPreviousShowLabels: false
  property bool wallhavenMode: false
  property var localImages: []
  property int localSelectedIndex: 0
  property string localFilterText: ""
  property bool wallpaperPickerRequest: false
  // LOCAL: favourites and the command-centre record are state this program
  // writes, not configuration anyone edits, so they live under the state home
  // - and beside qs-theme's own generated files rather than in ~/.config,
  // where Home Manager owns everything and a write would dirty the repo.
  readonly property string wallpaperCommandStatePath: stateHome + "/qs-theme-manager/wallpaper-command-center.json"
  // LOCAL: an installed theme's backgrounds are copied into the wallpaper
  // library under the theme's own name, which is the closest thing here to
  // omarchy's current/theme/backgrounds.
  readonly property string currentThemeRoot: wallpaperLib + "/" + (currentThemeName || "")
  // LOCAL: qs-theme records the live theme here, and writes it by rename.
  readonly property string currentThemeNamePath: stateHome + "/theme/theme.name"
  property string currentThemeName: ""
  property var favoriteIds: []
  property bool favoritesOnly: false
  readonly property bool wallpaperPickerActive: wallpaperPickerRequest
  readonly property bool localWallpaperMode: wallpaperPickerActive && !wallhavenMode && !catalogMode
  readonly property bool currentFavorite: localWallpaperMode
    && WallpaperCommandModel.isFavorite(favoriteIds, currentPath(), wallpaperFavoriteContext())
  readonly property string wallhavenFilterSummary: WallpaperBrowserModel.filterSummary({
    categories: wallhaven.categories,
    sorting: wallhaven.sorting,
    order: wallhaven.order,
    atLeast: wallhaven.atLeast,
    colors: wallhaven.colors
  })
  readonly property bool wallhavenFiltersActive: WallpaperBrowserModel.filterKey({
    categories: wallhaven.categories,
    sorting: wallhaven.sorting,
    order: wallhaven.order,
    atLeast: wallhaven.atLeast,
    colors: wallhaven.colors
  }) !== WallpaperBrowserModel.filterKey({})
  // Bound to the central [image-picker] section in shell.toml via Color.qml.
  // dimColor tints unselected slices and text outlines on top of the scrim.
  property color dimColor: Color.background
  property color foreground: Color.imagePicker.text
  property color scrim: Color.imagePicker.scrim
  property color selectedBorder: Color.imagePicker.selectedBorder
  property color unselectedBorder: Color.imagePicker.unselectedBorder
  readonly property bool livePaletteReady: wallpaperPickerActive && wallpaperPalette.ready
  readonly property color livePaletteBase: livePaletteReady
    ? mixColor(Color.background, wallpaperPalette.base, 0.58)
    : Color.background
  readonly property color livePaletteAccent: livePaletteReady
    ? mixColor(Color.accent, wallpaperPalette.accent, 0.78)
    : Color.accent
  readonly property color livePaletteSecondary: livePaletteReady
    ? mixColor(Color.accent, wallpaperPalette.secondary, 0.7)
    : Color.accent
  readonly property color activeSelectedBorder: livePaletteReady
    ? livePaletteAccent
    : selectedBorder
  readonly property color activeScrim: livePaletteReady
    ? Util.alpha(livePaletteBase, 0.82)
    : scrim
  property int expandedWidth: 768
  property int expandedHeight: 475
  property int sliceWidth: 108
  property int sliceHeight: 432
  property int sliceSpacing: -30
  property int skewOffset: 28
  property int bottomChromeHeight: wallhavenMode || catalogMode
    ? 150
    : (wallpaperPickerActive
        ? 78
        : (showLabels ? (filterable ? 104 : 74) : (filterable ? 60 : 30)))

  Component.onCompleted: console.info("Theme Manager runtime " + buildIdentity)

  function runtimeIdentity() {
    return buildIdentity
  }

  function mixColor(from, to, amount) {
    const t = Math.max(0, Math.min(1, Number(amount) || 0))
    return Qt.rgba(
      from.r + (to.r - from.r) * t,
      from.g + (to.g - from.g) * t,
      from.b + (to.b - from.b) * t,
      from.a + (to.a - from.a) * t)
  }

  function runtimeState() {
    return JSON.stringify({
      version: buildIdentity,
      opened: opened,
      layoutSettled: layoutSettled,
      mode: catalogMode
        ? "catalog"
        : (wallhavenMode
            ? "wallhaven"
            : (themeManager.themePickerActive
                ? "themes"
                : (wallpaperPickerActive ? "wallpapers" : "images"))),
      images: imageArray.length,
      query: wallhavenMode ? filterText : "",
      filtersOpen: filterSheet.opened,
      favoriteCount: favoriteIds.length,
      currentFavorite: currentFavorite,
      favoritesOnly: favoritesOnly,
      paletteReady: wallpaperPalette.ready,
      paletteSampledPath: wallpaperPalette.sampledPath
    })
  }

  onOpenedChanged: {
    if (!opened) {
      if (catalogMode) leaveCatalog(false)
      if (wallhavenMode) leaveWallhaven(false)
      layoutSettled = false
    }
  }

  // LOCAL: is this request browsing the wallpaper library rather than themes?
  // imageDirs is newline separated, and a theme request names the preview
  // directory instead, so an exact match on either the library or one of its
  // subject folders is the whole test.
  function isLocalWallpaperRequest(dirs) {
    const lib = String(root.wallpaperLib || "").replace(/\/+$/, "")
    if (lib === "") return false
    return String(dirs || "")
      .split("\n")
      .map((dir) => dir.trim().replace(/\/+$/, ""))
      .some((dir) => dir !== "" && (dir === lib || dir.startsWith(lib + "/")))
  }

  function scriptPath(name) {
    // LOCAL: list.sh ships in this fork rather than in an omarchy plugin dir.
    return pluginRoot + "/" + name
  }

  function pluginScriptPath(name) {
    const sourceDir = manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
    // LOCAL: no plugin host sets __sourceDir here, so fall back to the root
    // this config was loaded from.
    return sourceDir ? sourceDir.replace(/\/$/, "") + "/" + name : (pluginRoot + "/" + name)
  }

  function focusPicker() {
    if (root.opened && root.imagesLoaded && root.layoutSettled)
      keyHandler.forceActiveFocus()
  }

  function currentWallhavenFilters() {
    return {
      categories: wallhaven.categories,
      sorting: wallhaven.sorting,
      order: wallhaven.order,
      atLeast: wallhaven.atLeast,
      colors: wallhaven.colors
    }
  }

  function revealWhenSettled(serial) {
    Qt.callLater(function() {
      if (serial === root.requestSerial && root.opened && root.imagesLoaded && root.imageArray.length > 0) {
        root.layoutSettled = true
        root.focusPicker()
      }
    })
  }

  function currentPath() {
    if (imageArray.length === 0 || !itemMatches(selectedIndex)) return ""
    return imageArray[selectedIndex].filePath
  }

  function wallpaperFavoriteContext() {
    return {
      themeRoot: currentThemeRoot,
      themeName: currentThemeName
    }
  }

  function loadWallpaperCommandState(raw) {
    const state = WallpaperCommandModel.parseState(raw, wallpaperFavoriteContext())
    favoriteIds = state.favorites
    if (localWallpaperMode && imageArray.length > 0) reorderWallpapers()
  }

  function saveWallpaperCommandState() {
    wallpaperCommandState.setText(WallpaperCommandModel.serializeState(favoriteIds))
  }

  function reorderWallpapers() {
    if (!localWallpaperMode || imageArray.length === 0) return
    const selectedPath = currentPath()
    imageArray = WallpaperCommandModel.prioritizeFavorites(
      imageArray,
      favoriteIds,
      wallpaperFavoriteContext())
    selectedIndex = ImagePickerModel.indexForSelectedImage(imageArray, selectedPath)
  }

  function toggleCurrentFavorite() {
    if (!localWallpaperMode) return
    const path = currentPath()
    if (!path) return
    favoriteIds = WallpaperCommandModel.toggleFavorite(
      favoriteIds,
      path,
      wallpaperFavoriteContext())
    if (favoritesOnly && favoriteIds.length === 0) favoritesOnly = false
    reorderWallpapers()
    saveWallpaperCommandState()
    Qt.callLater(focusPicker)
  }

  function toggleFavoritesOnly() {
    if (!localWallpaperMode || favoriteIds.length === 0) return
    favoritesOnly = !favoritesOnly
    if (!itemMatches(selectedIndex)) selectedIndex = firstMatchingIndex()
    Qt.callLater(focusPicker)
  }

  function currentItem() {
    if (imageArray.length === 0 || !itemMatches(selectedIndex)) return null
    return imageArray[selectedIndex]
  }

  function currentPaletteSource() {
    if (!opened || !wallpaperPickerActive) return ""
    const item = currentItem()
    if (!item) return ""
    return String(item.thumbnailPath || item.filePath || "")
  }

  function nameForPath(path) {
    return ImagePickerModel.nameForPath(path)
  }

  function labelForPath(path) {
    return ImagePickerModel.labelForPath(path)
  }

  function currentLabel() {
    const item = currentItem()
    if (!item) return filterText ? "No matches" : ""

    if (wallhavenMode) {
      const parts = [String(item.displayName || "Wallhaven")]
      if (item.resolution) parts.push(String(item.resolution))
      if (item.category) parts.push(String(item.category))
      return parts.join("  ·  ")
    }

    if (item.displayName) return String(item.displayName)
    return labelForPath(item.filePath)
  }

  function currentCatalogMeta() {
    const item = catalogMode ? currentItem() : null
    if (!item) return ""

    const parts = []
    if (item.official) parts.push("Official Omarchy listing")
    else parts.push("Community catalog")
    if (item.owner) parts.push("@" + item.owner)
    if (item.stars > 0) parts.push(item.stars + " ★")
    if (item.warnings && item.warnings.length > 0) parts.push(item.warnings.length + " notes")
    return parts.join("  ·  ")
  }

  function openCatalog() {
    if (wallhavenMode
        || !themeManager.themePickerActive
        || !themeManager.inventoryReady
        || catalogMode) return
    themeCatalog.load()
  }

  function enterCatalog(rows) {
    if (wallhavenMode || !Array.isArray(rows) || rows.length === 0) return

    if (!catalogMode) {
      catalogPreviousImages = imageArray
      catalogPreviousIndex = selectedIndex
      catalogPreviousFilter = filterText
      catalogPreviousFilterable = filterable
      catalogPreviousShowLabels = showLabels
    }

    catalogMode = true
    imageArray = rows
    selectedIndex = 0
    filterText = ""
    filterable = true
    showLabels = true
    Qt.callLater(focusPicker)
  }

  function leaveCatalog(restoreFocus) {
    if (!catalogMode) return

    catalogMode = false
    imageArray = catalogPreviousImages
    selectedIndex = Math.min(catalogPreviousIndex, Math.max(0, imageArray.length - 1))
    filterText = catalogPreviousFilter
    filterable = catalogPreviousFilterable
    showLabels = catalogPreviousShowLabels
    catalogPreviousImages = []
    catalogPreviousIndex = 0
    catalogPreviousFilter = ""
    catalogPreviousFilterable = false
    catalogPreviousShowLabels = false

    if (restoreFocus !== false) Qt.callLater(focusPicker)
  }

  function removeThemeFromRows(name) {
    if (catalogMode || wallhavenMode) return

    const previousIndex = selectedIndex
    const nextImages = ThemeManagerModel.withoutNamedImage(imageArray, name)
    imageArray = nextImages
    loadedImageRows = ""

    if (nextImages.length === 0) {
      cancel()
      return
    }

    selectedIndex = Math.min(previousIndex, nextImages.length - 1)
    Qt.callLater(focusPicker)
  }

  function itemMatches(index) {
    if (wallhavenMode)
      return index >= 0 && index < imageArray.length
    if (localWallpaperMode && favoritesOnly) {
      if (index < 0 || index >= imageArray.length) return false
      const item = imageArray[index]
      if (!item || !WallpaperCommandModel.isFavorite(
          favoriteIds,
          item.filePath,
          wallpaperFavoriteContext())) return false
    }
    return ImagePickerModel.itemMatches(imageArray, index, filterText)
  }

  function firstMatchingIndex() {
    if (wallhavenMode) return imageArray.length > 0 ? 0 : -1
    for (let index = 0; index < imageArray.length; index++)
      if (itemMatches(index)) return index
    return -1
  }

  function filteredPosition(index) {
    if (wallhavenMode) return index
    let position = 0
    for (let candidate = 0; candidate < index; candidate++)
      if (itemMatches(candidate)) position += 1
    return position
  }

  function selectedFilteredPosition() {
    if (wallhavenMode) return selectedIndex
    return itemMatches(selectedIndex) ? filteredPosition(selectedIndex) : 0
  }

  function select(index, immediate) {
    if (imageArray.length === 0) return
    if (index < 0) index = 0
    else if (index >= imageArray.length) index = imageArray.length - 1
    if (!itemMatches(index)) return
    if (index === selectedIndex && immediate !== true) return

    selectedIndex = index
    if (wallhavenMode) Qt.callLater(maybeLoadMoreWallhaven)
  }

  function selectAdjacent(direction) {
    const count = imageArray.length
    if (count === 0) return

    let index = selectedIndex
    for (let i = 0; i < count; i++) {
      index = (index + direction + count) % count
      if (itemMatches(index)) {
        select(index)
        return
      }
    }
  }

  function updateFilter(nextFilterText) {
    if (wallhavenMode) {
      filterText = WallpaperBrowserModel.normalizeQuery(nextFilterText)
      wallhavenSearchTimer.restart()
      return
    }

    filterText = nextFilterText
    if (!itemMatches(selectedIndex)) {
      const first = firstMatchingIndex()
      if (first >= 0) selectedIndex = first
    }
  }

  function searchWallhaven() {
    if (!wallhavenMode) return

    imageArray = []
    selectedIndex = 0
    wallhaven.search(filterText, false)
  }

  function maybeLoadMoreWallhaven() {
    if (!wallhavenMode
        || wallhaven.loading
        || !wallhaven.hasMore
        || imageArray.length === 0
        || selectedIndex < Math.max(0, imageArray.length - 10)) return

    wallhaven.loadMore()
  }

  function openWallhavenFilters() {
    if (!wallhavenMode || wallhaven.downloading) return
    wallhavenSearchTimer.stop()
    filterSheet.openWith(currentWallhavenFilters())
  }

  function applyWallhavenFilters(filters) {
    const normalized = WallpaperBrowserModel.normalizeFilters(filters)
    const changed = WallpaperBrowserModel.filterKey(normalized)
      !== WallpaperBrowserModel.filterKey(currentWallhavenFilters())
    wallhaven.categories = normalized.categories
    wallhaven.sorting = normalized.sorting
    wallhaven.order = normalized.order
    wallhaven.atLeast = normalized.atLeast
    wallhaven.colors = normalized.colors

    if (changed) searchWallhaven()
    else Qt.callLater(focusPicker)
  }

  function openWallhaven() {
    if (catalogMode || !wallpaperPickerActive || wallhavenMode) return

    localImages = imageArray
    localSelectedIndex = selectedIndex
    localFilterText = filterText
    wallhavenMode = true
    filterSheet.opened = false
    imageArray = []
    selectedIndex = 0
    filterText = ""
    imagesLoaded = true
    layoutSettled = true
    wallhaven.search("", false)
    Qt.callLater(focusPicker)
  }

  function leaveWallhaven(restoreFocus) {
    if (!wallhavenMode) return

    wallhavenSearchTimer.stop()
    filterSheet.opened = false
    wallhaven.reset()
    wallhavenMode = false
    imageArray = localImages
    selectedIndex = Math.min(localSelectedIndex, Math.max(0, imageArray.length - 1))
    filterText = localFilterText
    localImages = []
    localSelectedIndex = 0
    localFilterText = ""

    if (restoreFocus !== false) Qt.callLater(focusPicker)
  }

  function acceptWallhavenResults(rows, append) {
    if (!wallhavenMode || !Array.isArray(rows)) return

    const previousIndex = selectedIndex
    imageArray = append
      ? WallpaperBrowserModel.appendUniqueRows(imageArray, rows)
      : rows
    selectedIndex = append
      ? Math.min(previousIndex, Math.max(0, imageArray.length - 1))
      : 0
    imagesLoaded = true
    layoutSettled = true
    Qt.callLater(focusPicker)
  }

  function releaseNextDoneFile() {
    if (releaseProc.running || doneFilesToRelease.length === 0) return

    const path = doneFilesToRelease.shift()
    releaseProc.command = ["bash", "-c", ": > " + Util.shellQuote(path)]
    releaseProc.running = true
  }

  function finishDoneFile(path) {
    if (!path) return
    doneFilesToRelease.push(path)
    releaseNextDoneFile()
  }

  function finishSelection(path) {
    if (!path || !selectionFile) {
      cancel()
      return
    }

    const activeSelectionFile = selectionFile
    const activeDoneFile = doneFile
    applySerial = requestSerial
    requestActive = false
    selectionFile = ""
    doneFile = ""

    applyProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(path) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    applyProc.running = true
  }

  function applySelected() {
    if (catalogMode) {
      themeCatalog.requestInstall()
      return
    }

    if (wallhavenMode) {
      const item = currentItem()
      if (!item || wallhaven.downloading) return
      wallhaven.download(String(item.id || ""))
      return
    }

    finishSelection(currentPath())
  }

  function cancel() {
    if (catalogMode) leaveCatalog(false)
    if (wallhavenMode) leaveWallhaven(false)

    if (requestActive)
      finishDoneFile(doneFile)

    requestActive = false
    selectionFile = ""
    doneFile = ""
    root.opened = false
  }

  function closeSelector(nextDoneFile) {
    if (catalogMode) leaveCatalog(false)
    if (wallhavenMode) leaveWallhaven(false)
    requestSerial += 1

    if (requestActive)
      finishDoneFile(doneFile)

    if (nextDoneFile && nextDoneFile !== doneFile)
      finishDoneFile(nextDoneFile)

    requestActive = false
    selectionFile = ""
    doneFile = ""
    filterText = ""
    root.opened = false
  }

  function loadRows(rows, reveal) {
    let newImages = ImagePickerModel.loadRows(rows)
    if (wallpaperPickerActive)
      newImages = WallpaperCommandModel.prioritizeFavorites(
        newImages,
        favoriteIds,
        wallpaperFavoriteContext())

    root.loadedImageRows = rows
    root.selectedIndex = root.indexForSelectedImage(newImages)
    root.imageArray = newImages
    root.imagesLoaded = true

    if (reveal !== false) {
      root.opened = true
      root.revealWhenSettled(root.requestSerial)
    }
  }

  function openSelector(nextImageDirs, nextImageRows, nextSelectedImage, nextSelectionFile, nextDoneFile, nextShowLabels, nextFilterable) {
    if (catalogMode) leaveCatalog(false)
    if (wallhavenMode) leaveWallhaven(false)
    if (requestActive && doneFile && doneFile !== nextDoneFile)
      finishDoneFile(doneFile)

    requestSerial += 1

    imageDirs = nextImageDirs
    imageRows = nextImageRows
    // LOCAL: upstream decides this from omarchy's own layout - a request on
    // current/theme/backgrounds or ~/.config/omarchy/backgrounds is a
    // wallpaper request, anything else is themes. Neither path exists here, so
    // the answer was always false and the whole wallpaper half of the overlay
    // - Wallhaven, favourites, the command centre - was unreachable. The
    // library is whatever QS_THEME_WALLPAPER_LIB names, so recognise that too.
    //
    // Keeping upstream's test first rather than replacing it: it costs
    // nothing, and it is the line a merge from upstream will want to touch.
    wallpaperPickerRequest = WallpaperBrowserModel.isWallpaperPickerRequest(
      imageDirs,
      imageRows
    ) || root.isLocalWallpaperRequest(imageDirs)
    selectedImage = nextSelectedImage
    selectionFile = nextSelectionFile
    doneFile = nextDoneFile
    requestActive = !!doneFile
    showLabels = nextShowLabels === true || nextShowLabels === "true"
    filterable = nextFilterable === true || nextFilterable === "true"
    filterText = ""
    favoritesOnly = false
    layoutSettled = false

    if (imageRows && imageRows === loadedImageRows && imageArray.length > 0) {
      root.select(root.selectedImageIndex(), true)
      imagesLoaded = true
      opened = true
      root.revealWhenSettled(requestSerial)
      return
    }

    if (imageRows) {
      const rowsToLoad = imageRows
      const rowsSerial = requestSerial
      imageArray = []
      selectedIndex = 0
      imagesLoaded = true
      opened = true
      Qt.callLater(function() {
        if (rowsSerial === root.requestSerial)
          root.loadRows(rowsToLoad, true)
      })
      return
    }

    imageArray = []
    selectedIndex = 0
    imagesLoaded = false
    opened = false
    startImageScan(requestSerial, imageDirs)
  }

  property var imageArray: []

  function startImageScan(serial, dirs) {
    if (loadImagesProc.running) {
      loadImagesProc.queuedSerial = serial
      loadImagesProc.queuedDirs = dirs
      return
    }

    loadImagesProc.activeSerial = serial
    loadImagesProc.queuedSerial = 0
    loadImagesProc.queuedDirs = ""
    loadImagesProc.command = [root.scriptPath("list.sh"), dirs]
    loadImagesProc.running = true
  }

  function indexForSelectedImage(images) {
    return ImagePickerModel.indexForSelectedImage(images, selectedImage)
  }

  function selectedImageIndex() {
    return indexForSelectedImage(imageArray)
  }

  Process {
    id: loadImagesProc

    property int activeSerial: 0
    property int queuedSerial: 0
    property string queuedDirs: ""

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (loadImagesProc.activeSerial === root.requestSerial)
          root.loadRows(String(text || ""), true)
      }
    }

    onExited: {
      const serial = queuedSerial
      const dirs = queuedDirs
      activeSerial = 0
      queuedSerial = 0
      queuedDirs = ""
      if (serial > 0 && serial === root.requestSerial)
        root.startImageScan(serial, dirs)
    }
  }

  FileView {
    id: wallpaperCommandState
    path: root.wallpaperCommandStatePath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadWallpaperCommandState(text())
    onLoadFailed: root.loadWallpaperCommandState("")
  }

  FileView {
    id: currentThemeNameFile
    path: root.currentThemeNamePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.currentThemeName = String(text() || "").trim().slice(0, 255)
      if (root.localWallpaperMode && root.imageArray.length > 0)
        root.reorderWallpapers()
    }
    onLoadFailed: root.currentThemeName = ""
    onFileChanged: reload()
  }

  WallpaperPalette {
    id: wallpaperPalette
    sourcePath: root.currentPaletteSource()
    fallbackBase: Color.background
    fallbackAccent: Color.accent
  }

  // Lifecycle hooks invoked by omarchy-shell summon/hide. The shell host owns
  // the stable image-selector IPC target and forwards positional calls here.
  function open(payload) {
    let args = {}
    if (payload) {
      try { args = JSON.parse(payload) || {} } catch (_error) { args = {} }
    }
    const dirs = String(args.imageDirs || imageDirs)
    const rows = String(args.imageRows || "")
    const sel = String(args.selectedImage || selectedImage)
    const selFile = String(args.selectionFile || "")
    const doneF = String(args.doneFile || "")
    const labels = args.showLabels === true || args.showLabels === "true"
    const filter = args.filterable === true || args.filterable === "true"
    openSelector(dirs, rows, sel, selFile, doneF, labels, filter)
  }

  function close() {
    cancel()
  }

  function preloadRows(nextImageRows, nextSelectedImage, nextShowLabels, nextFilterable) {
    // Ignore warmups while a visible request is active. Otherwise a preload
    // resets layoutSettled and can leave only the fullscreen scrim visible.
    if (opened || requestActive) return

    requestSerial += 1
    imageRows = nextImageRows
    selectedImage = nextSelectedImage
    showLabels = nextShowLabels === true || nextShowLabels === "true"
    filterable = nextFilterable === true || nextFilterable === "true"
    filterText = ""
    layoutSettled = false

    if (imageRows && imageRows === loadedImageRows && imageArray.length > 0) {
      selectedIndex = selectedImageIndex()
      imagesLoaded = true
    } else if (imageRows) {
      loadRows(imageRows, false)
    }
  }

  Timer {
    id: wallhavenSearchTimer
    interval: 450
    repeat: false
    onTriggered: {
      if (root.wallhavenMode)
        root.searchWallhaven()
    }
  }

  Process {
    id: applyProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  Process {
    id: releaseProc
    onExited: root.releaseNextDoneFile()
  }

  WallpaperBrowserController {
    id: wallhaven
    onResultsReady: function(rows, append) { root.acceptWallhavenResults(rows, append) }
    onWallpaperReady: function(path) {
      if (root.wallhavenMode) root.finishSelection(path)
    }
    onFocusRequested: Qt.callLater(root.focusPicker)
  }

  ThemeManagerController {
    id: themeManager
    selectedPath: root.currentPath()
    pickerOpen: root.opened
    inventoryScriptPath: root.pluginScriptPath("theme-inventory.sh")
    themeBin: root.themeBin   // LOCAL
    onThemeRemoved: function(name) { root.removeThemeFromRows(name) }
    onFocusRequested: Qt.callLater(root.focusPicker)
  }

  ThemeCatalogController {
    id: themeCatalog
    catalogScriptPath: root.pluginScriptPath("catalog.sh")
    themeBin: root.themeBin   // LOCAL
    pickerOpen: root.opened
    installedThemes: themeManager.installedThemes
    stockThemes: themeManager.stockThemes
    installedRepositories: themeManager.installedRepositories
    selectedEntry: root.catalogMode ? root.currentItem() : null
    onCatalogLoaded: function(rows) { root.enterCatalog(rows) }
    onThemeInstalled: root.cancel()
    onFocusRequested: Qt.callLater(root.focusPicker)
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-image-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened && root.imagesLoaded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      visible: root.opened && root.imagesLoaded
      color: root.activeScrim
      Behavior on color { ColorAnimation { duration: 360; easing.type: Easing.OutCubic } }
    }

    Rectangle {
      anchors.fill: parent
      visible: root.opened && root.imagesLoaded && root.livePaletteReady
      opacity: 0.42
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0; color: Util.alpha(root.livePaletteSecondary, 0.28) }
        GradientStop { position: 0.48; color: "transparent" }
        GradientStop { position: 1; color: Util.alpha(root.livePaletteAccent, 0.24) }
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened && root.imagesLoaded
      onClicked: root.cancel()
    }

    Item {
      id: keyHandler
      anchors.fill: parent
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (filterSheet.opened) {
          if (filterSheet.handleKey(event)) event.accepted = true
          return
        }

        if (themeCatalog.confirmationOpen) {
          if (installConfirm.handleKey(event)) event.accepted = true
        } else if (themeManager.confirmationOpen) {
          if (uninstallConfirm.handleKey(event)) event.accepted = true
        } else if (event.key === Qt.Key_Delete
                   && !root.catalogMode
                   && !root.wallhavenMode
                   && themeManager.themePickerActive) {
          themeManager.requestUninstall()
          event.accepted = true
        } else if (event.key === Qt.Key_B
            && (event.modifiers & Qt.ControlModifier) !== 0
            && root.wallpaperPickerActive
            && !root.wallhavenMode) {
          root.openWallhaven()
          event.accepted = true
        } else if (event.key === Qt.Key_B
                   && (event.modifiers & Qt.ControlModifier) !== 0
                   && !root.catalogMode
                   && !root.wallhavenMode
                   && themeManager.themePickerActive) {
          root.openCatalog()
          event.accepted = true
        } else if (event.key === Qt.Key_N
                   && (event.modifiers & Qt.ControlModifier) !== 0
                   && root.wallhavenMode) {
          wallhaven.loadMore()
          event.accepted = true
        } else if (event.key === Qt.Key_F
                   && (event.modifiers & Qt.ControlModifier) !== 0
                   && root.wallhavenMode) {
          root.openWallhavenFilters()
          event.accepted = true
        } else if (event.key === Qt.Key_D
                   && (event.modifiers & Qt.ControlModifier) !== 0
                   && (event.modifiers & Qt.ShiftModifier) !== 0
                   && root.localWallpaperMode) {
          root.toggleFavoritesOnly()
          event.accepted = true
        } else if (event.key === Qt.Key_D
                   && (event.modifiers & Qt.ControlModifier) !== 0
                   && root.localWallpaperMode) {
          root.toggleCurrentFavorite()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          if (root.filterText) {
            root.updateFilter("")
          } else if (root.wallhavenMode) {
            root.leaveWallhaven(true)
          } else if (root.catalogMode) {
            root.leaveCatalog(true)
          } else {
            root.cancel()
          }
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.applySelected()
          event.accepted = true
        } else if ((root.wallhavenMode || root.filterable) && Util.editsFilter(event, root.filterText)) {
          root.updateFilter(Util.editedFilter(event, root.filterText))
          event.accepted = true
        } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab) {
          root.selectAdjacent(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
          root.selectAdjacent(1)
          event.accepted = true
        } else if ((root.wallhavenMode || root.filterable)
                   && event.text
                   && event.text.length === 1
                   && event.text.charCodeAt(0) >= 32
                   && event.text.charCodeAt(0) !== 127
                   && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
          root.updateFilter(root.filterText + event.text)
          event.accepted = true
        }
      }
    }

    Item {
      id: card
      visible: root.opened && root.imagesLoaded && root.layoutSettled && root.imageArray.length > 0
      width: Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
      height: root.expandedHeight + Style.space(30) + root.bottomChromeHeight
      anchors.centerIn: parent

      MouseArea { anchors.fill: parent; onClicked: {} }

      Rectangle {
        visible: root.livePaletteReady
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.expandedWidth * 0.2
        width: root.expandedWidth * 0.82
        height: root.expandedHeight * 0.82
        radius: width / 2
        color: Util.alpha(root.livePaletteAccent, 0.28)
        opacity: 0.74
        layer.enabled: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1
          blurMax: 96
          autoPaddingEnabled: true
        }
      }

      Rectangle {
        visible: root.livePaletteReady
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.expandedWidth * 0.24
        anchors.verticalCenterOffset: root.expandedHeight * 0.12
        width: root.expandedWidth * 0.7
        height: root.expandedHeight * 0.7
        radius: width / 2
        color: Util.alpha(root.livePaletteSecondary, 0.24)
        opacity: 0.68
        layer.enabled: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1
          blurMax: 96
          autoPaddingEnabled: true
        }
      }

      Item {
        id: carousel
        anchors.top: parent.top
        anchors.topMargin: Style.space(30)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomChromeHeight
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
        clip: false

        readonly property real itemStep: root.sliceWidth + root.sliceSpacing
        readonly property real previewX: (width - root.expandedWidth) / 2

        Repeater {
          model: root.imageArray.length

          delegate: Item {
            id: item
            required property int index

            readonly property var imageData: root.imageArray[index]
            readonly property string filePath: imageData ? imageData.filePath : ""
            readonly property string fileName: imageData ? imageData.fileName : ""
            readonly property string thumbnailPath: imageData ? imageData.thumbnailPath : ""

            readonly property bool matched: root.itemMatches(index)
            readonly property int relativeIndex: root.filteredPosition(index) - root.selectedFilteredPosition()
            readonly property bool selected: matched && index === root.selectedIndex
            readonly property bool nearby: matched
              && Math.abs(relativeIndex) <= (root.wallhavenMode || root.catalogMode ? 7 : 16)
            property bool sourceActivated: nearby
            onNearbyChanged: if (nearby) sourceActivated = true

            visible: nearby
            x: selected ? carousel.previewX : (relativeIndex < 0 ? carousel.previewX + relativeIndex * carousel.itemStep : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)
            width: selected ? root.expandedWidth : root.sliceWidth
            height: selected ? root.expandedHeight : root.sliceHeight
            y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
            z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)

            Behavior on x {
              enabled: root.opened && root.layoutSettled
              NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on y {
              enabled: root.opened && root.layoutSettled
              NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on width {
              enabled: root.opened && root.layoutSettled
              NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on height {
              enabled: root.opened && root.layoutSettled
              NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }

            readonly property real skAbs: Math.abs(root.skewOffset)
            readonly property real topLeft: root.skewOffset >= 0 ? skAbs : 0
            readonly property real topRight: root.skewOffset >= 0 ? width : width - skAbs
            readonly property real bottomRight: root.skewOffset >= 0 ? width - skAbs : width
            readonly property real bottomLeft: root.skewOffset >= 0 ? 0 : skAbs

            Item {
              id: maskShape
              anchors.fill: parent
              visible: false
              layer.enabled: true

              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "white"
                  strokeColor: "transparent"
                  startX: item.topLeft; startY: 0
                  PathLine { x: item.topRight; y: 0 }
                  PathLine { x: item.bottomRight; y: item.height }
                  PathLine { x: item.bottomLeft; y: item.height }
                  PathLine { x: item.topLeft; y: 0 }
                }
              }
            }

            Item {
              anchors.fill: parent
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.3
                maskSpreadAtMin: 0.3
              }

              Rectangle {
                anchors.fill: parent
                color: Util.alpha(root.dimColor, 0.88)
              }

              Image {
                id: image
                anchors.fill: parent
                // Aether owns local Wallhaven thumbnails. Theme catalog URLs
                // have already passed ThemeCatalogModel's strict allowlist.
                source: item.sourceActivated && item.thumbnailPath
                  ? (root.catalogMode
                      ? item.thumbnailPath
                      : Util.fileUrl(item.thumbnailPath))
                  : ""
                fillMode: Image.PreserveAspectCrop
                // LOCAL: async for the local grid too, not just the two remote
                // ones. Upstream browses a handful of theme backgrounds and
                // can afford to decode them on the GUI thread; the wallpaper
                // library here is 658 images, and even thumbnailed, a
                // synchronous decode per step through the grid is a stutter
                // you can feel. sourceSize caps the decode at roughly the
                // slice it is drawn into, so a 62MB original never becomes a
                // 62MB texture on the way past.
                asynchronous: true
                sourceSize.width: root.sliceWidth * 4
                sourceSize.height: root.sliceHeight * 2
                cache: true
                smooth: true
              }

              Text {
                anchors.centerIn: parent
                visible: item.selected
                  && (root.wallhavenMode || root.catalogMode)
                  && (!item.thumbnailPath || image.status === Image.Error)
                text: "Preview unavailable"
                color: root.foreground
                font.pixelSize: Style.font.title
                textFormat: Text.PlainText
              }

              Rectangle {
                anchors.fill: parent
                color: Util.alpha(root.dimColor, item.selected ? 0 : 0.42)
              }

              Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.space(12)
                visible: root.localWallpaperMode
                  && WallpaperCommandModel.isFavorite(
                    root.favoriteIds,
                    item.filePath,
                    root.wallpaperFavoriteContext())
                text: "★"
                color: root.livePaletteAccent
                style: Text.Outline
                styleColor: Util.alpha(root.dimColor, 0.82)
                font.pixelSize: item.selected ? Style.font.display : Style.font.title
                font.weight: Font.Bold
                opacity: item.selected ? 1.0 : 0.86
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }

              Rectangle {
                visible: item.selected && root.livePaletteReady
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(14)
                width: paletteBadgeRow.implicitWidth + Style.space(18)
                height: paletteBadgeRow.implicitHeight + Style.space(12)
                radius: height / 2
                color: Util.alpha(root.livePaletteBase, 0.86)
                border.width: 1
                border.color: Util.alpha(root.livePaletteAccent, 0.8)

                Row {
                  id: paletteBadgeRow
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Repeater {
                    model: [root.livePaletteAccent, root.livePaletteSecondary, root.livePaletteBase]
                    Rectangle {
                      required property color modelData
                      width: Style.space(9)
                      height: width
                      radius: width / 2
                      color: modelData
                      border.width: 1
                      border.color: Util.alpha(root.foreground, 0.42)
                    }
                  }

                  Text {
                    text: "LIVE PALETTE"
                    color: root.foreground
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                    textFormat: Text.PlainText
                  }
                }
              }
            }

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: item.selected ? root.activeSelectedBorder : root.unselectedBorder
                strokeWidth: item.selected ? 3 : 1
                startX: item.topLeft; startY: 0
                PathLine { x: item.topRight; y: 0 }
                PathLine { x: item.bottomRight; y: item.height }
                PathLine { x: item.bottomLeft; y: item.height }
                PathLine { x: item.topLeft; y: 0 }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (item.selected) root.applySelected()
                else {
                  root.select(index)
                  root.focusPicker()
                }
              }
            }
          }
        }
      }

      Item {
        id: footer
        visible: root.showLabels || root.wallpaperPickerActive
        anchors.top: carousel.bottom
        anchors.topMargin: Style.space(16)
        anchors.horizontalCenter: carousel.horizontalCenter
        width: root.expandedWidth
        height: Math.max(
          selectedLabel.implicitHeight,
          favoriteControls.implicitHeight,
          wallhavenBrowseButton.implicitHeight,
          wallhavenBackButton.implicitHeight,
          loadMoreButton.implicitHeight,
          themeBrowseButton.implicitHeight,
          catalogBackButton.implicitHeight,
          uninstallButton.implicitHeight,
          catalogInstallButton.implicitHeight
        )
        readonly property real sideWidth: Math.max(
          favoriteControls.visible ? favoriteControls.implicitWidth : 0,
          wallhavenBrowseButton.visible && selectedLabel.visible ? wallhavenBrowseButton.implicitWidth : 0,
          wallhavenBackButton.visible ? wallhavenBackButton.implicitWidth : 0,
          loadMoreButton.visible ? loadMoreButton.implicitWidth : 0,
          themeBrowseButton.visible ? themeBrowseButton.implicitWidth : 0,
          catalogBackButton.visible ? catalogBackButton.implicitWidth : 0,
          uninstallButton.visible ? uninstallButton.implicitWidth : 0,
          catalogInstallButton.visible ? catalogInstallButton.implicitWidth : 0
        )

        Row {
          id: favoriteControls
          visible: root.localWallpaperMode
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Button {
            text: root.currentFavorite ? "★ Saved" : "☆ Save"
            tooltipText: "Toggle favorite (Ctrl+D)"
            foreground: root.currentFavorite ? root.livePaletteAccent : root.foreground
            accent: root.livePaletteAccent
            bordered: true
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(7)
            onClicked: root.toggleCurrentFavorite()
          }

          Button {
            enabled: root.favoriteIds.length > 0
            text: root.favoritesOnly ? "★ Favorites" : "All"
            tooltipText: "Show only favorites (Ctrl+Shift+D)"
            foreground: root.favoritesOnly ? root.livePaletteAccent : root.foreground
            accent: root.livePaletteAccent
            bordered: true
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(7)
            onClicked: root.toggleFavoritesOnly()
          }
        }

        Text {
          id: selectedLabel
          visible: root.showLabels || root.wallhavenMode || root.wallpaperPickerActive
          anchors.centerIn: parent
          width: footer.sideWidth > 0
            ? parent.width - 2 * (footer.sideWidth + Style.space(16))
            : parent.width
          text: root.currentLabel()
          color: root.foreground
          style: Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: root.wallhavenMode ? Style.font.title : Style.font.display
          font.weight: Font.DemiBold
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Button {
          id: wallhavenBrowseButton
          visible: root.wallpaperPickerActive && !root.wallhavenMode
          anchors.verticalCenter: parent.verticalCenter
          x: selectedLabel.visible ? parent.width - width : (parent.width - width) / 2
          text: "Browse Wallhaven"
          tooltipText: "Browse SFW Wallhaven wallpapers through Aether (Ctrl+B)"
          foreground: root.foreground
          accent: root.livePaletteAccent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: root.openWallhaven()
        }

        Button {
          id: themeBrowseButton
          visible: !root.catalogMode
            && !root.wallhavenMode
            && themeManager.themePickerActive
          enabled: themeManager.inventoryReady
            && !themeCatalog.loading
            && !themeManager.busy
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: !themeManager.inventoryReady
            ? "Indexing…"
            : (themeCatalog.loading ? "Loading…" : "Browse themes")
          tooltipText: "Browse community themes from verified catalog metadata (Ctrl+B)"
          foreground: root.foreground
          accent: Color.accent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: root.openCatalog()
        }

        Button {
          id: catalogBackButton
          visible: root.catalogMode
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Back"
          tooltipText: "Return to installed themes (Escape)"
          foreground: root.foreground
          accent: Color.accent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: root.leaveCatalog(true)
        }

        Button {
          id: wallhavenBackButton
          visible: root.wallhavenMode
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Back"
          tooltipText: "Return to local wallpapers (Escape)"
          foreground: root.foreground
          accent: Color.accent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: root.leaveWallhaven(true)
        }

        Button {
          id: loadMoreButton
          visible: root.wallhavenMode
          enabled: wallhaven.hasMore && !wallhaven.loading
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: wallhaven.loading
            ? "Loading…"
            : (wallhaven.hasMore ? "Load more" : "All loaded")
          tooltipText: wallhaven.hasMore
            ? "Load two more Wallhaven pages (Ctrl+N)"
            : "All available results are loaded"
          foreground: root.foreground
          accent: Color.accent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: {
            wallhaven.loadMore()
            Qt.callLater(root.focusPicker)
          }
        }

        Button {
          id: uninstallButton
          visible: !root.catalogMode
            && !root.wallhavenMode
            && themeManager.themePickerActive
            && themeManager.inventoryReady
            && themeManager.selectedThemeInstalled
          enabled: themeManager.canUninstallSelectedTheme
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: themeManager.selectedThemeIsCurrent
            ? "In use"
            : (themeManager.busy ? "Uninstalling…" : "Uninstall")
          tooltipText: themeManager.selectedThemeIsCurrent
            ? "Switch to another theme before uninstalling this one"
            : "Uninstall this user-installed theme (Delete)"
          foreground: themeManager.selectedThemeIsCurrent ? Color.muted : Color.urgent
          accent: Color.urgent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: themeManager.requestUninstall()
        }

        Button {
          id: catalogInstallButton
          visible: root.catalogMode
          enabled: themeCatalog.canInstallSelected
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: themeCatalog.selectedStatus
          tooltipText: {
            const item = themeCatalog.selectedEntry
            if (!item) return ""
            if (item.installed) return "This repository is already installed"
            if (item.stockConflict) return "This repository would overwrite a stock theme slug"
            if (item.warnings && item.warnings.length > 0)
              return "Review " + item.warnings.length + " catalog notes before installing"
            return "Clone and immediately apply this theme (Enter)"
          }
          foreground: themeCatalog.canInstallSelected ? Color.accent : Color.muted
          accent: Color.accent
          bordered: true
          horizontalPadding: Style.space(12)
          verticalPadding: Style.space(7)
          onClicked: themeCatalog.requestInstall()
        }
      }

      WallhavenFilterBar {
        id: wallhavenFilters
        visible: root.wallhavenMode
        anchors.top: footer.bottom
        anchors.topMargin: Style.space(8)
        anchors.horizontalCenter: carousel.horizontalCenter
        height: implicitHeight
        summary: root.wallhavenFilterSummary
        filtersActive: root.wallhavenFiltersActive
        foreground: root.foreground
        accent: Color.accent
        onOpenRequested: root.openWallhavenFilters()
      }

      Text {
        visible: root.wallhavenMode
        anchors.top: wallhavenFilters.bottom
        anchors.topMargin: Style.space(8)
        anchors.horizontalCenter: carousel.horizontalCenter
        width: root.expandedWidth
        text: {
          if (wallhaven.downloading) return "Downloading full wallpaper with Aether…"
          if (wallhaven.errorMessage) return wallhaven.errorMessage
          if (wallhaven.loading && root.imageArray.length > 0)
            return "Loading more with Aether…  " + root.imageArray.length + " loaded"
          if (wallhaven.loading) return "Searching Wallhaven with Aether…"
          if (root.filterText)
            return "Search: " + root.filterText + "  ·  " + root.imageArray.length + " loaded"
          return wallhaven.totalResults > 0
            ? root.imageArray.length + " of " + wallhaven.totalResults + " loaded  ·  Type to search"
            : "Type to search Wallhaven"
        }
        color: wallhaven.errorMessage ? Color.urgent : root.foreground
        opacity: 0.9
        style: Text.Outline
        styleColor: Util.alpha(root.dimColor, 0.7)
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Column {
        id: themeStatusColumn
        anchors.top: footer.bottom
        anchors.topMargin: Style.space(8)
        anchors.horizontalCenter: carousel.horizontalCenter
        width: root.expandedWidth
        spacing: Style.space(4)

        Text {
          visible: !root.wallhavenMode && root.catalogMode
          width: parent.width
          text: root.currentCatalogMeta()
          color: root.foreground
          opacity: 0.75
          style: Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          visible: !root.wallhavenMode && root.filterable && root.filterText
          width: parent.width
          text: root.filterText
          color: root.foreground
          opacity: 0.85
          style: Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: Style.font.title
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          visible: !root.wallhavenMode
            && (themeManager.errorMessage !== "" || themeCatalog.errorMessage !== "")
          width: parent.width
          text: themeCatalog.errorMessage || themeManager.errorMessage
          color: Color.urgent
          style: Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }

      ConfirmDialog {
        id: uninstallConfirm
        anchors.fill: parent
        opened: themeManager.confirmationOpen
        z: 1000
        message: "Uninstall " + ThemeManagerModel.labelForThemeName(themeManager.pendingTheme) + "?"
        confirmText: "Uninstall"
        background: root.dimColor
        foreground: root.foreground
        scrim: root.scrim
        selectedText: Color.accent
        onCanceled: themeManager.cancelUninstall()
        onConfirmed: themeManager.confirmUninstall()
      }

      ConfirmDialog {
        id: installConfirm
        anchors.fill: parent
        opened: themeCatalog.confirmationOpen
        z: 1000
        message: themeCatalog.confirmationMessage
        confirmText: "Install"
        background: root.dimColor
        foreground: root.foreground
        scrim: root.scrim
        selectedText: Color.accent
        onCanceled: themeCatalog.cancelInstall()
        onConfirmed: themeCatalog.confirmInstall()
      }
    }

    Item {
      visible: root.opened
        && root.imagesLoaded
        && root.layoutSettled
      && root.wallhavenMode
      && root.imageArray.length === 0
      width: root.expandedWidth
      height: 300
      anchors.centerIn: parent

      MouseArea { anchors.fill: parent; onClicked: {} }

      Text {
        id: emptyStateTitle
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -24
        text: {
          if (wallhaven.errorMessage) return wallhaven.errorMessage
          if (wallhaven.loading) return "Searching Wallhaven with Aether…"
          return root.filterText
            ? "No SFW wallpapers found for “" + root.filterText + "”"
            : "No Wallhaven wallpapers found"
        }
        color: wallhaven.errorMessage ? Color.urgent : root.foreground
        font.pixelSize: Style.font.title
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }

      Text {
        id: emptyStateHint
        anchors.top: emptyStateTitle.bottom
        anchors.topMargin: Style.space(10)
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Type to search  ·  Escape to return to local wallpapers"
        color: root.foreground
        opacity: 0.75
        font.pixelSize: Style.font.body
        textFormat: Text.PlainText
      }

      WallhavenFilterBar {
        id: emptyStateFilters
        anchors.top: emptyStateHint.bottom
        anchors.topMargin: Style.space(16)
        anchors.horizontalCenter: parent.horizontalCenter
        height: implicitHeight
        summary: root.wallhavenFilterSummary
        filtersActive: root.wallhavenFiltersActive
        foreground: root.foreground
        accent: Color.accent
        onOpenRequested: root.openWallhavenFilters()
      }

      Button {
        visible: !!wallhaven.errorMessage && !wallhaven.loading
        anchors.top: emptyStateFilters.bottom
        anchors.topMargin: Style.space(16)
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Retry"
        foreground: root.foreground
        accent: Color.accent
        bordered: true
        horizontalPadding: Style.space(12)
        verticalPadding: Style.space(7)
        onClicked: root.searchWallhaven()
      }
    }

    WallhavenFilterSheet {
      id: filterSheet

      anchors.fill: parent
      background: root.dimColor
      foreground: root.foreground
      scrim: Util.alpha(root.dimColor, 0.88)
      accent: Color.accent
      onCanceled: Qt.callLater(root.focusPicker)
      onApplied: function(filters) { root.applyWallhavenFilters(filters) }
    }
  }
}
