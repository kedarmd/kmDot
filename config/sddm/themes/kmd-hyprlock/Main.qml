import QtQuick 2.0
import SddmComponents 2.0
import Qt5Compat.GraphicalEffects 1.0

Rectangle {
  id: root
  width: 640
  height: 480

  LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
  LayoutMirroring.childrenInherit: true

  property color surfaceColor: config.surface ? config.surface : "#1f2335"
  property color surfaceAltColor: config.surfaceAlt ? config.surfaceAlt : "#292e42"
  property color borderColor: config.border ? config.border : "#3b4261"
  property color textColor: config.text ? config.text : "#c0caf5"
  property color mutedColor: config.muted ? config.muted : "#a9b1d6"
  property color accentColor: config.accent ? config.accent : "#88c0d0"
  property color accentAltColor: config.accentAlt ? config.accentAlt : "#81a1c1"
  property color errorColor: config.error ? config.error : "#bf616a"

  TextConstants { id: textConstants }

  Item {
    id: backgroundLayer
    anchors.fill: parent

    Rectangle {
      anchors.fill: parent
      color: "#0b111a"

      Image {
        id: bgImage
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background)
        fillMode: Image.PreserveAspectCrop

        onStatusChanged: {
          if (status === Image.Error) {
            visible = false
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "#0b111a"
        opacity: 0.25
      }
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#0b111a" }
        GradientStop { position: 0.55; color: "transparent" }
        GradientStop { position: 1.0; color: "#0b111a" }
      }
      opacity: 0.35
    }
  }

  Connections {
    target: sddm

    function onLoginFailed() {
      password.text = ""
      statusText.color = errorColor
      statusText.text = textConstants.loginFailed
    }

    function onLoginSucceeded() {
      statusText.color = accentColor
      statusText.text = textConstants.loginSucceeded
    }

    function onInformationMessage(message) {
      statusText.color = errorColor
      statusText.text = message
    }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: 380
    height: mainColumn.implicitHeight + 40
    radius: 14
    clip: true
    color: "transparent"
    border.width: 2
    border.color: "#c0caf5"

    ShaderEffectSource {
      id: blurSource
      anchors.fill: parent
      sourceItem: backgroundLayer
      sourceRect: Qt.rect(card.x, card.y, card.width, card.height)
      live: true
      hideSource: false
      visible: false
    }

    FastBlur {
      anchors.fill: parent
      source: blurSource
      radius: 22
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.28)
    }

    Column {
      id: mainColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: 20
      anchors.rightMargin: 20
      anchors.topMargin: 20
      spacing: 8

      Text {
        text: "Welcome"
        color: textColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        width: parent.width
      }

      Text {
        id: statusText
        text: textConstants.prompt
        color: mutedColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        width: parent.width
      }

      Column {
        width: parent.width
        spacing: 6

        Text {
          text: textConstants.userName
          color: "#e6edf6"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
        }

        TextBox {
          id: username
          width: parent.width
          height: 34
          text: userModel.lastUser
          color: Qt.rgba(surfaceAltColor.r, surfaceAltColor.g, surfaceAltColor.b, 0.65)
          textColor: "#e6edf6"
          borderColor: borderColor
          focusColor: accentColor
          hoverColor: accentAltColor
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          KeyNavigation.tab: password
        }
      }

      Column {
        width: parent.width
        spacing: 6

        Text {
          text: textConstants.password
          color: "#e6edf6"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
        }

        PasswordBox {
          id: password
          width: parent.width
          height: 34
          color: Qt.rgba(surfaceAltColor.r, surfaceAltColor.g, surfaceAltColor.b, 0.65)
          textColor: "#e6edf6"
          borderColor: borderColor
          focusColor: accentColor
          hoverColor: accentAltColor
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          KeyNavigation.tab: loginButton

          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              loginButton.clicked()
              event.accepted = true
            }
          }
        }
      }

      Row {
        spacing: 10
        width: parent.width
        height: 38

        Button {
          id: loginButton
          width: parent.width
          height: 38
          text: textConstants.login
          color: accentColor
          textColor: "#0b111a"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14

          onClicked: {
            sddm.login(username.text, password.text, sessionModel.lastIndex)
          }
        }
      }

      Row {
        spacing: 10
        width: parent.width
        height: 34

        Button {
          width: (parent.width - spacing) / 2
          height: 34
          text: textConstants.reboot
          color: Qt.rgba(surfaceAltColor.r, surfaceAltColor.g, surfaceAltColor.b, 0.8)
          textColor: textColor
          borderColor:  "#e6edf6"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          onClicked: sddm.reboot()
        }

        Button {
          width: (parent.width - spacing) / 2
          height: 34
          text: textConstants.shutdown
          color: Qt.rgba(surfaceAltColor.r, surfaceAltColor.g, surfaceAltColor.b, 0.8)
          textColor: textColor
          borderColor:  "#e6edf6"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          onClicked: sddm.powerOff()
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: "transparent"
      border.width: 2
      border.color: "#c0caf5"
    }
  }

  Component.onCompleted: {
    if (username.text === "") {
      username.focus = true
    } else {
      password.focus = true
    }
  }
}
