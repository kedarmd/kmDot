import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import "../components"

WlSessionLockSurface {
  id: root
  required property var lock
  required property var shell
  color: Colors.base

  readonly property string fontName: "JetBrainsMono Nerd Font Propo"
  property date now: new Date()
  readonly property bool transitionOut: root.shell.lockAuthenticating || root.shell.lockUnlocking

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.now = new Date()
  }

  Image {
    anchors.fill: parent
    source: "file:///var/tmp/kmdot-current.png"
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }
  Rectangle {
    anchors.fill: parent
    color: Colors.base
    opacity: 0.68
  }

  R1Icon {
    x: 48; y: 48
    width: 48; height: 48
    iconName: "kmdot"
    font.pixelSize: 48
    color: Colors.text
    accentColor: Colors.primary
  }

  Column {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 48
    anchors.rightMargin: 48
    spacing: 6
    Text {
      width: 260
      horizontalAlignment: Text.AlignRight
      text: Qt.formatDateTime(root.now, "hh:mm AP")
      color: Colors.text
      font.family: root.fontName
      font.pixelSize: 22
    }
    Text {
      width: 260
      horizontalAlignment: Text.AlignRight
      text: Qt.formatDateTime(root.now, "dddd · d MMMM")
      color: Colors.text_alt
      font.family: root.fontName
      font.pixelSize: 12
    }
  }

  Rectangle {
    id: card
    width: Math.min(424, parent.width - 32)
    height: 364
    radius: 24
    color: Colors.surface
    border.color: Colors.border
    border.width: 1
    anchors.centerIn: parent
    opacity: root.transitionOut ? 0 : 1
    scale: root.transitionOut ? 0.98 : 1

    Behavior on opacity {
      NumberAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Easing.InCubic }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 0

      R1Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 24; height: 24
        iconName: "lock"
        font.pixelSize: 24
        color: Colors.text
      }
      Item { width: 1; height: 16 }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Session locked"
        color: Colors.text
        font.family: root.fontName
        font.pixelSize: 24
        font.weight: Font.DemiBold
      }
      Item { width: 1; height: 8 }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Quickshell.env("USER") + "  ·  Hyprland"
        color: Colors.text_alt
        font.family: root.fontName
        font.pixelSize: 13
        elide: Text.ElideRight
      }
      Item { width: 1; height: 26 }

      Rectangle {
        width: parent.width
        height: 56
        radius: 16
        color: Colors.surface_alt
        border.color: root.shell.lockError ? Colors.error : Colors.primary
        border.width: 2
        clip: true

        Row {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 16
          R1Icon {
            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            iconName: "lock"
            font.pixelSize: 24
            color: root.shell.lockError ? Colors.error : Colors.text
          }
          TextInput {
            id: password
            width: parent.width - 56
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            focus: root.lock.secure
            enabled: root.lock.secure && !root.shell.lockAuthenticating
            color: Colors.text
            selectionColor: Colors.primary
            selectedTextColor: Colors.on_primary
            font.family: root.fontName
            font.pixelSize: 16
            // QML's default password bullet has very little side bearing;
            // match the Penpot credential rhythm with deliberate tracking.
            font.letterSpacing: 4
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            clip: true
            onTextChanged: root.shell.lockPassword = text
            Keys.onReturnPressed: root.shell.submitLockPassword()
            Keys.onEnterPressed: root.shell.submitLockPassword()
          }
        }
      }

      Item {
        width: parent.width; height: 48
        Text {
          y: 4
          width: parent.width
          visible: root.shell.lockError
          text: "Incorrect password. Try again."
          color: Tokens.errorText
          font.family: root.fontName
          font.pixelSize: 12
        }
      }
      Rectangle {
        width: 160; height: 40; radius: 20
        anchors.horizontalCenter: parent.horizontalCenter
        color: Colors.primary
        opacity: root.shell.lockAuthenticating ? 0.55 : 1
        Text {
          anchors.centerIn: parent
          text: root.shell.lockAuthenticating ? "Unlocking…" : "Unlock"
          color: Colors.on_primary
          font.family: root.fontName
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }
        MouseArea {
          anchors.fill: parent
          enabled: root.lock.secure && !root.shell.lockAuthenticating
          cursorShape: Qt.PointingHandCursor
          onClicked: root.shell.submitLockPassword()
        }
      }
      Item { width: 1; height: 12 }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Press Enter to unlock"
        color: Colors.text_alt
        font.family: root.fontName
        font.pixelSize: 12
      }
    }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 64
    spacing: 64
    opacity: root.transitionOut ? 0 : 1

    Behavior on opacity {
      NumberAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
    }

    Repeater {
      model: [
        { label: "Shutdown", icon: "power", command: ["systemctl", "poweroff"] },
        { label: "Restart", icon: "refresh", command: ["systemctl", "reboot"] },
        { label: "Suspend", icon: "moon", command: ["systemctl", "suspend"] }
      ]
      delegate: Item {
        required property var modelData
        width: 64
        height: 56
        R1Icon {
          x: 20
          y: 0
          width: 24; height: 24
          iconName: modelData.icon
          font.pixelSize: 24
          color: actionMouse.containsMouse ? Colors.primary : Colors.text
        }
        Text {
          y: 32
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: modelData.label
          color: Colors.text_alt
          font.family: root.fontName
          font.pixelSize: 12
        }
        MouseArea {
          id: actionMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(modelData.command)
        }
      }
    }
  }

  Connections {
    target: root.shell
    function onLockPasswordChanged() {
      if (password.text !== root.shell.lockPassword)
        password.text = root.shell.lockPassword
    }
    function onLockErrorChanged() {
      if (root.shell.lockError) password.text = ""
    }
  }

  Component.onCompleted: password.forceActiveFocus()
}
