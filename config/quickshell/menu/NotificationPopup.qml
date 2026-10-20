import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"
import "../components/notificationidentity.js" as Identity
import "../components/popuppos.js" as Pos

PanelWindow {
  id: root
  visible: root.presentationVisible
  color: Qt.rgba(0, 0, 0, 0)
  focusable: false

  // NOTE: Pos.primaryScreen (indexed), not .values (see PopupBase screen binding).
  screen: Pos.primaryScreen(Quickshell.screens)

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // Union of actual card rectangles: gaps and the desktop remain click-through.
  mask: Region {
    Region { item: { const count = popupModel.count; const height = popupColumn.contentHeight; return count > 0 ? popupColumn.itemAtIndex(0) : null } }
    Region { item: { const count = popupModel.count; const height = popupColumn.contentHeight; return count > 1 ? popupColumn.itemAtIndex(1) : null } }
    Region { item: { const count = popupModel.count; const height = popupColumn.contentHeight; return count > 2 ? popupColumn.itemAtIndex(2) : null } }
  }

  property bool opened: false
  readonly property bool presentationVisible: presentation.presented
  property SurfacePresentation presentation: SurfacePresentation { opened: root.opened }
  property var scope: null
  property int maxVisible: 3
  property real popupWidth: 360
  property real popupSpacing: 8
  property real popupTopMargin: 52
  property real popupRightMargin: 12

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-notifpopup.sock"
  }

  function addNotification(notif) {
    if (DnDState.dndEnabled || (root.scope && root.scope.notificationCenter && root.scope.notificationCenter.opened)) return
    root.removeNotification(notif.id)
    const isScreenshot = root.isScreenshotApp(notif)
    const duration = notif.urgency === 2 ? 0 : (isScreenshot ? 10000 : 5000)
    popupModel.insert(0, {
      notifId: notif.id,
      appName: notif.appName || "",
      appIcon: Identity.sourceIcon(notif),
      desktopEntry: notif.desktopEntry || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency,
      image: notif.image || "",
      timestamp: Date.now(),
      remaining: duration,
      duration: duration,
      paused: false,
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

  function removeNotification(id) {
    for (let i = popupModel.count - 1; i >= 0; i--) {
      if (popupModel.get(i).notifId === id) root.dismissIndex(i)
    }
  }

  function dismissIndex(idx) {
    if (idx < 0 || idx >= popupModel.count) return
    // Hiding a toast preserves its live actions in notification history.
    popupModel.remove(idx)
    if (popupModel.count === 0) root.opened = false
  }

  function dismissAll() {
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

  function actionCount(actions) {
    if (!actions) return 0
    return actions.count !== undefined ? actions.count : (actions.length || 0)
  }
  function actionAt(actions, index) {
    return actions && actions.get ? actions.get(index) : actions[index]
  }

  ListModel {
    id: popupModel
  }

  Timer {
    interval: 100
    repeat: true
    running: root.opened
    onTriggered: {
      for (let i = popupModel.count - 1; i >= 0; i--) {
        const entry = popupModel.get(i)
        if (!entry.paused && entry.duration > 0) {
          const remaining = entry.remaining - 100
          if (remaining <= 0) popupModel.remove(i)
          else popupModel.setProperty(i, "remaining", remaining)
        }
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

    ListView {
      id: popupColumn
      anchors {
        top: parent.top
        topMargin: root.popupTopMargin
        right: parent.right
        rightMargin: root.popupRightMargin
      }
      height: contentHeight
      interactive: false
      spacing: root.popupSpacing
      width: root.popupWidth
      opacity: root.opened ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: Tokens.notificationMotion; easing.type: Tokens.motionEasing }
      }

      model: popupModel

      add: Transition {
        ParallelAnimation {
          NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.notificationMotion; easing.type: Tokens.motionEasing }
        }
      }
      remove: Transition {
        ParallelAnimation {
          NumberAnimation { property: "opacity"; to: 0; duration: Tokens.notificationDismissMotion; easing.type: Tokens.motionEasing }

        }
      }
      displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: Tokens.notificationMotion; easing.type: Tokens.motionEasing }
      }

      delegate: Rectangle {
        id: card
        required property int index
        required property var modelData
        width: popupColumn.width
        height: cardBody.implicitHeight + 32
        radius: 24
        color: Colors.surface_high
        border.width: Tokens.surfaceBorderWidth
        border.color: modelData.urgency === 2 ? Colors.error : Colors.border
        enabled: root.opened && index >= 0

        HoverHandler {
          onHoveredChanged: if (card.index >= 0 && card.index < popupModel.count)
            popupModel.setProperty(card.index, "paused", hovered)
        }
        Connections {
          target: card.modelData._ref
          function onClosed() { root.removeNotification(card.modelData.notifId) }
        }

        Column {
          id: cardBody
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
            leftMargin: 52
          }
          spacing: 8

          Item {
            width: parent.width
            height: 24

            NotificationIcon {
              x: -36
              anchors.verticalCenter: parent.verticalCenter
              desktopEntry: card.modelData.desktopEntry
              appIcon: card.modelData.appIcon
              appName: card.modelData.appName
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 32
              text: (modelData.appName || "Notification") + " · now"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: Colors.text
              elide: Text.ElideRight
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: false
              text: root.relativeTime(modelData.timestamp)
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: Tokens.mutedText
            }

            R1Icon {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              glyph: "\uf00d"
              font.family: "JetBrainsMono Nerd Font Propo"
              width: 24
              height: 24
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.pixelSize: 16
              color: Tokens.mutedText

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
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.Bold
            color: modelData.urgency === 2 ? Colors.error : Colors.text
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
          }

          Text {
            id: bodyText
            width: parent.width
            visible: text !== ""
            text: modelData.body
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.text_alt
            elide: Text.ElideRight
            maximumLineCount: 3
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
          }

          PillButton {
            visible: bodyText.truncated
            text: "View details"
            onClicked: {
              if (root.scope && root.scope.notificationCenter) root.scope.notificationCenter.revealNotification(card.modelData.notifId)
            }
          }

          Flow {
            visible: modelData.hasActions || (modelData._ref && modelData._ref.hasInlineReply)
            width: parent.width
            spacing: 6

            Repeater {
              model: root.actionCount(card.modelData.actions)
                + (card.modelData._ref && card.modelData._ref.hasInlineReply ? 1 : 0)

              PillButton {
                required property int index
                height: 40
                readonly property bool replyAction: card.modelData._ref
                  && card.modelData._ref.hasInlineReply
                  && index === root.actionCount(card.modelData.actions)
                text: replyAction ? "Reply" : (root.actionAt(card.modelData.actions, index).text || "")
                textSize: 14
                horizontalPadding: 16
                filled: true
                active: true
                onClicked: {
                  if (replyAction) {
                    if (root.scope && root.scope.notificationReplyPopup)
                      root.scope.notificationReplyPopup.present(card.modelData._ref, [{
                        text: [card.modelData.summary, card.modelData.body].filter(Boolean).join("\n"),
                        when: "now"
                      }])
                  } else {
                    const action = root.actionAt(card.modelData.actions, index)
                    if (action.invoke) action.invoke()
                    root.dismissIndex(card.index)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
