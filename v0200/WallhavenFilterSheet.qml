pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "WallpaperBrowserModel.js" as WallpaperBrowserModel

Item {
  id: root

  property bool opened: false
  property string draftCategories: "111"
  property string draftSorting: "date_added"
  property string draftOrder: "desc"
  property string draftAtLeast: "1920x1080"
  property string draftColors: ""
  property color background: Color.background
  property color foreground: Color.foreground
  property color scrim: Util.alpha(Color.background, 0.82)
  property color accent: Color.accent
  property int cursorSection: 0
  property int categoryCursor: 0
  property int sortingCursor: 0
  property int resolutionCursor: 1
  property int colorCursor: 0
  readonly property var sortingOptions: WallpaperBrowserModel.getSortingOptions()
  readonly property var resolutionOptions: WallpaperBrowserModel.getResolutionOptions()
  readonly property var colorOptions: WallpaperBrowserModel.getColorOptions()

  signal canceled()
  signal applied(var filters)

  function optionIndex(options, value, fallback) {
    for (let index = 0; index < options.length; index++) {
      if (String(options[index].value) === String(value)) return index
    }
    return fallback
  }

  function wrap(index, length) {
    return (index + length) % length
  }

  function draftFilters() {
    return WallpaperBrowserModel.normalizeFilters({
      categories: draftCategories,
      sorting: draftSorting,
      order: draftOrder,
      atLeast: draftAtLeast,
      colors: draftColors
    })
  }

  function openWith(filters) {
    const normalized = WallpaperBrowserModel.normalizeFilters(filters)
    draftCategories = normalized.categories
    draftSorting = normalized.sorting
    draftOrder = normalized.order
    draftAtLeast = normalized.atLeast
    draftColors = normalized.colors
    cursorSection = 0
    categoryCursor = 0
    sortingCursor = optionIndex(sortingOptions, draftSorting, 0)
    resolutionCursor = optionIndex(resolutionOptions, draftAtLeast, 1)
    colorCursor = optionIndex(colorOptions, draftColors, 0)
    opened = true
  }

  function resetDraft() {
    draftCategories = "111"
    draftSorting = "date_added"
    draftOrder = "desc"
    draftAtLeast = "1920x1080"
    draftColors = ""
    categoryCursor = 0
    sortingCursor = 0
    resolutionCursor = 1
    colorCursor = 0
  }

  function toggleCategory(index) {
    draftCategories = WallpaperBrowserModel.toggleCategory(draftCategories, index)
  }

  function cancel() {
    opened = false
    canceled()
  }

  function apply() {
    const filters = draftFilters()
    opened = false
    applied(filters)
  }

  function handleKey(event) {
    if (!opened) return false

    if (event.key === Qt.Key_Escape) {
      cancel()
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      apply()
    } else if (event.key === Qt.Key_Backspace) {
      resetDraft()
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
      cursorSection = wrap(cursorSection - 1, 4)
    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
      cursorSection = wrap(cursorSection + 1, 4)
    } else if (event.key === Qt.Key_D && cursorSection === 1) {
      draftOrder = draftOrder === "desc" ? "asc" : "desc"
    } else if (event.key === Qt.Key_Space && cursorSection === 0) {
      toggleCategory(categoryCursor)
    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      const direction = event.key === Qt.Key_Left ? -1 : 1
      if (cursorSection === 0) {
        categoryCursor = wrap(categoryCursor + direction, 3)
      } else if (cursorSection === 1) {
        sortingCursor = wrap(sortingCursor + direction, sortingOptions.length)
        draftSorting = sortingOptions[sortingCursor].value
      } else if (cursorSection === 2) {
        resolutionCursor = wrap(resolutionCursor + direction, resolutionOptions.length)
        draftAtLeast = resolutionOptions[resolutionCursor].value
      } else {
        colorCursor = wrap(colorCursor + direction, colorOptions.length)
        draftColors = colorOptions[colorCursor].value
      }
    } else {
      return false
    }

    return true
  }

  visible: opened
  z: 500

  Rectangle {
    anchors.fill: parent
    color: root.scrim

    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }
  }

  BorderSurface {
    id: card

    width: Math.min(parent.width - Style.space(48), Style.space(860))
    height: Style.space(430)
    anchors.centerIn: parent
    color: root.background
    borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
    radius: Style.cornerRadius
    padding: Style.space(24)

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
      spacing: Style.space(14)

      Item {
        width: parent.width
        height: Style.space(48)

        Text {
          anchors.left: parent.left
          anchors.top: parent.top
          text: "Filter Wallhaven"
          color: root.foreground
          font.pixelSize: Style.font.heading
          font.weight: Font.DemiBold
          textFormat: Text.PlainText
        }

        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          text: "Stage your choices, then make one Aether request"
          color: root.foreground
          opacity: 0.64
          font.pixelSize: Style.font.bodySmall
          textFormat: Text.PlainText
        }

        BorderSurface {
          anchors.right: parent.right
          anchors.top: parent.top
          width: sfwText.implicitWidth + Style.space(18)
          height: Style.space(28)
          color: Util.alpha(root.accent, 0.12)
          borderSpec: Border.flat(Util.alpha(root.accent, 0.8), Style.normalBorderWidth)
          radius: Style.cornerRadius

          Text {
            id: sfwText
            anchors.centerIn: parent
            text: "SFW only"
            color: root.accent
            font.pixelSize: Style.font.bodySmall
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(38)

        Text {
          width: Style.space(108)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Categories"
          color: root.cursorSection === 0 ? root.accent : root.foreground
          opacity: root.cursorSection === 0 ? 1 : 0.72
          font.pixelSize: Style.font.body
          font.weight: root.cursorSection === 0 ? Font.DemiBold : Font.Normal
          textFormat: Text.PlainText
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(118)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Repeater {
            model: ["General", "Anime", "People"]

            Button {
              required property int index
              required property string modelData

              text: modelData
              selected: root.draftCategories.charAt(index) === "1"
              hasCursor: root.cursorSection === 0 && root.categoryCursor === index
              foreground: root.foreground
              accent: root.accent
              bordered: true
              horizontalPadding: Style.space(12)
              verticalPadding: Style.space(6)
              onClicked: {
                root.cursorSection = 0
                root.categoryCursor = index
                root.toggleCategory(index)
              }
            }
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(38)

        Text {
          width: Style.space(108)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Sort"
          color: root.cursorSection === 1 ? root.accent : root.foreground
          opacity: root.cursorSection === 1 ? 1 : 0.72
          font.pixelSize: Style.font.body
          font.weight: root.cursorSection === 1 ? Font.DemiBold : Font.Normal
          textFormat: Text.PlainText
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(118)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Repeater {
            model: root.sortingOptions

            Button {
              required property int index
              required property var modelData

              text: modelData.label
              selected: root.draftSorting === modelData.value
              hasCursor: root.cursorSection === 1 && root.sortingCursor === index
              foreground: root.foreground
              accent: root.accent
              bordered: true
              fontSize: Style.font.bodySmall
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(6)
              onClicked: {
                root.cursorSection = 1
                root.sortingCursor = index
                root.draftSorting = modelData.value
              }
            }
          }

          Button {
            text: root.draftOrder === "desc" ? "↓" : "↑"
            tooltipText: root.draftOrder === "desc" ? "Descending (D)" : "Ascending (D)"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            fontSize: Style.font.body
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(5)
            onClicked: {
              root.cursorSection = 1
              root.draftOrder = root.draftOrder === "desc" ? "asc" : "desc"
            }
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(38)

        Text {
          width: Style.space(108)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Minimum size"
          color: root.cursorSection === 2 ? root.accent : root.foreground
          opacity: root.cursorSection === 2 ? 1 : 0.72
          font.pixelSize: Style.font.body
          font.weight: root.cursorSection === 2 ? Font.DemiBold : Font.Normal
          textFormat: Text.PlainText
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(118)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Repeater {
            model: root.resolutionOptions

            Button {
              required property int index
              required property var modelData

              text: modelData.label
              selected: root.draftAtLeast === modelData.value
              hasCursor: root.cursorSection === 2 && root.resolutionCursor === index
              foreground: root.foreground
              accent: root.accent
              bordered: true
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(6)
              onClicked: {
                root.cursorSection = 2
                root.resolutionCursor = index
                root.draftAtLeast = modelData.value
              }
            }
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(52)

        Text {
          width: Style.space(108)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Palette color"
          color: root.cursorSection === 3 ? root.accent : root.foreground
          opacity: root.cursorSection === 3 ? 1 : 0.72
          font.pixelSize: Style.font.body
          font.weight: root.cursorSection === 3 ? Font.DemiBold : Font.Normal
          textFormat: Text.PlainText
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(118)
          anchors.top: parent.top
          spacing: Style.space(7)

          Repeater {
            model: root.colorOptions

            BorderSurface {
              id: swatch

              required property int index
              required property var modelData

              readonly property bool selected: root.draftColors === modelData.value
              readonly property bool hasCursor: root.cursorSection === 3 && root.colorCursor === index
              width: index === 0 ? Style.space(54) : Style.space(34)
              height: Style.space(30)
              color: index === 0 ? "transparent" : ("#" + modelData.value)
              borderSpec: Border.flat(
                hasCursor ? root.foreground : (selected ? root.accent : Util.alpha(root.foreground, 0.38)),
                hasCursor || selected ? Style.focusBorderWidth : Style.normalBorderWidth)
              radius: Style.cornerRadius

              Text {
                anchors.centerIn: parent
                text: swatch.index === 0 ? "Any" : (swatch.selected ? "✓" : "")
                color: swatch.index === 0
                  ? root.foreground
                  : (["ffcc33", "cccccc", "ffffff"].includes(swatch.modelData.value) ? "#111111" : "#ffffff")
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  root.cursorSection = 3
                  root.colorCursor = swatch.index
                }
                onClicked: {
                  root.cursorSection = 3
                  root.colorCursor = swatch.index
                  root.draftColors = swatch.modelData.value
                }
              }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(64)
            text: root.colorOptions[root.colorCursor].label
            color: root.foreground
            opacity: 0.72
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(118)
          anchors.bottom: parent.bottom
          text: "Wallhaven palette tag; selected color need not dominate"
          color: root.foreground
          opacity: 0.56
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }
      }

      Item {
        width: parent.width
        height: Style.space(72)

        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(6)
          text: "↑↓ section  ·  ←→ choice  ·  Space toggle  ·  D direction  ·  Enter apply"
          color: root.foreground
          opacity: 0.58
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }

        Row {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Style.space(8)

          Button {
            text: "Reset"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            horizontalPadding: Style.space(12)
            verticalPadding: Style.space(7)
            onClicked: root.resetDraft()
          }

          Button {
            text: "Cancel"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            horizontalPadding: Style.space(12)
            verticalPadding: Style.space(7)
            onClicked: root.cancel()
          }

          Button {
            text: "Apply filters"
            selected: true
            foreground: root.foreground
            accent: root.accent
            bordered: true
            horizontalPadding: Style.space(14)
            verticalPadding: Style.space(7)
            onClicked: root.apply()
          }
        }
      }
    }
  }
}
