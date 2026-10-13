import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-opencode-usage"
  cardWidth: 424
  cardMinHeight: root.tab === 0 ? 576 : 528

  property int tab: 0
  property var report: null
  property string errorText: ""

  function refreshItems() {
    if (usageProc.running) return
    errorText = ""
    usageProc.exec(["sh", "-c", "node \"$HOME/.config/kmdot/quickshell/scripts/opencode-usage.mjs\""])
  }
  function formatTokens(value) {
    if (value >= 1000000000) return (value / 1000000000).toFixed(1) + "B"
    if (value >= 1000000) return (value / 1000000).toFixed(1) + "M"
    if (value >= 1000) return (value / 1000).toFixed(1) + "K"
    return String(Math.round(value || 0))
  }
  function formatCost(value) { return "$" + Number(value || 0).toFixed(2) }
  function formatModelName(value) {
    return String(value || "Unknown model")
      .replace(/[\/_-]+/g, " ")
      .replace(/\b\w/g, character => character.toUpperCase())
  }
  function formatUpdated(value) {
    if (!value) return "Updated just now"
    return "Updated " + new Date(value).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })
  }
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
    height: 48
    R1Icon { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf080"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text }
    Text { anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; text: "OpenCode usage"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
  }

  Row {
    width: parent.width
    spacing: 8
    PillButton { width: (parent.width - 8) / 2; text: "Daily"; textSize: 14; filled: true; inactiveFillColor: Colors.surface_alt; active: root.tab === 0; onClicked: root.tab = 0 }
    PillButton { width: (parent.width - 8) / 2; text: "Models"; textSize: 14; filled: true; inactiveFillColor: Colors.surface_alt; active: root.tab === 1; onClicked: root.tab = 1 }
  }

  Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Tokens.errorText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; wrapMode: Text.WordWrap }
  Text { visible: !root.report && root.errorText === ""; width: parent.width; text: "Loading usage data…"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }

  Column {
    id: dailyContent
    visible: !!root.report && root.tab === 0
    width: parent.width
    spacing: 8
    Text { width: parent.width; text: root.report ? root.formatCost(root.report.total.cost) : "—"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 48; font.weight: Font.DemiBold }
    Text { width: parent.width; text: root.report ? root.formatTokens(root.report.total.tokens) + " tokens in the last 7 days" : ""; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Text { width: parent.width; text: "Daily activity · steps"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Item {
      id: activityChart
      width: parent.width
      height: 156
      readonly property real maximum: {
        let max = 1
        for (const day of (root.report ? root.report.days : [])) max = Math.max(max, day.steps)
        return max
      }
      Row {
        anchors.fill: parent
        Repeater {
          model: root.report ? root.report.days : []
          delegate: Item {
            required property var modelData
            width: activityChart.width / Math.max(1, root.report ? root.report.days.length : 7)
            height: activityChart.height
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 24
              width: 32
              height: Math.max(3, 112 * modelData.steps / activityChart.maximum)
              radius: 8
              color: modelData.date === root.report.days[root.report.days.length - 1].date ? Colors.primary : Tokens.primaryContainer
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              text: modelData.label.slice(0, 1)
              color: Colors.text_alt
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
            }
          }
        }
      }
    }
  }

  ListView {
    id: modelList
    visible: !!root.report && root.tab === 1
    width: parent.width
    height: Math.min(300, contentHeight)
    spacing: 8
    interactive: contentHeight > height
    clip: true
    model: root.report ? root.report.models : []
    delegate: Rectangle {
      required property var modelData
      width: modelList.width
      height: 72
      radius: 16
      color: Colors.surface_alt
      R1Icon { anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; glyph: "\uf120"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
      Column { anchors.left: parent.left; anchors.leftMargin: 56; anchors.right: trailing.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
        Text { width: parent.width; text: root.formatModelName(modelData.model); color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
        Text { width: parent.width; text: root.formatTokens(modelData.tokens) + " tokens · " + root.formatCost(modelData.cost); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
      }
      R1Icon { id: trailing; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf054"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14 }
    }
    Rectangle {
      visible: modelList.contentHeight > modelList.height
      width: 4
      radius: 2
              color: Tokens.mutedText
      opacity: 0.6
      z: 2
      anchors.right: parent.right
      anchors.rightMargin: 1
      y: modelList.contentY * (modelList.height - height) / Math.max(1, modelList.contentHeight - modelList.height)
      height: Math.max(24, modelList.height * modelList.height / modelList.contentHeight)
    }
  }

  bottomContent: Item {
    width: parent.width
    height: 48
    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      Text { text: root.tab === 0 ? root.formatUpdated(root.report ? root.report.generatedAt : 0) : "7-day total"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
      Text { visible: root.tab === 1; text: root.report ? root.formatTokens(root.report.total.tokens) + " tokens · " + root.formatCost(root.report.total.cost) : "—"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold }
    }
    PillButton { visible: root.tab === 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 120; text: "Refresh"; textSize: 14; filled: true; inactiveFillColor: Colors.surface_alt; enabled: !usageProc.running; onClicked: root.refreshItems() }
  }
}
