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
  tabNavigation: true

  property int tab: 0
  property int tabDirection: 1
  property var report: null
  property string errorText: ""
  property var agents: []
  property string selectedAgent: "opencode"
  property bool loading: false
  property bool agentMenuOpen: false
  property string requestAgent: ""
  property var hoveredDay: null
  property real hoveredX: 0
  function switchTab(index) {
    if (root.tab === index) return
    const direction = index > root.tab ? 1 : -1
    root.tabDirection = direction
    if (index === 1) {
      modelPage.x = modelPage.width * direction
      root.tab = index
      dailyContent.x = -dailyContent.width * direction
      modelPage.x = 0
    } else {
      dailyContent.x = dailyContent.width * direction
      root.tab = index
      modelPage.x = -modelPage.width * direction
      dailyContent.x = 0
    }
  }
  function navigateTab(direction) {
    root.switchTab((root.tab + direction + 2) % 2)
  }

  function refreshItems() {
    report = null
    errorText = ""
    loading = true
    if (usageProc.running) return
    requestAgent = selectedAgent
    usageProc.exec(["sh", "-c", "node \"$HOME/.config/kmdot/quickshell/scripts/agent-usage.mjs\" \"" + root.requestAgent + "\""])
  }
  function selectAgent(id) {
    agentMenuOpen = false
    if (id === selectedAgent) return
    selectedAgent = id
    refreshItems()
  }
  function loadAgents(text) {
    try {
      const parsed = JSON.parse(String(text).trim())
      agents = parsed.agents || []
      if (!agents.some(agent => agent.id === selectedAgent) && agents.length) selectedAgent = agents[0].id
      refreshItems()
    } catch (e) { agents = [] }
  }
  function formatTokens(value) {
    const compact = amount => amount >= 10 ? String(Math.round(amount)) : amount.toFixed(1).replace(/\.0$/, "")
    if (value >= 1000000000) return compact(value / 1000000000) + "B"
    if (value >= 1000000) return compact(value / 1000000) + "M"
    if (value >= 1000) return compact(value / 1000) + "K"
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
    if (requestAgent !== selectedAgent) { refreshItems(); return }
    const trimmed = String(text).trim()
    loading = false
    if (trimmed === "") { errorText = "Could not read usage data"; return }
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
    onExited: if (root.requestAgent !== root.selectedAgent) root.refreshItems()
  }
  Process { id: agentsProc; command: ["sh", "-c", "node \"$HOME/.config/kmdot/quickshell/scripts/agent-usage.mjs\" --list"]; running: root.opened; stdout: StdioCollector { onStreamFinished: root.loadAgents(String(this.text)) } }

  Item {
    width: parent.width
    height: 48
    R1Icon { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf121"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text }
    Text { anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; text: root.agentName(root.selectedAgent) + " usage"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
  }

  function agentName(id) { const found = agents.find(agent => agent.id === id); return found ? found.name : "AI agent" }

  Item {
    id: agentSelector
    width: parent.width
    height: 40
    z: root.agentMenuOpen ? 10 : 0
    Rectangle {
      id: agentSelectorButton
      width: parent.width
      height: 40
      radius: 20
      color: Colors.surface_alt
      R1Icon { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf121"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14 }
      Text { anchors.left: parent.left; anchors.leftMargin: 38; anchors.verticalCenter: parent.verticalCenter; text: root.agentName(root.selectedAgent); color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
      R1Icon { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; glyph: root.agentMenuOpen ? "\uf078" : "\uf078"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14; rotation: root.agentMenuOpen ? 180 : 0; Behavior on rotation { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } } }
      MouseArea { anchors.fill: parent; onClicked: root.agentMenuOpen = !root.agentMenuOpen }
    }
    Rectangle {
      id: agentMenu
      visible: root.agentMenuOpen || opacity > 0
      width: parent.width
      height: menuContent.implicitHeight + 12
      y: 46
      radius: 16
      color: Colors.surface_high
      border.width: Tokens.surfaceBorderWidth
      border.color: Colors.border
      clip: true
      opacity: root.agentMenuOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }
      Column {
        id: menuContent
        anchors.fill: parent
        anchors.margins: 6
        Repeater {
          model: root.agents
          delegate: Item {
            required property var modelData
            required property int index
            width: menuContent.width
            height: 38
            Rectangle {
              anchors.fill: parent
              radius: 10
              color: root.selectedAgent === modelData.id ? Colors.surface_alt : "transparent"
            }
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: root.selectedAgent === modelData.id ? Colors.text : Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
            R1Icon { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; visible: root.selectedAgent === modelData.id; glyph: "\uf00c"; color: Colors.primary; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13 }
            MouseArea { anchors.fill: parent; onClicked: root.selectAgent(modelData.id) }
            Rectangle { visible: index < root.agents.length - 1; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.leftMargin: 10; anchors.rightMargin: 10; height: 1; color: Colors.outline_variant; opacity: 0.45 }
          }
        }
      }
    }
  }

  Row {
    width: parent.width
    spacing: 8
    PillButton { width: (parent.width - 8) / 2; text: "Daily"; textSize: 14; filled: true; inactiveFillColor: Colors.surface_alt; active: root.tab === 0; onClicked: root.switchTab(0) }
    PillButton { width: (parent.width - 8) / 2; text: "Models"; textSize: 14; filled: true; inactiveFillColor: Colors.surface_alt; active: root.tab === 1; onClicked: root.switchTab(1) }
  }

  Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Tokens.errorText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; wrapMode: Text.WordWrap }
  Row {
    visible: root.loading && root.errorText === ""
    width: parent.width
    height: 46
    spacing: 10
    R1Icon {
      glyph: "\uf110"
      color: Colors.primary
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 20
      anchors.verticalCenter: parent.verticalCenter
      RotationAnimation on rotation { from: 0; to: 360; duration: Tokens.busyRotation; easing.type: Easing.Linear; loops: Animation.Infinite; running: !Tokens.reducedMotion }
    }
    Text { text: "Loading " + root.agentName(root.selectedAgent) + " usage…"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
  }

  Item {
    id: usagePages
    width: parent.width
    height: Math.max(dailyContent.implicitHeight, modelList.height)
    visible: !!root.report
    clip: true

    Column {
      id: dailyContent
      visible: !!root.report
      height: implicitHeight
      width: parent.width
      spacing: 8
      Behavior on x { NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing } }
    Text { width: parent.width; text: root.report ? (root.report.total.costAvailable === false ? root.formatTokens(root.report.total.tokens) + " tokens" : root.formatCost(root.report.total.cost)) : "—"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 40; font.weight: Font.DemiBold }
    Text { width: parent.width; text: root.report ? (root.report.total.costAvailable === false ? "in the last 7 days · cost unavailable" : root.formatTokens(root.report.total.tokens) + " tokens in the last 7 days") : ""; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Text { width: parent.width; text: root.report && root.report.weeklyLimit ? "Weekly plan usage · " + root.report.weeklyLimit.usedPercent + "%" : "Daily activity · tokens"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Item {
      id: activityChart
      width: parent.width
      height: 180
      readonly property real maximum: {
        let max = 1
        for (const day of (root.report ? root.report.days : [])) max = Math.max(max, day.tokens)
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
              height: Math.max(3, 112 * modelData.tokens / activityChart.maximum)
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
            HoverHandler {
              onHoveredChanged: {
                if (hovered) {
                  root.hoveredDay = modelData
                  root.hoveredX = parent.mapToItem(activityChart, parent.width / 2, 0).x
                } else if (root.hoveredDay === modelData) {
                  root.hoveredDay = null
                }
              }
            }
          }
        }
      }
      Rectangle {
        visible: root.hoveredDay !== null
        z: 10
        x: Math.max(0, Math.min(activityChart.width - width, root.hoveredX - width / 2))
        y: 2
        width: tooltipValue.implicitWidth + 20
        height: 34
        radius: 10
        color: Colors.surface_high
        border.width: Tokens.surfaceBorderWidth
        border.color: Colors.border
        Text {
          id: tooltipValue
          anchors.centerIn: parent
          text: root.hoveredDay ? root.formatTokens(root.hoveredDay.tokens || 0) + " tokens" : ""
          color: Colors.text
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }
      }
    }
    }

    Item {
      id: modelPage
      visible: !!root.report
      width: parent.width
      height: Math.min(300, modelList.contentHeight)
      clip: true
      Behavior on x { NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing } }
      ListView {
        id: modelList
        anchors.fill: parent
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
    }

  Component.onCompleted: {
    modelPage.x = modelPage.width
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
  }

  bottomContent: Item {
    width: parent.width
    height: 48
    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      Text { text: root.tab === 0 ? root.formatUpdated(root.report ? root.report.generatedAt : 0) : "7-day total"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
      Text { visible: root.tab === 1; text: root.report ? root.formatTokens(root.report.total.tokens) + " tokens · " + (root.report.total.costAvailable === false ? "cost unavailable" : root.formatCost(root.report.total.cost)) : "—"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold }
    }
    PillButton { visible: root.tab === 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 120; text: "Refresh"; textSize: 14; filled: true; inactiveFillColor: Colors.surface_alt; enabled: !usageProc.running && !root.loading; onClicked: root.refreshItems() }
  }
}
