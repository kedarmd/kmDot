import QtQuick
import qs
import "../components"
import "../launcher/plugin/ui" as Cast
import "../launcher/plugin/compat" as CastCompat

PopupBase {
  id: root
  title: "Confirm"
  cardWidth: 424
  cardMinHeight: 220
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant
  closeButtonVisible: false
  dimBackground: true
  centerCard: true
  socketEnabled: false
  focusItem: keyFocus

  property string message: ""
  property bool fired: false
  property string supportingText: ""
  property string titleGlyph: "\uf071"
  property color titleGlyphColor: Tokens.warning
  readonly property string uiFont: CastCompat.Style.font.menuFamily
  property string confirmText: "Forget"
  property string cancelText: "Cancel"
  property color confirmFill: Tokens.errorContainer
  property color confirmTextColor: Tokens.on_error_container
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
    root.confirmText = opts.confirmText || "Forget"
    root.cancelText = opts.cancelText || "Cancel"
    root.confirmFill = opts.confirmFill || Tokens.errorContainer
    root.confirmTextColor = opts.confirmTextColor || Tokens.on_error_container
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
    // confirmation surface so its caller discards the pending operation.
    if (!root.opened && !root.fired) {
      root.fired = true
      root.cancelled()
    }
  }

  Column {
    width: parent.width
    spacing: 16

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

    Item {
      objectName: "confirmationHeading"
      width: parent.width
      height: Math.max(26, titleText.implicitHeight)
      R1Icon {
        id: titleIcon
        width: 26
        height: 26
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        glyph: root.titleGlyph
        font.pixelSize: 20
        color: root.titleGlyphColor
      }
      Text {
        id: titleText
        anchors { left: titleIcon.right; right: escapeButton.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 12 }
        text: root.title
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: root.uiFont
        font.pixelSize: 17
        font.weight: Font.Medium
        color: Colors.text
      }
      Item {
        id: escapeButton
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: escapeHint.implicitWidth
        height: escapeHint.implicitHeight
        Cast.KeyHint { id: escapeHint; keys: "Esc"; color: Colors.text; fontFamily: root.uiFont }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelFromKeyboard() }
      }
    }

    Text {
      objectName: "confirmationMessage"
      width: parent.width
      text: root.message
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: Colors.text_alt
      font.family: root.uiFont
      font.pixelSize: 14
    }
    Text {
      objectName: "confirmationSupportingText"
      width: parent.width
      visible: root.supportingText !== ""
      text: root.supportingText
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: Colors.text_alt
      font.family: root.uiFont
      font.pixelSize: 14
    }
  }

  bottomContent: Item {
    width: parent.width
    height: 51 + (root.showKeyboardHints ? 30 : 0)
    Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Colors.divider }
    Row {
      id: actionButtons
      objectName: "confirmationActions"
      anchors { top: parent.top; right: parent.right; topMargin: 17 }
      spacing: 8
      PillButton {
        objectName: "confirmationCancel"
        width: Math.max(100, implicitWidth)
        height: 34
        horizontalPadding: 16
        fontFamily: root.uiFont
        textSize: 14
        filled: true
        keyboardSelected: root.selectedAction === 0
        text: root.cancelText
        onClicked: root.cancelFromKeyboard()
      }
      PillButton {
        objectName: "confirmationAccept"
        width: Math.max(100, implicitWidth)
        height: 34
        horizontalPadding: 16
        fontFamily: root.uiFont
        textSize: 14
        active: true
        keyboardSelected: root.selectedAction === 1
        fillColor: root.confirmFill
        activeTextColor: root.confirmTextColor
        text: root.confirmText
        onClicked: { root.selectedAction = 1; root.confirmFromKeyboard() }
      }
    }
    Row {
      visible: root.showKeyboardHints
      anchors { top: actionButtons.bottom; right: parent.right; topMargin: 12 }
      spacing: 6
      Text { anchors.verticalCenter: parent.verticalCenter; text: "Choose"; color: Colors.text_alt; font.family: root.uiFont; font.pixelSize: 11 }
      Cast.KeyHint { anchors.verticalCenter: parent.verticalCenter; keys: "← →"; color: Colors.text; fontFamily: root.uiFont }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "Activate"; color: Colors.text_alt; font.family: root.uiFont; font.pixelSize: 11 }
      Cast.KeyHint { anchors.verticalCenter: parent.verticalCenter; keys: "↵"; color: Colors.text; fontFamily: root.uiFont }
    }
  }
}
