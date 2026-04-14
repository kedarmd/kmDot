import QtQuick 2.15
import QtQuick.Controls 2.15 as Controls
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480

  LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
  LayoutMirroring.childrenInherit: true

  property color textColor: config.text ? config.text : "#ffffff"
  property color errorColor: config.error ? config.error : "#bf616a"
  property string fontFamily: config.fontFamily ? config.fontFamily : "JetBrainsMono Nerd Font Propo"
  property string errorMessage: ""
  property bool showError: false
  property string selectedUser: userModel.lastUser ? userModel.lastUser : ""
  
  TextConstants { id: textConstants }

  // 1. Background Image (Full Screen)
  Image {
    id: bgImage
    anchors.fill: parent
    source: Qt.resolvedUrl(config.background)
    fillMode: Image.PreserveAspectCrop
  }


  // Optional: A very subtle global dark gradient at the bottom to ensure white text is readable
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 150
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.4) }
    }
  }

  // Top Right Status Bar (Placeholder for Clock)
  Text {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 20
    color: textColor
    font.family: root.fontFamily
    font.pixelSize: 13
    font.weight: Font.Medium
    text: Qt.formatDateTime(new Date(), "ddd h:mm A") 
  }

  // 2. Central Login Area (Floating)
  Column {
    id: mainColumn
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -40 // Shift up slightly like macOS
    spacing: 20

    Timer {
      id: errorTimer
      interval: 2500
      repeat: false
      onTriggered: showError = false
    }

    function userNameAt(index) {
      var entry = userModel.get(index)
      return entry.name || entry.userName || entry.login || ""
    }

    // Profile Avatar
    Rectangle {
      width: 100
      height: 100
      radius: 50
      anchors.horizontalCenter: parent.horizontalCenter
      color: Qt.rgba(1, 1, 1, 0.2)
      border.color: Qt.rgba(1, 1, 1, 0.4)
      border.width: 1
      
      Text {
        anchors.centerIn: parent
        text: (selectedUser && selectedUser.length > 0)
          ? selectedUser.charAt(0).toUpperCase()
          : "K"
        font.family: root.fontFamily
        font.pixelSize: 42
        font.weight: Font.Medium
        color: textColor
      }
    }

    // Username Dropdown
    Controls.ComboBox {
      id: userCombo
      width: 222
      height: 32
      model: userModel
      textRole: "name"
      leftPadding: 14
      rightPadding: 28
      anchors.horizontalCenter: parent.horizontalCenter
      font.family: root.fontFamily
      onCurrentTextChanged: selectedUser = userCombo.currentText

      contentItem: Text {
        text: userCombo.displayText
        color: textColor
        font.family: root.fontFamily
        font.pixelSize: 20
        font.weight: Font.Bold
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      background: Rectangle {
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.18)
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1
      }

      indicator: Text {
        text: "▾"
        color: Qt.rgba(1, 1, 1, 0.8)
        font.family: root.fontFamily
        font.pixelSize: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Password Input Row (Pill shape + Question Mark)
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10

      Controls.TextField {
        id: password
        width: 180
        height: 32
        leftPadding: 12
        rightPadding: 12
        placeholderText: "Enter Password"
        echoMode: TextInput.Password // Masks the text with dots
        color: textColor
        font.family: root.fontFamily
        font.pixelSize: 14
        onTextChanged: {
          if (showError) {
            showError = false
          }
        }
        
        // This styles the placeholder text specifically
        placeholderTextColor: Qt.rgba(1, 1, 1, 0.6) 

        // This creates the pill shape background
        background: Rectangle {
          radius: 16
          color: Qt.rgba(1, 1, 1, 0.25)
          border.color: "transparent"
        }

        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            sddm.login(selectedUser, password.text, sessionModel.lastIndex)
          }
        }
      }

      Rectangle {
        width: 32
        height: 32
        radius: 16
        color: submitMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.12)
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: ""
          color: textColor
          font.family: root.fontFamily
          font.pixelSize: 16
          font.weight: Font.Medium
          anchors.verticalCenterOffset: -1
        }

        MouseArea {
          id: submitMouseArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.login(selectedUser, password.text, sessionModel.lastIndex)
        }
      }
    }

    Text {
      visible: showError
      text: errorMessage
      color: errorColor
      font.family: root.fontFamily
      font.pixelSize: 12
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignHCenter
      anchors.horizontalCenter: parent.horizontalCenter
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.45)
    }
  }

  // 3. Bottom Power Actions
  Row {
    id: powerRow
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.bottomMargin: 60
    anchors.rightMargin: 60
    spacing: 40

    // Shut Down
    Column {
      spacing: 8
      Rectangle {
        width: 44; height: 44; radius: 22
        anchors.horizontalCenter: parent.horizontalCenter
        color: powerMouseArea1.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.6); border.width: 1.5
        
        Text { anchors.centerIn: parent; text: ""; color: textColor; font.family: root.fontFamily; font.pixelSize: 20 }
        
        MouseArea {
          id: powerMouseArea1
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.powerOff()
        }
      }
      Text { text: "Shut Down"; color: textColor; font.family: root.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }

    // Restart
    Column {
      spacing: 8
      Rectangle {
        width: 44; height: 44; radius: 22
        anchors.horizontalCenter: parent.horizontalCenter
        color: powerMouseArea2.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.6); border.width: 1.5
        
        Text { anchors.centerIn: parent; text: ""; color: textColor; font.family: root.fontFamily; font.pixelSize: 24; anchors.verticalCenterOffset: -2 }
        
        MouseArea {
          id: powerMouseArea2
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.reboot()
        }
      }
      Text { text: "Restart"; color: textColor; font.family: root.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }

    // Sleep
    Column {
      spacing: 8
      Rectangle {
        width: 44; height: 44; radius: 22
        anchors.horizontalCenter: parent.horizontalCenter
        color: powerMouseArea3.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.6); border.width: 1.5
        
        Text { anchors.centerIn: parent; text: ""; color: textColor; font.family: root.fontFamily; font.pixelSize: 20; anchors.verticalCenterOffset: -1 }
        
        MouseArea {
          id: powerMouseArea3
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.suspend()
        }
      }
      Text { text: "Sleep"; color: textColor; font.family: root.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }
  }

  Component.onCompleted: {
    password.focus = true
    if (userModel.count > 0) {
      var fallbackIndex = 0
      if (selectedUser.length > 0) {
        for (var i = 0; i < userModel.count; i++) {
          if (mainColumn.userNameAt(i) === selectedUser) {
            fallbackIndex = i
            break
          }
        }
      } else {
        selectedUser = mainColumn.userNameAt(0)
      }
      userCombo.currentIndex = fallbackIndex
      if (selectedUser.length === 0) {
        selectedUser = userCombo.currentText
      }
    }
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      errorMessage = "Incorrect password"
      showError = true
      errorTimer.restart()
    }
  }
}
