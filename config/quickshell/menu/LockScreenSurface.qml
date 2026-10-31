import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Shapes
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
  // Keep the secure surface fully present while PAM is checking credentials.
  // Only a confirmed success starts the desktop handoff animation.
  readonly property bool transitionOut: root.shell.lockUnlocking
  // Keep the lockscreen itself steady through unlock. The shell-wide cover
  // performs the only unlock animation so the card and backdrop cannot drift
  // out of sync with each other.
  readonly property real contentOpacity: root.lock.secure ? 1 : 0
  readonly property int transitionDuration: root.shell.lockTransitionDuration

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
    opacity: root.contentOpacity
    Behavior on opacity {
      NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutCubic }
    }
  }
  Rectangle {
    anchors.fill: parent
    color: Colors.scrim
    opacity: root.contentOpacity
    Behavior on opacity {
      NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutCubic }
    }
  }
  Column {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 48
    anchors.rightMargin: 48
    spacing: 6
    opacity: root.contentOpacity
    Behavior on opacity {
      NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutCubic }
    }
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

  // A soft halo and sharp highlight sweep around the outside of the card.
  // Both colors stay bound to the active theme; the card itself stays still.
  Shape {
    id: cardHalo
    width: card.width + 16
    height: card.height + 16
    anchors.centerIn: card
    opacity: root.contentOpacity
    ShapePath {
      fillRule: ShapePath.OddEvenFill
      fillColor: "white"
      strokeColor: "transparent"
      strokeWidth: 0
      fillGradient: ConicalGradient {
        id: cardHaloGradient
        angle: cardShineGradient.angle
        centerX: cardHalo.width / 2
        centerY: cardHalo.height / 2
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.39; color: "transparent" }
        GradientStop { position: 0.46; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08) }
        GradientStop { position: 0.5; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2) }
        GradientStop { position: 0.54; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08) }
        GradientStop { position: 0.61; color: "transparent" }
        GradientStop { position: 1.0; color: "transparent" }
      }
      PathRectangle { x: 0; y: 0; width: cardHalo.width; height: cardHalo.height; radius: card.radius + 8 }
      PathRectangle { x: 8; y: 8; width: cardHalo.width - 16; height: cardHalo.height - 16; radius: card.radius }
    }
  }

  Shape {
    id: cardShine
    width: card.width + 6
    height: card.height + 6
    anchors.centerIn: card
    opacity: root.contentOpacity
    ShapePath {
      fillRule: ShapePath.OddEvenFill
      fillColor: "white"
      strokeColor: "transparent"
      strokeWidth: 0
      fillGradient: ConicalGradient {
        id: cardShineGradient
        centerX: cardShine.width / 2
        centerY: cardShine.height / 2
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.475; color: "transparent" }
        GradientStop { position: 0.493; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.55) }
        GradientStop { position: 0.5; color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.92) }
        GradientStop { position: 0.507; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.55) }
        GradientStop { position: 0.525; color: "transparent" }
        GradientStop { position: 1.0; color: "transparent" }
      }
      PathRectangle { x: 0; y: 0; width: cardShine.width; height: cardShine.height; radius: card.radius + 3 }
      PathRectangle { x: 3; y: 3; width: cardShine.width - 6; height: cardShine.height - 6; radius: card.radius }
    }
  }

  NumberAnimation {
    target: cardShineGradient
    property: "angle"
    from: 360
    to: 0
    duration: 12000
    loops: Animation.Infinite
    easing.type: Easing.Linear
    running: root.lock.secure && !root.transitionOut && !Tokens.reducedMotion
  }

  Rectangle {
    id: card
    width: Math.min(424, parent.width - 32)
    height: 404
    radius: 24
    color: Colors.surface_high
    border.color: Colors.border
    border.width: Tokens.surfaceBorderWidth
    anchors.centerIn: parent
    opacity: root.contentOpacity


    Behavior on opacity {
      NumberAnimation { duration: root.transitionDuration; easing.type: Easing.InOutCubic }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 0

      KmdotMark {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 64; height: 64
        primary: Colors.text
        accent: Colors.primary
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
        border.color: root.shell.lockError ? Colors.error : Colors.focus
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
            verticalAlignment: Text.AlignVCenter
            color: root.shell.lockError ? Colors.error : Colors.text
          }
          Controls.TextField {
            selectionColor: Colors.text_selection
            selectedTextColor: Colors.on_text_selection
            cursorDelegate: Rectangle { width: 2; height: password.cursorRectangle.height; color: Colors.cursor }
            id: password
            width: parent.width - 56
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            focus: root.lock.secure
            enabled: root.lock.secure && !root.shell.lockAuthenticating && !root.transitionOut
            color: Colors.text
            placeholderText: "Password"
            placeholderTextColor: Colors.text_alt
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            background: Item { }

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
        color: Colors.button
        opacity: root.shell.lockAuthenticating ? 0.55 : 1
        Text {
          anchors.centerIn: parent
          text: root.shell.lockAuthenticating || root.transitionOut ? "Unlocking…" : "Unlock"
          color: Colors.on_button
          font.family: root.fontName
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }
        MouseArea {
          anchors.fill: parent
          enabled: root.lock.secure && !root.shell.lockAuthenticating && !root.transitionOut
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
    opacity: root.contentOpacity

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
          enabled: !root.transitionOut
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
