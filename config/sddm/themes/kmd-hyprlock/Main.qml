import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480

  LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
  LayoutMirroring.childrenInherit: true

  property color textColor: config.text ? config.text : "#ffffff"
  
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
        text: (userModel.lastUser && userModel.lastUser.length > 0)
          ? userModel.lastUser.charAt(0).toUpperCase()
          : "K"
        font.pixelSize: 42
        font.weight: Font.Medium
        color: textColor
      }
    }

    // Username
    Text {
      text: userModel.lastUser || "Guest"
      color: textColor
      font.pixelSize: 22
      font.weight: Font.Bold
      horizontalAlignment: Text.AlignHCenter
      anchors.horizontalCenter: parent.horizontalCenter
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.5)
    }

    // Password Input Row (Pill shape + Question Mark)
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10

      TextField {
        id: password
        width: 180
        height: 32
        leftPadding: 12
        rightPadding: 12
        placeholderText: "Enter Password"
        echoMode: TextInput.Password // Masks the text with dots
        color: textColor
        font.pixelSize: 14
        
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
            sddm.login(userModel.lastUser, password.text, sessionModel.lastIndex)
          }
        }
      }
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
        
        Text { anchors.centerIn: parent; text: "⏻"; color: textColor; font.pixelSize: 20 }
        
        MouseArea {
          id: powerMouseArea1
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.powerOff()
        }
      }
      Text { text: "Shut Down"; color: textColor; font.pixelSize: 12; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }

    // Restart
    Column {
      spacing: 8
      Rectangle {
        width: 44; height: 44; radius: 22
        anchors.horizontalCenter: parent.horizontalCenter
        color: powerMouseArea2.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.6); border.width: 1.5
        
        Text { anchors.centerIn: parent; text: "⟳"; color: textColor; font.pixelSize: 24; anchors.verticalCenterOffset: -2 }
        
        MouseArea {
          id: powerMouseArea2
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.reboot()
        }
      }
      Text { text: "Restart"; color: textColor; font.pixelSize: 12; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }

    // Sleep
    Column {
      spacing: 8
      Rectangle {
        width: 44; height: 44; radius: 22
        anchors.horizontalCenter: parent.horizontalCenter
        color: powerMouseArea3.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.6); border.width: 1.5
        
        Text { anchors.centerIn: parent; text: "☾"; color: textColor; font.pixelSize: 20; anchors.verticalCenterOffset: -1 }
        
        MouseArea {
          id: powerMouseArea3
          anchors.fill: parent
          hoverEnabled: true
          onClicked: sddm.suspend()
        }
      }
      Text { text: "Sleep"; color: textColor; font.pixelSize: 12; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }
  }

  Component.onCompleted: password.focus = true
}
