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

Item {
  id: root

  // Injected by omarchy-shell; defaults to the session OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var manifest: null
  property string stateHome: Quickshell.env("HOME") + "/.local/state"
  property string imageDirs: Quickshell.env("OMARCHY_IMAGE_SELECTOR_DIRS") || Quickshell.env("OMARCHY_IMAGE_SELECTOR_DIR") || Quickshell.env("OMARCHY_STOCK_BACKGROUNDS_DIR") || (stateHome + "/omarchy/current/theme/backgrounds")
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
  // Bound to the central [image-picker] section in shell.toml via Color.qml.
  // `dimColor` tints unselected slices and text outlines on top of the scrim;
  // it intentionally tracks the foundational background, not a surface role.
  property color dimColor: Color.background
  property color foreground: Color.imagePicker.text
  property color scrim: Color.imagePicker.scrim
  property color selectedBorder: Color.imagePicker.selectedBorder
  property color unselectedBorder: Color.imagePicker.unselectedBorder
  property int expandedWidth: 768
  property int expandedHeight: 475
  property int sliceWidth: 108
  property int sliceHeight: 432
  property int sliceSpacing: -30
  property int skewOffset: 28
  property int bottomChromeHeight: showLabels
    ? (catalogMode ? 150 : (filterable ? 104 : 74))
    : (filterable ? 60 : 30)

  onOpenedChanged: {
    if (!opened) {
      if (catalogMode) leaveCatalog(false)
      layoutSettled = false
    }
  }

  function scriptPath(name) {
    return omarchyPath + "/shell/plugins/image-picker/" + name
  }

  function pluginScriptPath(name) {
    const sourceDir = manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
    return sourceDir ? sourceDir.replace(/\/$/, "") + "/" + name : ""
  }

  function focusPicker() {
    if (root.opened && root.imagesLoaded && root.layoutSettled)
      carousel.forceActiveFocus()
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

  function currentItem() {
    if (imageArray.length === 0 || !itemMatches(selectedIndex)) return null
    return imageArray[selectedIndex]
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
    if (!themeManager.themePickerActive || !themeManager.inventoryReady || catalogMode) return
    themeCatalog.load()
  }

  function enterCatalog(rows) {
    if (!Array.isArray(rows) || rows.length === 0) return

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
    return ImagePickerModel.itemMatches(imageArray, index, filterText)
  }

  function firstMatchingIndex() {
    return ImagePickerModel.firstMatchingIndex(imageArray, filterText)
  }

  function filteredPosition(index) {
    return ImagePickerModel.filteredPosition(imageArray, index, filterText)
  }

  function selectedFilteredPosition() {
    return ImagePickerModel.selectedFilteredPosition(imageArray, selectedIndex, filterText)
  }

  function select(index, immediate) {
    if (imageArray.length === 0) return
    if (index < 0) index = 0
    else if (index >= imageArray.length) index = imageArray.length - 1
    if (!itemMatches(index)) return
    if (index === selectedIndex && immediate !== true) return

    selectedIndex = index
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
    filterText = nextFilterText

    if (!itemMatches(selectedIndex)) {
      const first = ImagePickerModel.nextSelectedIndexForFilter(imageArray, selectedIndex, filterText)
      if (first >= 0) selectedIndex = first
    }
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

  function applySelected() {
    if (catalogMode) {
      themeCatalog.requestInstall()
      return
    }

    const path = currentPath()
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

  function cancel() {
    if (catalogMode) leaveCatalog(false)

    if (requestActive)
      finishDoneFile(doneFile)

    requestActive = false
    selectionFile = ""
    doneFile = ""
    root.opened = false
  }

  function closeSelector(nextDoneFile) {
    if (catalogMode) leaveCatalog(false)
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
    const newImages = ImagePickerModel.loadRows(rows)

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
    if (requestActive && doneFile && doneFile !== nextDoneFile)
      finishDoneFile(doneFile)

    requestSerial += 1

    imageDirs = nextImageDirs
    imageRows = nextImageRows
    selectedImage = nextSelectedImage
    selectionFile = nextSelectionFile
    doneFile = nextDoneFile
    requestActive = !!doneFile
    showLabels = nextShowLabels === true || nextShowLabels === "true"
    filterable = nextFilterable === true || nextFilterable === "true"
    filterText = ""
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

  // Lifecycle hooks invoked by omarchy-shell summon/hide. shell.summon(id,
  // payloadJson) hands the JSON to open() here; shell.hide(id) calls close().
  // The shell host owns the stable `image-selector` IPC target and forwards
  // those lower-level positional calls here.
  function open(payload) {
    let args = {}
    if (payload) {
      try { args = JSON.parse(payload) || {} } catch (e) { args = {} }
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
    // Theme/background set hooks can warm selector rows after a picker was
    // dismissed. Ignore those preloads while a user-visible request is open;
    // otherwise the preload resets layoutSettled without revealing again,
    // leaving only the fullscreen scrim.
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

  ThemeManagerController {
    id: themeManager
    selectedPath: root.currentPath()
    pickerOpen: root.opened
    inventoryScriptPath: root.pluginScriptPath("theme-inventory.sh")
    onThemeRemoved: function(name) { root.removeThemeFromRows(name) }
    onFocusRequested: Qt.callLater(root.focusPicker)
  }

  ThemeCatalogController {
    id: themeCatalog
    catalogScriptPath: root.pluginScriptPath("catalog.sh")
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
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened && root.imagesLoaded
      onClicked: root.cancel()
    }

    Item {
      id: card
      visible: root.opened && root.imagesLoaded && root.layoutSettled && root.imageArray.length > 0
      width: Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
      height: root.expandedHeight + Style.space(30) + root.bottomChromeHeight
      anchors.centerIn: parent

        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
          id: carousel
          anchors.top: parent.top
          anchors.topMargin: Style.space(30)
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.bottomChromeHeight
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
          clip: false
          focus: true

          readonly property real itemStep: root.sliceWidth + root.sliceSpacing
          readonly property real previewX: (width - root.expandedWidth) / 2

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (themeCatalog.confirmationOpen) {
              if (installConfirm.handleKey(event)) event.accepted = true
            } else if (themeManager.confirmationOpen) {
              if (uninstallConfirm.handleKey(event)) event.accepted = true
            } else if (event.key === Qt.Key_Delete && !root.catalogMode && themeManager.themePickerActive) {
              themeManager.requestUninstall()
              event.accepted = true
            } else if (event.key === Qt.Key_B
                       && (event.modifiers & Qt.ControlModifier) !== 0
                       && !root.catalogMode
                       && themeManager.themePickerActive) {
              root.openCatalog()
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              if (root.filterText) {
                root.updateFilter("")
              } else if (root.catalogMode) {
                root.leaveCatalog(true)
              } else {
                root.cancel()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.applySelected()
              event.accepted = true
            } else if (root.filterable && Util.editsFilter(event, root.filterText)) {
              root.updateFilter(Util.editedFilter(event, root.filterText))
              event.accepted = true
            } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab) {
              root.selectAdjacent(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
              root.selectAdjacent(1)
              event.accepted = true
            } else if (root.filterable && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
              root.updateFilter(root.filterText + event.text)
              event.accepted = true
            }
          }

          Component.onCompleted: forceActiveFocus()

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
                && Math.abs(relativeIndex) <= (root.catalogMode ? 7 : 16)
              property bool sourceActivated: nearby
              onNearbyChanged: if (nearby) sourceActivated = true

              visible: nearby
              x: selected ? carousel.previewX : (relativeIndex < 0 ? carousel.previewX + relativeIndex * carousel.itemStep : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)
              width: selected ? root.expandedWidth : root.sliceWidth
              height: selected ? root.expandedHeight : root.sliceHeight
              y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
              z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)

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
                  // Load only the initial/visited nearby images, but keep the
                  // source once activated so Qt does not tear textures down as
                  // selection moves through the carousel.
                  source: item.sourceActivated && item.thumbnailPath
                    ? (item.thumbnailPath.indexOf("://") !== -1
                        ? item.thumbnailPath
                        : Util.fileUrl(item.thumbnailPath))
                    : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: root.catalogMode
                  cache: true
                  smooth: true
                }

                Text {
                  anchors.centerIn: parent
                  visible: item.selected
                    && root.catalogMode
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
              }

              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "transparent"
                  strokeColor: item.selected ? root.selectedBorder : root.unselectedBorder
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
                onClicked: item.selected ? root.applySelected() : root.select(index)
              }
            }
          }
        }

        Item {
          id: footer
          visible: root.showLabels
          anchors.top: carousel.bottom
          anchors.topMargin: Style.space(16)
          anchors.horizontalCenter: carousel.horizontalCenter
          width: root.expandedWidth
          height: Math.max(
            selectedLabel.implicitHeight,
            browseButton.implicitHeight,
            catalogBackButton.implicitHeight,
            uninstallButton.implicitHeight,
            catalogInstallButton.implicitHeight
          )
          readonly property real sideWidth: Math.max(
            browseButton.visible ? browseButton.implicitWidth : 0,
            catalogBackButton.visible ? catalogBackButton.implicitWidth : 0,
            uninstallButton.visible ? uninstallButton.implicitWidth : 0,
            catalogInstallButton.visible ? catalogInstallButton.implicitWidth : 0
          )

          Text {
            id: selectedLabel
            anchors.centerIn: parent
            width: footer.sideWidth > 0
              ? parent.width - 2 * (footer.sideWidth + Style.space(16))
              : parent.width
            text: root.currentLabel()
            color: root.foreground
            style: Text.Outline
            styleColor: Util.alpha(root.dimColor, 0.7)
            font.pixelSize: Style.font.display
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }

          Button {
            id: browseButton
            visible: !root.catalogMode && themeManager.themePickerActive
            enabled: themeManager.inventoryReady && !themeCatalog.loading && !themeManager.busy
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
            id: uninstallButton
            visible: !root.catalogMode
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

        Column {
          id: statusColumn
          anchors.top: footer.bottom
          anchors.topMargin: Style.space(8)
          anchors.horizontalCenter: carousel.horizontalCenter
          width: root.expandedWidth
          spacing: Style.space(4)

          Text {
            visible: root.catalogMode
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
            visible: root.filterable && root.filterText
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
            visible: themeManager.errorMessage !== "" || themeCatalog.errorMessage !== ""
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
  }
}
