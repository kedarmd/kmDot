import QtQuick
import qs
import "../components"

Item {
  id: root
  implicitHeight: 32
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

  readonly property real chevronWidth: 36
  readonly property real modulesWidth: modulesRow.implicitWidth

  width: root.open ? chevronWidth + modulesWidth + 8 : chevronWidth

  Behavior on width {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Rectangle {
    id: chevronBox
    width: root.chevronWidth
    height: 32
    radius: height / 2
    anchors.verticalCenter: parent.verticalCenter
    color: root.open ? Tokens.primaryContainer : "transparent"
    Behavior on color {
      ColorAnimation { duration: 180 }
    }

    R1Icon {
      id: chevronGlyph
      anchors.centerIn: parent
      glyph: "\uf105"
      rotation: root.open ? 0 : 180
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 24
      color: root.open ? Tokens.on_primary_container : Colors.text
    }

    StateLayer {
      anchors.fill: parent
      radius: parent.radius
      hovered: hoverArea.containsMouse
      pressed: hoverArea.pressed
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
      if (!root.stayOpen && !hoverArea.containsMouse) root.open = false
    }
  }
}
