import Quickshell.Io
import QtQuick
import qs.Commons
import "WallpaperPaletteModel.js" as WallpaperPaletteModel

Item {
  id: root

  property string sourcePath: ""
  property color fallbackBase: Color.background
  property color fallbackAccent: Color.accent
  property color base: fallbackBase
  property color accent: fallbackAccent
  property color secondary: fallbackAccent
  property bool ready: false
  property string sampledPath: ""
  property int sourceGeneration: 0

  function reset() {
    ready = false
    sampledPath = ""
    base = fallbackBase
    accent = fallbackAccent
    secondary = fallbackAccent
  }

  function queueSample() {
    sampleDelay.restart()
  }

  function startSample() {
    const path = String(sourcePath || "")
    if (!path || path.charAt(0) !== "/") {
      reset()
      return
    }
    if (sampler.running) return
    sampler.activePath = path
    sampler.activeGeneration = sourceGeneration
    sampler.result = ""
    sampler.command = [
      "magick", path + "[0]",
      "-alpha", "off",
      "-thumbnail", "64x64^",
      "-gravity", "center",
      "-extent", "64x64",
      "-colorspace", "sRGB",
      "-depth", "8",
      "-colors", "8",
      "-format", "%c",
      "histogram:info:-"
    ]
    sampler.running = true
  }

  onSourcePathChanged: {
    sourceGeneration += 1
    reset()
    queueSample()
  }
  onFallbackBaseChanged: if (!ready) base = fallbackBase
  onFallbackAccentChanged: if (!ready) {
    accent = fallbackAccent
    secondary = fallbackAccent
  }
  Component.onCompleted: queueSample()

  Behavior on base { ColorAnimation { duration: 360; easing.type: Easing.OutCubic } }
  Behavior on accent { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
  Behavior on secondary { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Timer {
    id: sampleDelay
    interval: 140
    repeat: false
    onTriggered: root.startSample()
  }

  Process {
    id: sampler
    property string activePath: ""
    property string result: ""
    property int activeGeneration: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: sampler.result = String(text || "").slice(0, 8192)
    }

    onExited: function(exitCode) {
      const currentPath = String(root.sourcePath || "")
      const sourceChanged = activeGeneration !== root.sourceGeneration
        || activePath !== currentPath
      if (exitCode === 0 && !sourceChanged) {
        const palette = WallpaperPaletteModel.paletteFromHistogram(result)
        if (palette) {
          root.base = palette.base
          root.accent = palette.accent
          root.secondary = palette.secondary
          root.sampledPath = activePath
          root.ready = true
        }
      }
      activePath = ""
      activeGeneration = 0
      // A source change while ImageMagick was running needs one fresh sample.
      // A failed sample of the current source must not become a process loop.
      if (currentPath && sourceChanged)
        Qt.callLater(root.startSample)
    }
  }
}
