import QtQuick
import Quickshell
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-display"
  cardWidth: 424
  cardMinHeight: 728
  cardMaxHeight: 728

  readonly property var displays: DisplayState.displays
  readonly property var selectedDisplay: DisplayState.selectedDisplay
  readonly property bool selectedHasBacklight: DisplayState.selectedHasBacklight
  readonly property real selectedScale: DisplayState.selectedScale

  function refreshItems() {
    DisplayState.refreshDisplays()
    DisplayState.detectBacklights()
  }
  function openedChange() { DisplayState.monitorsActive = root.opened }

  Item {
    width: parent.width
    height: 680

    Row {
      spacing: 16
      R1Icon { glyph: "\uf26c"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "Display"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
    }

    Rectangle {
      y: 64; width: parent.width; height: 152; radius: 24; color: Colors.surface_alt
      Flickable {
        anchors { fill: parent; margins: 16 }
        clip: true
        contentWidth: monitorRow.width
        contentHeight: height
        Row {
          id: monitorRow
          height: parent.height
          spacing: 12
          Repeater {
            model: root.displays
            Rectangle {
              required property var modelData
              required property int index
              width: root.displays.length === 1 ? 344 : 152
              height: 96
              y: 12
              radius: 12
              color: index === DisplayState.selectedIdx ? Colors.primary_container : Colors.surface
              Text {
                anchors.centerIn: parent
                text: index + 1
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24
                color: index === DisplayState.selectedIdx ? Colors.on_primary_container : Colors.text_alt
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DisplayState.selectedIdx = index }
            }
          }
        }
      }
      Text {
        anchors.centerIn: parent; visible: root.displays.length === 0
        text: "No displays detected"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt
      }
    }

    Text {
      y: 240; width: parent.width - 80
      text: !root.selectedDisplay ? "No display selected" : /^(eDP|LVDS)/i.test(root.selectedDisplay.name) ? "Built-in display" : root.selectedDisplay.name
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text; elide: Text.ElideRight
    }
    Text {
      y: 242; anchors.right: parent.right
      text: root.selectedDisplay && root.selectedDisplay.focused ? "Focused" : ""
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.primary
    }
    Text {
      y: 270; width: parent.width
      text: root.selectedDisplay ? root.selectedDisplay.width + " × " + root.selectedDisplay.height + " · " + root.selectedDisplay.refresh + " Hz" : ""
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
    }

    Text { y: 320; text: "BRIGHTNESS"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    Text {
      y: 316; anchors.right: parent.right
      text: root.selectedHasBacklight ? DisplayState.percentFor(DisplayState.selectedDevice) + "%" : "Unavailable"
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: root.selectedHasBacklight ? Colors.primary : Tokens.mutedText
    }
    SliderBar {
      y: 352; width: parent.width; height: 40; enabled: root.selectedHasBacklight
      trackHeight: 40
      opacity: enabled ? 1 : 0.38
      value: DisplayState.curFor(DisplayState.selectedDevice) / DisplayState.maxFor(DisplayState.selectedDevice)
      trackColor: Colors.surface_alt; barRadius: 20
      thumbWidth: 8; thumbHeight: 32; thumbRadius: 4; thumbColor: Colors.surface
      onChanged: value => DisplayState.applyBrightness(DisplayState.selectedDevice, Math.round(value * DisplayState.maxFor(DisplayState.selectedDevice)))
    }

    Text { y: 424; text: "SCALE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    Row {
      y: 456; width: parent.width; spacing: 8
      Repeater {
        model: [1, 1.25, 1.5, 2]
        PillButton {
          required property var modelData
          width: (parent.width - 24) / 4; height: 40; filled: true
          inactiveFillColor: Colors.surface_alt; active: root.selectedScale === modelData
          enabled: !!root.selectedDisplay; text: Math.round(modelData * 100) + "%"; textSize: 14
          onClicked: DisplayState.applyScale(DisplayState.selectedName, modelData)
        }
      }
    }

    Text { y: 528; text: "DISPLAY MODE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    Row {
      y: 560; width: parent.width; spacing: 8
      Repeater {
        model: [{label: "Extend", value: "extend"}, {label: "Mirror", value: "mirror"}, {label: "External", value: "external"}]
        PillButton {
          required property var modelData
          width: (parent.width - 16) / 3; height: 40; filled: true
          inactiveFillColor: Colors.surface_alt; active: DisplayState.currentMode === modelData.value
          enabled: root.displays.length > 0 && (modelData.value === "extend" || root.displays.length > 1)
          text: modelData.label; textSize: 14
          onClicked: DisplayState.applyMode(modelData.value)
        }
      }
    }
    Item {
      y: 624; width: parent.width; height: 40; visible: DisplayState.currentMode === "extend"
      Text {
        anchors.verticalCenter: parent.verticalCenter; width: parent.width - 136
        text: "External monitor position"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt; wrapMode: Text.WordWrap
      }
      Row {
        anchors.right: parent.right; spacing: 8
        Repeater {
          model: ["left", "right"]
          PillButton {
            required property var modelData
            width: 64; height: 40; filled: true; inactiveFillColor: Colors.surface_alt
            active: DisplayState.externalPosition === modelData; enabled: root.displays.length > 1
            text: modelData === "left" ? "Left" : "Right"; textSize: 14
            onClicked: { DisplayState.externalPosition = modelData; DisplayState.applyMode("extend") }
          }
        }
      }
    }
  }
}
