import QtQuick
import qs
import "../components"

Column {
  id: root
  spacing: 16
  signal back()
  readonly property var adjustment: DisplayColorState.adjustment(DisplayState.selectedName)
  readonly property bool changed: adjustment.contrast !== 1 || adjustment.saturation !== 1 || adjustment.gamma !== 1

  PillButton {
    buttonStyle: "action"
    height: 34
    text: "Display"; glyph: "\uf060"; outlined: true
    textSize: 13
    onClicked: root.back()
  }
  Column {
    width: parent.width; spacing: 6
    Text {
      text: "Color adjustment"
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.text
    }
    Text {
      width: parent.width
      text: DisplayState.selectedName + " · " + (root.changed ? "Custom" : "Default")
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
    }
  }
  Text {
    width: parent.width; wrapMode: Text.WordWrap
    text: DisplayColorState.supported ? "Fine-tune how this screen looks. Changes apply as you adjust." : DisplayColorState.unavailableReason
    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
  }
  Repeater {
    model: DisplayColorState.supported ? [
      { key: "contrast", label: "Contrast", min: 0.5, max: 1.5, hint: "Softer blacks and whites ↔ stronger contrast" },
      { key: "saturation", label: "Saturation", min: 0, max: 2, hint: "Grayscale ↔ richer colors" },
      { key: "gamma", label: "Midtones", min: 0.7, max: 1.3, hint: "Darker ↔ lighter middle tones" }
    ] : []
    delegate: Column {
      required property var modelData
      width: root.width; spacing: 6
      Row {
        width: parent.width
        Text {
          width: parent.width - 64; text: modelData.label.toUpperCase()
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
        }
        Text {
          width: 64; horizontalAlignment: Text.AlignRight
          text: Math.round(root.adjustment[modelData.key] * 100) + "%"
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.primary
        }
      }
      SliderBar {
        width: parent.width; height: 40; trackHeight: 8
        trackColor: Colors.surface_alt; fillColor: Colors.primary; barRadius: 4
        thumbVisible: true; thumbSize: 16
        thumbColor: Colors.surface_high; thumbBorderColor: Colors.primary
        value: (root.adjustment[modelData.key] - modelData.min) / (modelData.max - modelData.min)
        wheelStep: 0.01 / (modelData.max - modelData.min)
        activeFocusOnTab: true
        Keys.onLeftPressed: changed(Math.max(0, value - wheelStep))
        Keys.onRightPressed: changed(Math.min(1, value + wheelStep))
        Rectangle {
          anchors.fill: parent; anchors.margins: -3
          radius: 13; color: "transparent"
          border.width: parent.activeFocus ? 2 : 0; border.color: Colors.focus
        }
        onChanged: v => DisplayColorState.setValue(modelData.key, modelData.min + v * (modelData.max - modelData.min))
      }
      Text {
        width: parent.width; wrapMode: Text.WordWrap; text: modelData.hint
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: Tokens.mutedText
      }
    }
  }
  PillButton {
    buttonStyle: "action"
    height: 34
    visible: DisplayColorState.supported
    text: "Reset to default"; glyph: "\uf0e2"; outlined: true
    textSize: 13
    enabled: root.changed
    onClicked: DisplayColorState.reset()
  }
  Text {
    width: parent.width; wrapMode: Text.WordWrap
    visible: DisplayColorState.error !== ""
    text: DisplayColorState.error
    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Tokens.errorText
  }
}
