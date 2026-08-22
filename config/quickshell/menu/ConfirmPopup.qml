import QtQuick
import qs
import "../components"

ConnectionDropdownBase {
  id: root
  title: "Confirm"
  cardWidth: 340
  escapeCloses: true
  socketEnabled: false

  property string message: ""
  property bool fired: false

  signal confirmed
  signal cancelled

  function ask(popupTitle, popupMessage) {
    root.fired = false
    root.title = popupTitle
    root.message = popupMessage
    root.open()
  }

  function openedChange() {
    if (!root.opened && !root.fired) root.cancelled()
  }

  Column {
    width: parent.width; spacing: 12
    Row { width: parent.width; spacing: 10
      Text { id: warnIcon; text: "\uf071"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 22; color: Colors.warning; anchors.verticalCenter: parent.verticalCenter }
      Text { id: titleText; text: root.title; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - warnIcon.implicitWidth - titleText.implicitWidth - 10); height: 1 }
    }
    Text { width: parent.width; text: root.message; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
    Row { width: parent.width; spacing: 8
      PillButton { width: (parent.width - 8) / 2; filled: true; text: "Cancel"; onClicked: { root.fired = true; root.cancelled(); root.close() } }
      PillButton { width: (parent.width - 8) / 2; active: true; fillColor: Tokens.errorContainer; activeTextColor: Tokens.on_error_container; text: "Forget"; onClicked: { root.fired = true; root.confirmed(); root.close() } }
    }
  }
}
