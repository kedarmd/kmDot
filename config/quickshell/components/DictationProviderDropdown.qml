import QtQuick
import Quickshell
import qs

Item {
  id: root
  signal providerSelected(string provider)
  property real menuWidth: 112
  width: 94
  height: 28

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: Colors.surface_alt
    border.width: 1
    border.color: Colors.outline_variant
    Row {
      anchors.centerIn: parent
      spacing: 6
      Text {
        text: DictationConfig.switching ? "Switching…" : DictationConfig.provider === "hex" ? "Hex" : "Handy"
        color: Colors.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
      }
      Text {
        text: root.opened ? "▴" : "▾"
        color: Colors.text_alt
        font.pixelSize: 11
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.opened = !root.opened
    }
  }

  property bool opened: false
  // A separate Wayland popup surface escapes the panel body's Flickable clip
  // and always stacks over the Models/History row.
  PopupWindow {
    anchor.item: root
    anchor.rect.x: root.width
    anchor.rect.y: root.height
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    width: root.menuWidth
    height: 76
    visible: root.opened
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: 10
      color: Colors.surface_high
      border.width: 1
      border.color: Colors.outline_variant
      Column {
        anchors.fill: parent
        anchors.margins: 5
        Repeater {
          model: [{ id: "handy", name: "Handy" }, { id: "hex", name: "Hex" }]
          delegate: Rectangle {
            required property var modelData
            width: parent.width
            height: 32
            radius: 6
            color: DictationConfig.provider === modelData.id ? Colors.primary_container : "transparent"
            Item {
              anchors.fill: parent
              Text {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: DictationConfig.provider === modelData.id ? Colors.on_primary_container : Colors.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
              }
              Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: DictationConfig.provider === modelData.id ? "✓" : ""
                color: Colors.primary
                font.pixelSize: 13
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.opened = false
                DictationConfig.setProvider(modelData.id)
                root.providerSelected(modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
