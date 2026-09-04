// LOCAL: the host this fork runs under.
//
// Upstream is an omarchy-shell plugin: the plugin host loads
// v0200/ImagePicker.qml as an "overlay", hands it a manifest and a source
// directory, and calls open()/close() on it over the shell's IPC. There is no
// such host here, so this file is it - a quickshell config root that
// instantiates the same overlay, opens it once, and exits when it closes.
//
// One-shot rather than resident, which is how the other picker on this desktop
// works too (qs-wallpaper-picker's Main.qml, launched by open_picker.sh). The
// bar is the only thing that stays running; a picker that lingers is a window
// nobody asked to keep.
//
// The payload is the same JSON openSelector() takes from the plugin host, so
// nothing about the request protocol is forked - scripts/theme-manager.sh
// builds it, and reads the answer back out of the selection file.
import Quickshell
import QtQuick
import "v0200" as Runtime

ShellRoot {
  id: host

  // Whether the overlay has ever been up. Without this the picker would quit
  // during its own startup: opened is false until the first image scan
  // finishes, which is well after this file is done.
  property bool shown: false

  Runtime.ImagePicker {
    id: picker

    onOpenedChanged: {
      if (opened) {
        host.shown = true
        return
      }
      // The selection file has already been written and the done file
      // touched by this point - closeSelector does both before clearing
      // opened - so there is nothing left to wait for.
      if (host.shown) Qt.quit()
    }
  }

  // Not Component.onCompleted on the picker itself: ImagePicker declares one
  // of its own, and an attached handler on the instance would replace it.
  Component.onCompleted: picker.open(Quickshell.env("QS_TM_PAYLOAD") || "{}")
}
