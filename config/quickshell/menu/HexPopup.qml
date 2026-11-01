import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-hex"
  title: "Hex"
  cardWidth: 424
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant
  cardMinHeight: 536
  cardMaxHeight: 640
  tabNavigation: true
  property int tab: 0
  property var models: HexStore.models
  property var history: HexStore.history

  function switchTab(index) {
    if (root.tab === index) return
    const direction = index > root.tab ? 1 : -1
    if (index === 1) {
      historyPage.x = historyPage.width * direction
      root.tab = index
      modelPage.x = -modelPage.width * direction
      historyPage.x = 0
    } else {
      modelPage.x = modelPage.width * direction
      root.tab = index
      historyPage.x = -historyPage.width * direction
      modelPage.x = 0
    }
  }
  function navigateTab(direction) { root.switchTab(1 - root.tab) }

  function refreshItems() {
    root.tab = 0
    HexStore.refresh()
  }
  function openedChange() { if (root.opened) HexStore.refresh() }
  Connections {
    target: DictationConfig
    function onProviderChanged() {
      if (DictationConfig.provider !== "hex") root.close()
    }
  }
  Timer {
    interval: 3000
    repeat: true
    running: root.opened && root.tab === 1
    onTriggered: HexStore.refreshHistory()
  }
  function historyTitle(timestamp) {
    const date = new Date(Number(timestamp || 0))
    const now = new Date()
    const day = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    const days = Math.round((day(now) - day(date)) / 86400000)
    let hour = date.getHours()
    const suffix = hour >= 12 ? "PM" : "AM"
    hour = hour % 12 || 12
    const time = hour + ":" + String(date.getMinutes()).padStart(2, "0") + " " + suffix
    if (days === 0) return "Today, " + time
    if (days === 1) return "Yesterday, " + time
    return date.toLocaleDateString(undefined, { month: "short", day: "numeric" }) + ", " + time
  }

  Column {
    id: popupBody
    width: parent.width
    spacing: 16

    Item {
      width: parent.width
      height: 32
      DictationProviderDropdown { anchors.right: parent.right; anchors.rightMargin: 32; anchors.verticalCenter: parent.verticalCenter }
      R1Icon {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24
        glyph: "\uf130"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 20
        color: HexStore.active ? Colors.success : Colors.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 104
        anchors.verticalCenter: parent.verticalCenter
        text: HexStore.copyFeedback || "Hex"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Colors.text
        elide: Text.ElideRight
      }
    }

    Row {
      width: parent.width
      height: 34
      spacing: 8
      PillButton {
        buttonStyle: "action"; width: (parent.width - 8) / 2
        anchors.top: parent.top; anchors.bottom: parent.bottom
        text: "Models"; textSize: 13; filled: true; inactiveFillColor: Colors.surface_alt
        active: root.tab === 0; onClicked: root.switchTab(0)
      }
      PillButton {
        buttonStyle: "action"; width: (parent.width - 8) / 2
        anchors.top: parent.top; anchors.bottom: parent.bottom
        text: "History"; textSize: 13; filled: true; inactiveFillColor: Colors.surface_alt
        active: root.tab === 1; onClicked: root.switchTab(1)
      }
    }

    Text {
      visible: HexStore.errorText !== "" || DictationConfig.errorText !== ""
      width: parent.width
      text: DictationConfig.errorText || HexStore.errorText
      color: Tokens.errorText
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      wrapMode: Text.WordWrap
    }

    Item {
      id: pageClip
      width: parent.width
      height: 408
      clip: true

      Item {
        id: modelPage
        width: parent.width
        height: parent.height
        x: root.tab === 0 ? 0 : -width
        Behavior on x { NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing } }
        ListView {
          id: modelList
          anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: !HexStore.modelSelectionAvailable && root.models.length > 0 ? 34 : 0 }
          spacing: 8
          clip: true
          model: root.models
          delegate: Rectangle {
            required property var modelData
            width: modelList.width
            height: 72
            radius: 16
            color: modelData.selected ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
            R1Icon {
              anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
              width: 24; height: 24; glyph: "\uf130"
              color: modelData.selected ? Tokens.on_primary_container : Colors.text_alt
              font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20
              horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            Column {
              anchors.left: parent.left; anchors.leftMargin: 56
              anchors.right: stateGlyph.left; anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter; spacing: 4
              Text {
                width: parent.width; text: modelData.name
                color: modelData.selected ? Tokens.on_primary_container : Colors.text
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                font.weight: modelData.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
              }
              Text {
                width: parent.width; text: modelData.description
                color: modelData.selected ? Tokens.on_primary_container : Colors.text_alt
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                elide: Text.ElideRight
              }
            }
            R1Icon {
              id: stateGlyph
              anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
              visible: modelData.selected
              glyph: "\uf00c"; color: Tokens.on_primary_container
              font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14
            }
            MouseArea {
              anchors.fill: parent
              enabled: modelData.installed && !HexStore.commandBusy
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: HexStore.selectModel(modelData.id)
            }
          }
        }
        Text {
          anchors.centerIn: parent
          visible: root.models.length === 0
          width: parent.width - 24
          text: HexStore.modelNote || "No models are available"
          color: Colors.text_alt
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
          horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
        }
        Text {
          anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
          visible: !HexStore.modelSelectionAvailable && root.models.length > 0
          height: 26
          text: "To switch or install models, open Hex’s model settings."
          color: Colors.text_alt
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
          wrapMode: Text.WordWrap
        }
      }

      Item {
        id: historyPage
        width: parent.width
        height: parent.height
        x: root.tab === 1 ? 0 : width
        Behavior on x { NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing } }
        ListView {
          id: historyList
          anchors.fill: parent
          spacing: 8
          clip: true
          model: root.history
          delegate: Rectangle {
            required property var modelData
            width: historyList.width
            height: 88
            radius: 16
            color: historyMouse.containsMouse ? Tokens.surfaceContainer : Tokens.surfaceContainerHighest
            Item {
              id: historyIconCell
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              width: 32
              height: 32
              R1Icon {
                anchors.centerIn: parent
                width: 24; height: 24; glyph: "\uf130"
                color: Colors.text_alt
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
            Column {
              anchors.left: parent.left; anchors.leftMargin: 56
              anchors.right: copyGlyph.left; anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4
              Text {
                width: parent.width
                text: root.historyTitle(modelData.timestamp)
                color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Medium
                elide: Text.ElideRight
              }
              Text {
                width: parent.width; height: 34
                text: String(modelData.text || "").replace(/\s+/g, " ").trim()
                color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
              }
            }
            R1Icon {
              id: copyGlyph
              anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
              width: 20; height: 20
              glyph: HexStore.copiedHistoryId === modelData.id ? "\uf00c" : "\uf0c5"
              color: HexStore.copiedHistoryId === modelData.id ? Colors.success
                : historyMouse.containsMouse ? Colors.primary : Colors.text_alt
              font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 15
              horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            MouseArea {
              id: historyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: HexStore.copyText(modelData.text, modelData.id)
            }
          }
        }
        Text {
          anchors.centerIn: parent
          visible: root.history.length === 0
          text: "No dictations yet"
          color: Colors.text_alt
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
        }
      }
    }

  }
}
