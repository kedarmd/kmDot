import QtQuick
import qs

Item {
  id: root
  implicitHeight: 30
  clip: true

  property bool open: false
  property bool stayOpen: false

  onStayOpenChanged: {
    if (root.stayOpen) {
      closeTimer.stop()
      root.open = true
    } else if (!hoverArea.containsMouse) {
      closeTimer.start()
    }
  }

  default property alias modules: modulesRow.data

  readonly property real chevronWidth: chevronGlyph.implicitWidth + 20
  readonly property real modulesWidth: modulesRow.implicitWidth

  width: root.open ? chevronWidth + modulesWidth + 8 : chevronWidth

  Behavior on width {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Item {
    id: chevronBox
    width: root.chevronWidth
    height: 30
    anchors.verticalCenter: parent.verticalCenter

    Text {
      id: chevronGlyph
      anchors.centerIn: parent
      text: root.open ? "\uf105" : "\uf104"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      color: Colors.text_alt
    }
  }

  Row {
    id: modulesRow
    anchors {
      left: chevronBox.right
      leftMargin: 8
      verticalCenter: parent.verticalCenter
    }
    spacing: 8
    opacity: root.open ? 1 : 0
    enabled: root.open
    Behavior on opacity {
      NumberAnimation { duration: 150 }
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      closeTimer.stop()
      root.open = true
    }
    onExited: closeTimer.start()
  }

  Timer {
    id: closeTimer
    interval: 150
    onTriggered: {
      if (!root.stayOpen) root.open = false
    }
  }
}