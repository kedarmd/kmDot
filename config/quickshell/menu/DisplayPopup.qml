import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-display"
  cardWidth: 340
  cardMaxHeight: 600

  // Positioning/focus/socket shell lives in PopupBase (anchorItem seam).
  // Pure view over the DisplayState singleton (issue #49): state binds to
  // singleton properties, actions delegate to it. No Processes of its own.
  property var displays: DisplayState.displays
  property var backlightMap: DisplayState.backlightMap
  property int selectedIdx: DisplayState.selectedIdx
  property string currentMode: DisplayState.currentMode
  property string externalPosition: DisplayState.externalPosition

  readonly property var selectedDisplay: DisplayState.selectedDisplay
  readonly property string selectedName: DisplayState.selectedName
  readonly property bool selectedHasBacklight: DisplayState.selectedHasBacklight
  readonly property string selectedDevice: DisplayState.selectedDevice
  readonly property real selectedScale: DisplayState.selectedScale

  readonly property int brightnessCur: DisplayState.curFor(DisplayState.selectedDevice)
  readonly property int brightnessMax: DisplayState.maxFor(DisplayState.selectedDevice)
  readonly property int brightnessPercent: DisplayState.percentFor(DisplayState.selectedDevice)

  function refreshItems() {
    DisplayState.refreshDisplays()
    DisplayState.detectBacklights()
  }

  function openedChange() {
    DisplayState.monitorsActive = root.opened
  }

        // Header
        Row {
          width: parent.width
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf26c"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            color: Colors.primary
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Display"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            color: Colors.text
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        // Display selector
        Text {
          width: parent.width
          text: "Displays"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Text {
          width: parent.width
          visible: root.displays.length === 0
          text: "No displays detected"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Repeater {
          model: root.displays

          Rectangle {
            required property var modelData
            required property int index
            width: parent.width
            height: 48
            radius: 12
            color: index === root.selectedIdx ? Tokens.primaryContainer : "transparent"

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: DisplayState.selectedIdx = index
            }

            Row {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 8

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - scaleCol.width - 8

                Text {
                  text: modelData.name + (modelData.focused ? " (active)" : "")
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 13
                  font.weight: modelData.focused ? Font.DemiBold : Font.Normal
                  color: index === root.selectedIdx ? Tokens.on_primary_container : Colors.text
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: modelData.width + "x" + modelData.height + "@" + modelData.refresh + " \u00d7 " + modelData.scale
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 11
                  color: Colors.muted
                }
              }

              Column {
                id: scaleCol
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: root.backlightMap[modelData.name] !== undefined
                  text: "\uf185"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: Colors.muted
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: root.backlightMap[modelData.name] === undefined
                  text: "\uf059"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: Colors.muted
                }
              }
            }
          }
        }

        // Brightness section
        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
          visible: root.selectedHasBacklight
        }

        Column {
          width: parent.width
          visible: root.selectedHasBacklight
          spacing: 8

          Row {
            width: parent.width
            spacing: 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.brightnessPercent + "%"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 14
              font.weight: Font.DemiBold
              color: Colors.text
            }

            Item { width: 1; height: 1 }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Brightness"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: Colors.muted
            }
          }

          SliderBar {
            width: parent.width
            value: root.brightnessMax > 0 ? root.brightnessCur / root.brightnessMax : 0
            onChanged: DisplayState.applyBrightness(root.selectedDevice, Math.round(v * root.brightnessMax))
          }
        }

        Text {
          width: parent.width
          visible: !root.selectedHasBacklight && root.selectedDisplay !== null
          text: "No backlight control for this display"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        // Scale section
        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Scale"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Row {
          width: parent.width
          spacing: 8

          Repeater {
            model: [1.0, 1.25, 1.5, 2.0]

            PillButton {
              required property var modelData
              required property int index
              width: (parent.width - 24) / 4
              height: 30
              filled: true
              active: root.selectedScale === modelData
              text: modelData + "\u00d7"
              textSize: 12
              onClicked: DisplayState.applyScale(root.selectedName, modelData)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.selectedDisplay !== null
          text: {
            if (!root.selectedDisplay) return ""
            const w = Math.round(root.selectedDisplay.width / root.selectedScale)
            const h = Math.round(root.selectedDisplay.height / root.selectedScale)
            return "Effective: " + w + "x" + h
          }
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 11
          color: Colors.muted
        }

        // Mode section
        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Display mode"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Row {
          width: parent.width
          spacing: 8

          PillButton {
            width: (parent.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "extend"
            text: "Extend"
            textSize: 12
            onClicked: DisplayState.applyMode("extend")
          }

          PillButton {
            width: (parent.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "mirror"
            text: "Mirror"
            textSize: 12
            onClicked: DisplayState.applyMode("mirror")
          }

          PillButton {
            width: (parent.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "external"
            text: "External"
            textSize: 12
            onClicked: DisplayState.applyMode("external")
          }
        }

        // External position selector (only show in extend mode)
        Column {
          width: parent.width
          visible: root.currentMode === "extend"
          spacing: 8

          Text {
            width: parent.width
            text: "External monitor position"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: Colors.muted
          }

          Row {
            width: parent.width
            spacing: 8

            PillButton {
              width: (parent.width - 8) / 2
              height: 30
              filled: true
              active: root.externalPosition === "left"
              text: "← Left"
              textSize: 12
              onClicked: {
                DisplayState.externalPosition = "left"
                DisplayState.applyMode("extend")
              }
            }

            PillButton {
              width: (parent.width - 8) / 2
              height: 30
              filled: true
              active: root.externalPosition === "right"
              text: "Right →"
              textSize: 12
              onClicked: {
                DisplayState.externalPosition = "right"
                DisplayState.applyMode("extend")
              }
            }
          }
        }
}
