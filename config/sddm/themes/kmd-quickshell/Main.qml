import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15 as Controls
import SddmComponents 2.0

Rectangle {
  id: root
  width: 1920
  height: 1080
  color: config.base || "#16161e"

  property color baseColor: config.base || "#16161e"
  property color surfaceColor: config.surface || "#1a1b26"
  property color fieldColor: config.surface_alt || "#292e42"
  property color textColor: config.text || "#c0caf5"
  property color secondaryColor: config.text_alt || "#a9b1d6"
  property color borderColor: config.border || "#3b4261"
  property color primaryColor: config.primary || "#7aa2f7"
  property color buttonTextColor: config.on_primary || "#1a1b26"
  property color errorColor: config.error || "#f7768e"
  property string fontName: config.fontFamily || "JetBrainsMono Nerd Font Propo"
  property string errorMessage: ""
  property bool showError: false
  property bool authenticating: false
  property bool signingOut: false
  property string selectedUser: userModel.lastUser || ""
  property int rememberedSession: sessionModel.lastIndex
  property date now: new Date()

  TextConstants { id: textConstants }

  Image {
    anchors.fill: parent
    source: Qt.resolvedUrl(config.background || "/var/tmp/kmdot-current.png")
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }
  Rectangle {
    anchors.fill: parent
    color: baseColor
    opacity: 0.68
  }
  Column {
    x: 48
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(520, parent.width * 0.42)
    spacing: 16
    Text {
      text: "WELCOME BACK"
      color: primaryColor
      font.family: root.fontName
      font.pixelSize: 12
      font.weight: Font.DemiBold
    }
    Text {
      text: Qt.formatDateTime(root.now, "hh:mm AP")
      color: textColor
      font.family: root.fontName
      font.pixelSize: Math.min(48, root.width * 0.026)
      font.weight: Font.Medium
    }
    Text {
      text: Qt.formatDateTime(root.now, "dddd, MMMM d")
      color: secondaryColor
      font.family: root.fontName
      font.pixelSize: 16
    }
    Text {
      text: "Your workspace awaits."
      color: secondaryColor
      font.family: root.fontName
      font.pixelSize: 13
      topPadding: 4
    }
  }

  Rectangle {
    id: card
    width: Math.min(424, root.width - 32)
    height: 472
    radius: 24
    color: surfaceColor
    border.color: borderColor
    border.width: 1
    x: Math.max(16, Math.min(root.width - width - 16, root.width * 0.694 - width / 2))
    anchors.verticalCenter: parent.verticalCenter
    opacity: root.signingOut ? 0 : 1
    scale: root.signingOut ? 0.98 : 1

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 240; easing.type: Easing.InCubic }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 0

      // Approved Folded badge KMD mark, matching the canonical R1 vector.
      Image {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 64; height: 64
        // Rasterize the SVG at its displayed physical size, like R1Icon.qml.
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        source: "data:image/svg+xml," + encodeURIComponent(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">' +
          '<path d="M2 5V19M2 12L7.5 5M7.5 19V5L11 10L14.5 5V19M2 12L7.5 19M14.5 5H17L19 8V16L17 19H14.5" fill="none" stroke="' + textColor + '" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' +
          '<circle cx="22" cy="18" r="1.5" fill="' + primaryColor + '"/></svg>')
      }

      Item { width: 1; height: 16 }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Sign in"
        color: textColor
        font.family: root.fontName
        font.pixelSize: 24
        font.weight: Font.DemiBold
      }
      Item { width: 1; height: 20 }
      Text {
        text: "USER"
        color: secondaryColor
        font.family: root.fontName
        font.pixelSize: 11
        font.weight: Font.DemiBold
      }
      Item { width: 1; height: 8 }
      Controls.ComboBox {
        id: userCombo
        width: parent.width
        height: 40
        model: userModel
        textRole: "name"
        currentIndex: Math.max(0, userModel.lastIndex)
        onActivated: root.selectedUser = root.userNameAt(currentIndex)
        background: Rectangle { radius: 20; color: fieldColor }
        contentItem: Text {
          leftPadding: 16
          rightPadding: 38
          text: userCombo.displayText
          color: textColor
          font.family: root.fontName
          font.pixelSize: 14
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
        indicator: Image {
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          width: 24; height: 24
          source: root.iconData("chevron-down", textColor)
        }
        popup: Controls.Popup {
          y: -height - 8
          width: userCombo.width
          height: Math.min(contentHeight, 240)
          padding: 4
          contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: userModel
            currentIndex: userCombo.highlightedIndex
            delegate: Controls.ItemDelegate {
              required property int index
              required property string name
              width: ListView.view.width
              text: name
              highlighted: index === userCombo.highlightedIndex
              onClicked: {
                userCombo.currentIndex = index
                root.selectedUser = root.userNameAt(index)
                userCombo.popup.close()
              }
              contentItem: Text {
                text: parent.text
                color: textColor
                font.family: root.fontName
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
              }
              background: Rectangle { radius: 8; color: parent.highlighted ? borderColor : "transparent" }
            }
            Controls.ScrollIndicator.vertical: Controls.ScrollIndicator { }
          }
          background: Rectangle { radius: 12; color: fieldColor; border.color: borderColor; border.width: 1 }
        }
      }
      Item { width: 1; height: 20 }
      Text {
        text: "PASSWORD"
        color: secondaryColor
        font.family: root.fontName
        font.pixelSize: 11
        font.weight: Font.DemiBold
      }
      Item { width: 1; height: 8 }
      Rectangle {
        id: credential
        width: parent.width
        height: 56
        radius: 16
        color: fieldColor
        border.color: root.showError ? errorColor : primaryColor
        border.width: 2
        clip: true
        Row {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 16
          Image {
            source: root.iconData("lock", root.showError ? errorColor : textColor)
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
          }
          Controls.TextField {
            id: password
            width: parent.width - 56
            height: 56
            focus: true
            enabled: !root.authenticating
            leftPadding: 0
            rightPadding: 0
            placeholderText: "Password"
            echoMode: TextInput.Password
            color: textColor
            placeholderTextColor: secondaryColor
            font.family: root.fontName
            font.pixelSize: 16
            // Give password bullets the same deliberate tracking as the
            // approved Penpot credential component.
            font.letterSpacing: 4
            background: Item { }
            onTextChanged: if (root.showError) root.showError = false
            Keys.onReturnPressed: root.login()
            Keys.onEnterPressed: root.login()
          }
        }
      }
      Item {
        width: parent.width; height: 48
        Text {
          x: 0; y: 4
          width: parent.width
          visible: root.showError
          text: root.errorMessage
          color: textColor
          font.family: root.fontName
          font.pixelSize: 12
        }
      }
      Rectangle {
        width: 160; height: 40; radius: 20
        anchors.horizontalCenter: parent.horizontalCenter
        color: primaryColor
        opacity: root.authenticating ? 0.55 : 1
        Text {
          anchors.centerIn: parent
          text: root.authenticating ? "Signing in…" : "Sign in"
          color: buttonTextColor
          font.family: root.fontName
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }
        MouseArea {
          anchors.fill: parent
          enabled: !root.authenticating
          cursorShape: Qt.PointingHandCursor
          onClicked: root.login()
        }
      }
      Item { width: 1; height: 12 }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Press Enter to sign in"
        color: secondaryColor
        font.family: root.fontName
        font.pixelSize: 12
      }
    }
  }

  Column {
    x: 48
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 64
    spacing: 8
    Text {
      text: "DESKTOP SESSION"
      color: secondaryColor
      font.family: root.fontName
      font.pixelSize: 11
      font.weight: Font.DemiBold
    }
    Controls.ComboBox {
      id: sessionCombo
      width: 240
      height: 40
      model: sessionModel
      textRole: "name"
      currentIndex: root.rememberedSession
      onActivated: root.rememberedSession = currentIndex
      Keys.onEscapePressed: {
        sessionCombo.popup.close()
        sessionCombo.forceActiveFocus()
      }
      background: Rectangle { radius: 20; color: fieldColor }
      contentItem: Text {
        leftPadding: 16
        rightPadding: 38
        text: sessionCombo.displayText
        color: textColor
        font.family: root.fontName
        font.pixelSize: 14
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
      indicator: Image {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24
        source: root.iconData("chevron-up", textColor)
      }
      popup: Controls.Popup {
        y: -height - 8
        width: sessionCombo.width
        height: Math.min(contentHeight, 240)
        padding: 4
        contentItem: ListView {
          clip: true
          implicitHeight: contentHeight
          model: sessionModel
          currentIndex: sessionCombo.highlightedIndex
          delegate: Controls.ItemDelegate {
            required property int index
            required property string name
            width: ListView.view.width
            text: name
            highlighted: index === sessionCombo.highlightedIndex
            onClicked: {
              sessionCombo.currentIndex = index
              root.rememberedSession = index
              sessionCombo.popup.close()
            }
            contentItem: Text {
              text: parent.text
              color: textColor
              font.family: root.fontName
              font.pixelSize: 14
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { radius: 8; color: parent.highlighted ? borderColor : "transparent" }
          }
          Controls.ScrollIndicator.vertical: Controls.ScrollIndicator { }
        }
        background: Rectangle { radius: 12; color: fieldColor; border.color: borderColor; border.width: 1 }
      }
    }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 64
    spacing: 64
    Repeater {
      model: [
        { label: "Shutdown", icon: "power", action: "powerOff" },
        { label: "Restart", icon: "refresh", action: "reboot" },
        { label: "Suspend", icon: "moon", action: "suspend" }
      ]
      delegate: Item {
        required property var modelData
        width: 64
        height: powerContent.implicitHeight
        Column {
          id: powerContent
          width: parent.width
          spacing: 8
        Image {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 24; height: 24
          source: root.iconData(modelData.icon, powerMouse.containsMouse ? primaryColor : textColor)
        }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: modelData.label
          color: secondaryColor
          font.family: root.fontName
          font.pixelSize: 12
        }
        }
        MouseArea {
          id: powerMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (modelData.action === "powerOff") sddm.powerOff()
            else if (modelData.action === "reboot") sddm.reboot()
            else sddm.suspend()
          }
        }
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.now = new Date()
  }

  function userNameAt(index) {
    return userCombo.textAt(index)
  }
  function login() {
    if (authenticating || !selectedUser || !password.text) return
    authenticating = true
    showError = false
    sddm.login(selectedUser, password.text, rememberedSession)
  }
  function iconData(name, color) {
    const paths = {
      lock: "M7 10V7a5 5 0 0 1 10 0v3 M5 10h14v11H5z M12 14v3",
      power: "M12 2v10 M7 4.8a9 9 0 1 0 10 0",
      refresh: "M20 8a8 8 0 0 0-13.7-3L4 7 M4 2v5h5 M4 16a8 8 0 0 0 13.7 3L20 17 M20 22v-5h-5",
      moon: "M20.5 15A8 8 0 0 1 9 3.5 8 8 0 1 0 20.5 15",
      chevron: "M9 5l7 7-7 7"
    }
    const key = name.startsWith("chevron") ? "chevron" : name
    const rotation = name === "chevron-down" ? 90 : name === "chevron-up" ? -90 : 0
    const path = paths[key] || ""
    return "data:image/svg+xml," + encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="' + path + '" fill="none" stroke="' + color + '" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"' + (rotation ? ' transform="rotate(' + rotation + ' 12 12)"' : "") + '/></svg>')
  }

  Connections {
    target: sddm
    function onLoginSucceeded() {
      root.authenticating = false
      root.signingOut = true
    }
    function onLoginFailed() {
      root.authenticating = false
      root.signingOut = false
      password.text = ""
      errorMessage = "Incorrect password"
      showError = true
    }
  }
  Component.onCompleted: {
    const rememberedUser = userCombo.find(selectedUser)
    if (rememberedUser >= 0) userCombo.currentIndex = rememberedUser
    if (userCombo.count > 0) selectedUser = userNameAt(userCombo.currentIndex)
    password.forceActiveFocus()
  }
}
