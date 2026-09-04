import Quickshell.Io
import QtQuick
import "ThemeCatalogModel.js" as ThemeCatalogModel

Item {
  id: root

  property string catalogScriptPath: ""
  // LOCAL: installing goes through qs-theme, not the omarchy CLI.
  property string themeBin: ""
  property bool pickerOpen: false
  property var installedThemes: ({})
  property var stockThemes: ({})
  property var installedRepositories: []
  property var payload: ({})
  // LOCAL: what `qs-theme check` has said about each repository, keyed by the
  // canonical URL catalogRows already put on the row. The catalog knows a
  // package exists; it cannot know whether qs-theme can read it, because an
  // older package ships a file per application and no palette at all - Ayaka
  // is one. Asking at install time means the answer arrives as a failure
  // after a clone, so the browser asks when the cursor lands on a package.
  property var checkedRepositories: ({})
  property string queuedCheckUrl: ""
  property var rows: []
  property var selectedEntry: null
  property bool loading: false
  property bool busy: false
  property bool confirmationOpen: false
  property var pendingEntry: null
  property string catalogStderr: ""
  property string installStderr: ""
  property string errorMessage: ""

  // LOCAL: the verdict is read here rather than built into the rows. The grid
  // is handed its rows once, by enterCatalog, and a verdict lands long after
  // that - rebuilding the rows behind the grid would never reach it.
  readonly property string selectedVerdict: selectedEntry
    ? String(checkedRepositories[String(selectedEntry.repositoryUrl || "")] || "")
    : ""
  readonly property var selectedState:
    ThemeCatalogModel.entryState(selectedEntry, selectedVerdict)

  readonly property bool canInstallSelected: selectedState.canInstall === true && !busy
  readonly property string selectedStatus: busy ? "Installing…" : selectedState.status
  readonly property string confirmationMessage:
    ThemeCatalogModel.installConfirmationMessage(pendingEntry)

  signal catalogLoaded(var rows)
  signal themeInstalled(string name)
  signal focusRequested()

  onPickerOpenChanged: if (!pickerOpen) resetTransientState()
  onSelectedEntryChanged: {
    if (!busy) errorMessage = ""
    requestCheck(selectedEntry)
  }
  onInstalledThemesChanged: rebuildRows(false)
  onStockThemesChanged: rebuildRows(false)
  onInstalledRepositoriesChanged: rebuildRows(false)

  function resetTransientState() {
    confirmationOpen = false
    pendingEntry = null
    errorMessage = ""
  }

  function inventory() {
    return {
      installedThemes,
      stockThemes,
      installedRepositories
    }
  }

  function rebuildRows(notify) {
    if (!payload || !Array.isArray(payload.themes)) return
    rows = ThemeCatalogModel.catalogRows(payload, inventory())
    if (notify === true) catalogLoaded(rows)
  }

  function load() {
    if (loading || busy || !catalogScriptPath) return

    loading = true
    errorMessage = ""
    catalogStderr = ""
    catalogProc.command = [catalogScriptPath]
    catalogProc.running = true
  }

  // LOCAL: one check at a time, and only ever for where the cursor is now.
  // A single queued slot rather than a queue: arrowing across the grid would
  // otherwise line up a fetch for every tile it passed over, and the answer
  // is only wanted for the tile it stops on.
  function requestCheck(entry) {
    if (!entry || entry.installed === true || entry.stockConflict === true) return

    const url = String(entry.repositoryUrl || "")
    if (!url || !themeBin) return
    if (checkedRepositories[url] !== undefined) return

    queuedCheckUrl = url
    pumpChecks()
  }

  function pumpChecks() {
    if (checkProc.running || busy || queuedCheckUrl === "") return

    const url = queuedCheckUrl
    queuedCheckUrl = ""
    checkProc.targetUrl = url
    // LOCAL: check fetches the one file install insists on and puts it through
    // the same resolve, writing nothing. 0 installable, 4 a fact about the
    // package, anything else an admission that nothing was learned.
    checkProc.command = [themeBin, "check", url]
    checkProc.running = true
  }

  function recordVerdict(url, verdict) {
    // Reassigned rather than mutated: a var property only notifies on
    // assignment, and the footer's binding is what has to notice.
    const next = {}
    for (const key in checkedRepositories) next[key] = checkedRepositories[key]
    next[url] = verdict
    checkedRepositories = next
  }

  function requestInstall() {
    if (!canInstallSelected) return
    pendingEntry = selectedEntry
    confirmationOpen = true
  }

  function cancelInstall() {
    confirmationOpen = false
    pendingEntry = null
    focusRequested()
  }

  function confirmInstall() {
    const entry = pendingEntry
    confirmationOpen = false
    pendingEntry = null

    if (!entry || entry !== selectedEntry || !canInstallSelected) {
      focusRequested()
      return
    }

    busy = true
    errorMessage = ""
    installStderr = ""
    installProc.targetEntry = entry
    // LOCAL: qs-theme install clones the package, refuses it unless there is
    // a colors.toml at the root that resolves, writes the URL to track it by
    // and copies its backgrounds into the wallpaper library.
    installProc.command = [themeBin, "install", entry.repositoryUrl]
    installProc.running = true
  }

  Process {
    id: catalogProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const parsed = JSON.parse(String(text || "{}"))
          root.payload = parsed
          root.rebuildRows(true)
          if (root.rows.length === 0)
            root.errorMessage = "No installable themes were found in the catalog"
        } catch (_) {
          root.rows = []
          root.errorMessage = "The theme catalog returned invalid data"
        }
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.catalogStderr = String(text || "").trim()
        if (!catalogProc.running && root.errorMessage !== "" && root.catalogStderr !== "")
          root.errorMessage = root.catalogStderr
      }
    }

    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) {
        root.rows = []
        root.errorMessage = root.catalogStderr || "Could not load the theme catalog"
        root.focusRequested()
      }
    }
  }

  // LOCAL: the pre-flight. Its output is not shown - the verdict is the exit
  // status, and the browser says the same thing however a package failed - so
  // both streams are collected only to keep them off the terminal.
  Process {
    id: checkProc
    property string targetUrl: ""

    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }

    onExited: function(exitCode) {
      const url = targetUrl
      targetUrl = ""
      if (url !== "")
        root.recordVerdict(
          url,
          exitCode === 0
            ? ThemeCatalogModel.OK
            : (exitCode === 4 ? ThemeCatalogModel.UNUSABLE : ThemeCatalogModel.UNVERIFIED)
        )
      root.pumpChecks()
    }
  }

  Process {
    id: installProc
    property var targetEntry: null

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.installStderr = String(text || "").trim()
        if (!installProc.running && root.errorMessage !== "" && root.installStderr !== "")
          root.errorMessage = root.installStderr
      }
    }

    onExited: function(exitCode) {
      const installedEntry = targetEntry
      targetEntry = null
      root.busy = false
      root.pumpChecks()

      if (exitCode === 0 && installedEntry) {
        root.themeInstalled(installedEntry.installSlug)
      } else {
        root.errorMessage = root.installStderr
          || "Could not install " + (installedEntry ? installedEntry.displayName : "the theme")
        root.focusRequested()
      }
    }
  }
}
