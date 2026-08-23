import Quickshell
import Quickshell.Io
import QtQuick
import "ThemeManagerModel.js" as ThemeManagerModel

Item {
  id: root

  property string selectedPath: ""
  property bool pickerOpen: false
  property string inventoryScriptPath: ""
  property string currentThemeName: ""
  property var installedThemes: ({})
  property var stockThemes: ({})
  property var installedRepositories: []
  property bool inventoryReady: false
  property bool confirmationOpen: false
  property bool busy: false
  property string pendingTheme: ""
  property string errorMessage: ""
  property string uninstallStderr: ""

  readonly property string currentThemeFile: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
  readonly property string selectedThemeName: ThemeManagerModel.themeNameForPath(selectedPath)
  readonly property bool themePickerActive: selectedThemeName !== ""
  readonly property bool selectedThemeInstalled: inventoryReady
    && ThemeManagerModel.hasTheme(installedThemes, selectedThemeName)
  readonly property bool selectedThemeIsCurrent: themePickerActive
    && selectedThemeName === currentThemeName
  readonly property bool canUninstallSelectedTheme: selectedThemeInstalled
    && ThemeManagerModel.isSafeThemeName(selectedThemeName)
    && !selectedThemeIsCurrent
    && !busy

  signal themeRemoved(string name)
  signal focusRequested()

  onPickerOpenChanged: {
    if (pickerOpen) {
      if (themePickerActive) refreshInventory()
    } else {
      resetTransientState()
    }
  }

  onThemePickerActiveChanged: {
    if (pickerOpen && themePickerActive) refreshInventory()
  }

  onSelectedPathChanged: errorMessage = ""

  function resetTransientState() {
    confirmationOpen = false
    pendingTheme = ""
    errorMessage = ""
  }

  function refreshInventory() {
    if (inventoryProc.running) {
      inventoryProc.refreshQueued = true
      return
    }

    inventoryReady = false
    errorMessage = ""
    inventoryProc.refreshQueued = false
    inventoryProc.command = [inventoryScriptPath]
    inventoryProc.running = true
  }

  function requestUninstall() {
    if (!canUninstallSelectedTheme) return

    pendingTheme = selectedThemeName
    confirmationOpen = true
  }

  function cancelUninstall() {
    confirmationOpen = false
    pendingTheme = ""
    focusRequested()
  }

  function confirmUninstall() {
    const themeName = pendingTheme
    confirmationOpen = false
    pendingTheme = ""

    if (themeName !== selectedThemeName
        || !ThemeManagerModel.hasTheme(installedThemes, themeName)
        || !canUninstallSelectedTheme) {
      focusRequested()
      return
    }

    busy = true
    errorMessage = ""
    uninstallStderr = ""
    uninstallProc.targetTheme = themeName
    uninstallProc.command = ["omarchy", "theme", "remove", themeName]
    uninstallProc.running = true
  }

  FileView {
    path: root.currentThemeFile
    watchChanges: true
    printErrors: false
    onLoaded: root.currentThemeName = String(text() || "").trim()
    onFileChanged: reload()
  }

  Process {
    id: inventoryProc
    property bool refreshQueued: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const inventory = ThemeManagerModel.themeInventoryFromText(String(text || ""))
        root.installedThemes = inventory.installedThemes
        root.stockThemes = inventory.stockThemes
        root.installedRepositories = inventory.installedRepositories
        root.inventoryReady = true
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.installedThemes = ({})
        root.stockThemes = ({})
        root.installedRepositories = []
        root.inventoryReady = false
        root.errorMessage = "Could not read the installed theme inventory"
      }

      if (refreshQueued) {
        refreshQueued = false
        Qt.callLater(root.refreshInventory)
      }
    }
  }

  Process {
    id: uninstallProc
    property string targetTheme: ""

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.uninstallStderr = String(text || "").trim()
        if (!uninstallProc.running && root.errorMessage !== "" && root.uninstallStderr !== "")
          root.errorMessage = root.uninstallStderr
      }
    }

    onExited: function(exitCode) {
      const removedTheme = targetTheme
      targetTheme = ""
      root.busy = false

      if (exitCode === 0) {
        root.installedThemes = ThemeManagerModel.withoutTheme(root.installedThemes, removedTheme)
        root.inventoryReady = true
        root.themeRemoved(removedTheme)
      } else {
        root.errorMessage = root.uninstallStderr
          || "Could not uninstall " + ThemeManagerModel.labelForThemeName(removedTheme)
        root.refreshInventory()
      }

      root.focusRequested()
    }
  }
}
