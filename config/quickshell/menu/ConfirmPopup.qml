import QtQuick
import qs
import "../components"

PopupBase {
  id: root
  title: "Confirm"
  cardWidth: 424
  cardMinHeight: root.confirmHeight
  centerCard: true
  socketEnabled: false
  focusItem: keyFocus

  property string message: ""
  property bool fired: false
  property string supportingText: ""
  property string titleGlyph: "\uf071"
  property color titleGlyphColor: Tokens.warning
  property int titleSize: 18
  property int messageSize: 12
  property int messageWeight: Font.Normal
  property int buttonTextSize: 12
  property string confirmText: "Forget"
  property string cancelText: "Cancel"
  property real confirmHeight: 312
  property color confirmFill: Tokens.errorContainer
  property color confirmTextColor: Tokens.on_error_container
  property real topGap: 0
  property real actionGap: 0
  property int selectedAction: 0
  property bool showKeyboardHints: true

  signal confirmed
  signal cancelled

  function ask(popupTitle, popupMessage, options) {
    const opts = options || ({})
    root.fired = false
    root.title = popupTitle
    root.message = popupMessage
    root.supportingText = opts.supportingText || ""
    root.titleGlyph = opts.titleGlyph || "\uf071"
    root.titleGlyphColor = opts.titleGlyphColor || Tokens.warning
    root.titleSize = opts.titleSize !== undefined ? opts.titleSize : 18
    root.messageSize = opts.messageSize !== undefined ? opts.messageSize : 12
    root.messageWeight = opts.messageWeight !== undefined ? opts.messageWeight : Font.Normal
    root.buttonTextSize = opts.buttonTextSize !== undefined ? opts.buttonTextSize : 12
    root.confirmText = opts.confirmText || "Forget"
    root.cancelText = opts.cancelText || "Cancel"
    root.confirmHeight = opts.cardHeight || 312
    root.confirmFill = opts.confirmFill || Tokens.errorContainer
    root.confirmTextColor = opts.confirmTextColor || Tokens.on_error_container
    root.topGap = opts.topGap || 0
    root.actionGap = opts.actionGap || 0
    root.selectedAction = 0
    root.showKeyboardHints = opts.showKeyboardHints !== false
    root.open()
  }

  function cancelFromKeyboard() {
    if (root.fired) return
    root.fired = true
    root.cancelled()
    root.close()
  }

  function confirmFromKeyboard() {
    if (root.selectedAction === 1 && !root.fired) {
      root.fired = true
      root.confirmed()
      root.close()
    } else if (!root.fired) {
      root.cancelFromKeyboard()
    }
  }

  function openedChange() {
    // Any dismissal path must invalidate the request that opened this shared
    // confirmation surface. In particular, SystemLauncher listens for
    // `cancelled` to discard a pending power command.
    if (!root.opened && !root.fired) {
      root.fired = true
      root.cancelled()
    }
  }

  Column {
    width: parent.width; spacing: 12
    Item {
      id: keyFocus
      width: 0
      height: 0
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.cancelFromKeyboard()
          event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                   || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          root.selectedAction = 1 - root.selectedAction
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                   || event.key === Qt.Key_Space) {
          root.confirmFromKeyboard()
          event.accepted = true
        }
      }
    }
    Row { width: parent.width; spacing: 10
      R1Icon { id: titleIcon; glyph: root.titleGlyph; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: root.titleSize; color: root.titleGlyphColor; anchors.verticalCenter: parent.verticalCenter }
      Text { id: titleText; text: root.title; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.titleSize; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - titleIcon.implicitWidth - titleText.implicitWidth - 10); height: 1 }
    }
    Item { width: 1; height: root.supportingText !== "" ? root.topGap : 0; visible: root.supportingText !== "" }
    Text { width: parent.width; text: root.message; wrapMode: Text.Wrap; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.messageSize; font.weight: root.messageWeight }
    Text { width: parent.width; visible: root.supportingText !== ""; text: root.supportingText; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Item { width: 1; height: root.supportingText !== "" ? root.actionGap : 0; visible: root.supportingText !== "" }
    Row { width: parent.width; spacing: 8
      PillButton { width: (parent.width - 8) / 2; filled: true; keyboardSelected: root.selectedAction === 0; text: root.cancelText; textSize: root.buttonTextSize; onClicked: root.cancelFromKeyboard() }
      PillButton { width: (parent.width - 8) / 2; active: true; keyboardSelected: root.selectedAction === 1; fillColor: root.confirmFill; activeTextColor: root.confirmTextColor; text: root.confirmText; textSize: root.buttonTextSize; onClicked: { root.fired = true; root.confirmed(); root.close() } }
    }
    Text {
      visible: root.showKeyboardHints
      width: parent.width
      horizontalAlignment: Text.AlignRight
      text: "\u2190\u2192 choose  \u00b7  Enter activate  \u00b7  Esc cancel"
      color: Colors.muted
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
    }
  }
}
