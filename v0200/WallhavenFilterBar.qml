import QtQuick
import qs.Commons
import qs.Ui

Row {
  id: root

  property string summary: "All categories  ·  Latest ↓  ·  1080p+"
  property bool filtersActive: false
  // LOCAL: handed down by ImagePicker so this sheet's text and padding
  // scale with the overlay it opens over. 1 is upstream's own size.
  property real uiScale: 1
  function px(n) { return Math.max(1, Math.round(n * uiScale)) }
  property color foreground: Color.foreground
  property color accent: Color.accent

  signal openRequested()

  spacing: Style.space(10)

  Button {
    anchors.verticalCenter: parent.verticalCenter
    text: "Filters"
    tooltipText: "Choose Wallhaven filters (Ctrl+F)"
    selected: root.filtersActive
    foreground: root.foreground
    accent: root.accent
    bordered: true
    fontSize: root.px(Style.font.body)
    horizontalPadding: root.px(Style.space(12))
    verticalPadding: root.px(Style.space(6))
    onClicked: root.openRequested()
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.summary
    color: root.foreground
    opacity: 0.78
    font.pixelSize: root.px(Style.font.bodySmall)
    textFormat: Text.PlainText
  }
}
