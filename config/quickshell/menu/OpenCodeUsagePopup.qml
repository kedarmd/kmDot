import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-opencode-usage"
  cardWidth: 430

  property int tab: 0
  property var report: null
  property string errorText: ""

  function refreshItems() {
    if (usageProc.running) return
    usageProc.exec(["sh", "-c", "node \"$HOME/.config/kmdot/quickshell/scripts/opencode-usage.mjs\""])
  }
  function formatTokens(value) {
    if (value >= 1000000000) return (value / 1000000000).toFixed(1) + "B"
    if (value >= 1000000) return (value / 1000000).toFixed(1) + "M"
    if (value >= 1000) return (value / 1000).toFixed(1) + "K"
    return String(Math.round(value || 0))
  }
  function formatCost(value) { return "$" + Number(value || 0).toFixed(2) }
  function applyReport(text) {
    const trimmed = String(text).trim()
    if (trimmed === "") return
    try {
      const parsed = JSON.parse(trimmed)
      report = parsed.ok ? parsed : null
      errorText = parsed.ok ? "" : (parsed.error || "Could not load usage")
    } catch (e) {
      report = null
      errorText = "Could not parse usage data"
    }
  }

  Process {
    id: usageProc
    stdout: StdioCollector { onStreamFinished: root.applyReport(String(this.text)) }
  }

  Item {
    width: parent.width
    height: 34
    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: ""; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 23; color: Colors.primary }
    Text { anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: "OpenCode usage"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text }
    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.report ? "7 days" : "Loading"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; color: Colors.muted }
  }

  Row {
    width: parent.width
    spacing: 8
    PillButton { width: (parent.width - 8) / 2; text: "Daily"; active: root.tab === 0; onClicked: root.tab = 0 }
    PillButton { width: (parent.width - 8) / 2; text: "Models"; active: root.tab === 1; onClicked: root.tab = 1 }
  }

  Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; wrapMode: Text.WordWrap }
  Text { visible: !root.report && root.errorText === ""; width: parent.width; text: "Loading usage data…"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }

  Column {
    visible: !!root.report && root.tab === 0
    width: parent.width
    spacing: 8
    Repeater {
      model: root.report ? root.report.days : []
      delegate: Item {
        required property var modelData
        width: parent.width
        height: 38
        readonly property real maximum: {
          let max = 1
          for (const day of (root.report ? root.report.days : [])) max = Math.max(max, day.tokens)
          return max
        }
        Text { anchors.left: parent.left; anchors.verticalCenter: progressTrack.verticalCenter; width: 42; text: modelData.label; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
        Text { anchors.right: parent.right; anchors.top: parent.top; text: root.formatTokens(modelData.tokens) + " · " + root.formatCost(modelData.cost); color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
        Rectangle { id: progressTrack; anchors.left: parent.left; anchors.leftMargin: 48; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 22; height: 8; radius: 4; color: Tokens.surfaceContainerHighest
          Rectangle { width: parent.width * modelData.tokens / maximum; height: parent.height; radius: 4; color: Colors.primary }
        }
      }
    }
  }

  ListView {
    id: modelList
    visible: !!root.report && root.tab === 1
    width: parent.width
    height: Math.min(300, contentHeight)
    spacing: 6
    interactive: contentHeight > height
    clip: true
    model: root.report ? root.report.models : []
    delegate: Rectangle {
      required property var modelData
      width: modelList.width - 8
      height: 48
      radius: 8
      color: Tokens.surfaceContainerHighest
      Text { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 8; anchors.leftMargin: 12; anchors.rightMargin: 12; text: modelData.model; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; elide: Text.ElideMiddle }
      Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: root.formatTokens(modelData.tokens) + " tokens"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
      Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: root.formatCost(modelData.cost); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
    }
    Rectangle {
      visible: modelList.contentHeight > modelList.height
      width: 4
      radius: 2
      color: Colors.muted
      opacity: 0.6
      z: 2
      anchors.right: parent.right
      anchors.rightMargin: 1
      y: modelList.contentY * (modelList.height - height)
        / Math.max(1, modelList.contentHeight - modelList.height)
      height: Math.max(24, modelList.height * modelList.height / modelList.contentHeight)
    }
  }

  Item {
    width: parent.width
    height: 42
    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      Text { text: "7-day total"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
      Text { text: root.report ? root.formatTokens(root.report.total.tokens) + " tokens · " + root.formatCost(root.report.total.cost) : "—"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14; font.weight: Font.DemiBold }
    }
    PillButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Refresh"; glyph: ""; enabled: !usageProc.running; onClicked: root.refreshItems() }
  }
}
