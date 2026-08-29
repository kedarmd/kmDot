import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"
import "../components/popuppos.js" as Pos

PanelWindow {
  id: root
  visible: root.opened
  color: Qt.rgba(0, 0, 0, 0)
  focusable: false

  BackgroundEffect.blurRegion: Region {
    item: root.contentItem

    Region {
      intersection: Intersection.Subtract
      x: 0
      y: 0
      width: root.width
      height: 42
    }
  }
  screen: Quickshell.screens.values.length > 0 ? Quickshell.screens.values[0] : null

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  property bool opened: false
  property var scope: null
  property int maxVisible: 5
  property real popupWidth: 360
  property real popupSpacing: 8
  property real popupTopMargin: 52
  property real popupRightMargin: 12

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-notifpopup.sock"
  }

  function addNotification(notif) {
    if (DnDState.dndEnabled) return
    const isScreenshot = root.isScreenshotApp(notif)
    const duration = notif.urgency === 2 ? 0 : (isScreenshot ? 10000 : 5000)
    popupModel.insert(0, {
      notifId: notif.id,
      appName: notif.appName || "",
      appIcon: notif.appIcon || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency,
      image: notif.image || "",
      timestamp: Date.now(),
      duration: duration,
      hasActions: notif.actions && notif.actions.length > 0,
      actions: notif.actions || [],
      _ref: notif
    })
    while (popupModel.count > root.maxVisible)
      popupModel.remove(popupModel.count - 1)
    root.opened = true
  }

  function isScreenshotApp(notif) {
    const name = (notif.appName || "").toLowerCase()
    const entry = (notif.desktopEntry || "").toLowerCase()
    return name.indexOf("grim") >= 0 || name.indexOf("hyprshot") >= 0
      || name.indexOf("flameshot") >= 0 || name.indexOf("screenshot") >= 0
      || entry.indexOf("grim") >= 0 || entry.indexOf("hyprshot") >= 0
      || entry.indexOf("flameshot") >= 0
  }

  function dismissIndex(idx) {
    const entry = popupModel.get(idx)
    if (entry && entry._ref) entry._ref.dismiss()
    popupModel.remove(idx)
    if (popupModel.count === 0) root.opened = false
  }

  function dismissAll() {
    for (let i = popupModel.count - 1; i >= 0; i--) {
      const entry = popupModel.get(i)
      if (entry && entry._ref) entry._ref.dismiss()
    }
    popupModel.clear()
    root.opened = false
  }

  function relativeTime(ts) {
    const diff = Math.floor((Date.now() - ts) / 1000)
    if (diff < 60) return "now"
    if (diff < 3600) return Math.floor(diff / 60) + "m"
    if (diff < 86400) return Math.floor(diff / 3600) + "h"
    return Math.floor(diff / 86400) + "d"
  }

  ListModel {
    id: popupModel
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened
    onTriggered: {
      const now = Date.now()
      for (let i = popupModel.count - 1; i >= 0; i--) {
        const entry = popupModel.get(i)
        if (entry.duration > 0 && (now - entry.timestamp) >= entry.duration)
          popupModel.remove(i)
      }
      if (popupModel.count === 0) root.opened = false
    }
  }

  SocketServer {
    active: true
    path: root.sockPath
    handler: Socket {
      onConnectedChanged: {
        if (connected) root.toggle()
      }
    }
  }

  function open() {
    root.opened = true
  }

  function close() {
    root.dismissAll()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Item {
    anchors.fill: parent

    Column {
      id: popupColumn
      anchors {
        top: parent.top
        topMargin: root.popupTopMargin
        right: parent.right
        rightMargin: root.popupRightMargin
      }
      spacing: root.popupSpacing
      width: root.popupWidth

      Repeater {
        model: popupModel

        Rectangle {
          id: card
          required property int index
          required property var modelData
          width: popupColumn.width
          height: cardBody.implicitHeight + 24
          radius: 16
          color: modelData.urgency === 2 ? Tokens.errorContainer : Tokens.surfaceContainerLow
          border.width: 1
          border.color: modelData.urgency === 2 ? Colors.error : Colors.border
          opacity: 1

          Behavior on opacity {
            NumberAnimation { duration: 200 }
          }

          Component.onCompleted: opacity = 1

          Column {
            id: cardBody
            anchors {
              top: parent.top
              left: parent.left
              right: parent.right
              margins: 12
            }
            spacing: 6

            Row {
              width: parent.width
              spacing: 8

              Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                  const ic = modelData.appIcon || ""
                  return ic !== "" && !ic.startsWith("\\u")
                }
                source: {
                  const ic = modelData.appIcon || ""
                  if (ic === "") return ""
                  if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic
                  return Quickshell.iconPath(ic)
                }
                width: 18
                height: 18
                sourceSize: Qt.size(18, 18)
                smooth: true
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                  const ic = modelData.appIcon || ""
                  return ic === "" || ic.startsWith("\\u")
                }
                text: "\uf0f3"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 14
                color: Colors.text_alt
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80
                text: modelData.appName || "Notification"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Colors.text
                elide: Text.ElideRight
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.relativeTime(modelData.timestamp)
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                color: Colors.muted
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00d"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Colors.muted

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.dismissIndex(card.index)
                }
              }
            }

            Text {
              width: parent.width
              visible: text !== ""
              text: modelData.summary
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 13
              font.weight: Font.Bold
              color: modelData.urgency === 2 ? Colors.error : Colors.text
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.Wrap
            }

            Text {
              width: parent.width
              visible: text !== ""
              text: modelData.body
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: Colors.text_alt
              elide: Text.ElideRight
              maximumLineCount: 3
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
            }

            Row {
              visible: modelData.hasActions
              width: parent.width
              spacing: 6

              Repeater {
                model: modelData.hasActions ? modelData.actions : []

                PillButton {
                  required property var modelData
                  height: 24
                  text: modelData.text || ""
                  textSize: 10
                  horizontalPadding: 8
                  onClicked: {
                    if (modelData.invoke) modelData.invoke()
                    root.dismissIndex(card.index)
                  }
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
              if (card.modelData.hasActions && card.modelData.actions.length > 0)
                card.modelData.actions[0].invoke()
              root.dismissIndex(card.index)
            }
          }
        }
      }
    }
  }
}
