import QtQuick
import Quickshell
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-notification-reply"
  animatePresentation: !Tokens.reducedMotion
  title: "Messages"
  cardWidth: 424
  cardMinHeight: 456
  cardMaxHeight: Math.min(488, root.height - 80)
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant
  socketEnabled: false
  property var notification: null
  property var messages: []
  focusItem: replyInput

  function present(notif, thread) {
    if (!notif || !notif.hasInlineReply) return
    root.notification = notif
    root.messages = thread || []
    replyInput.text = ""
    root.open()
    messageList.positionViewAtEnd()
  }
  function sendReply() {
    const value = replyInput.text.trim()
    if (!value || !root.notification || !root.notification.hasInlineReply) return
    root.notification.sendInlineReply(value)
    root.close()
  }

  Item {
    width: parent.width; height: 352
    Row {
      spacing: 16
      R1Icon { glyph: "\uf0f3"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "Messages"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.text }
    }
    Text {
      y: 64; width: parent.width
      text: root.notification ? root.notification.appName : "Conversation"
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text; elide: Text.ElideRight
    }
    Text {
      y: 102; width: parent.width; height: 40
      text: root.messages.length + (root.messages.length === 1 ? " message" : " messages")
        + " · Most recent " + (root.messages.length ? root.messages[root.messages.length - 1].when : "now")
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt; wrapMode: Text.WordWrap
    }
    Rectangle {
      y: 160; width: parent.width; height: 88; radius: 16; color: Colors.surface_alt
      ListView {
        id: messageList
        anchors { fill: parent; margins: 16 }
        clip: true; spacing: 12; model: root.messages
        delegate: Text {
          required property var modelData
          width: messageList.width; text: modelData.text
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text; wrapMode: Text.Wrap
        }
      }
    }
    Rectangle {
      y: 272; width: parent.width; height: 80; radius: 12; color: Colors.surface_alt
      TextEdit {
            selectionColor: Colors.text_selection
            selectedTextColor: Colors.on_text_selection
        cursorDelegate: Rectangle { width: 2; height: replyInput.cursorRectangle.height; color: Colors.cursor }
              id: replyInput
        anchors { fill: parent; margins: 16 }
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text
        clip: true; wrapMode: TextEdit.Wrap; selectByMouse: true
        Text {
          anchors.fill: parent; visible: replyInput.text.length === 0
          text: root.notification && root.notification.inlineReplyPlaceholder ? root.notification.inlineReplyPlaceholder : "Write a reply…"
          font: replyInput.font; color: Tokens.mutedText; wrapMode: Text.WordWrap
        }
        Keys.onReturnPressed: event => {
          if (event.modifiers & Qt.ControlModifier) root.sendReply()
          else replyInput.insert(replyInput.cursorPosition, "\n")
          event.accepted = true
        }
      }
    }
  }
  bottomContent: Row {
    width: parent.width; height: 34; spacing: 8
    PillButton {
      buttonStyle: "action"
      width: (parent.width - 8) / 2; anchors.top: parent.top; anchors.bottom: parent.bottom
      text: "Cancel"; textSize: 13
      filled: true; inactiveFillColor: Colors.surface_alt
      onClicked: root.close()
    }
    PillButton {
      buttonStyle: "action"
      width: (parent.width - 8) / 2; anchors.top: parent.top; anchors.bottom: parent.bottom
      text: "Send reply"; textSize: 13
      active: true; fillColor: Colors.button; activeTextColor: Colors.on_button
      enabled: replyInput.text.trim().length > 0 && !!root.notification && root.notification.hasInlineReply
      onClicked: root.sendReply()
    }
  }
}
