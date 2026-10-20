import QtQuick
import Quickshell
import qs
import "../components"

PopupBase {
  id: root

  sockName: "kmdot-display"
  title: "Display"
  cardWidth: 424
  cardChrome: 48

  readonly property var displays: DisplayState.displays
  readonly property var selectedDisplay: DisplayState.selectedDisplay
  readonly property bool canArrange: displays.length > 1
    && DisplayState.currentMode === "extend" && !DisplayState.changeBusy
  property bool resolutionOpen: false
  property string pendingDisplayMode: ""

  Timer {
    id: applyModeTimer
    interval: Tokens.motionStandard + 16
    onTriggered: DisplayState.applyMode(root.pendingDisplayMode)
  }

  function refreshItems() {
    DisplayState.refreshDisplays()
    DisplayState.detectBacklights()
  }
  function openedChange() {
    DisplayState.monitorsActive = root.opened
    if (!root.opened) root.resolutionOpen = false
  }

  function logicalWidth(display) { return display.width / (display.scale || 1) }
  function logicalHeight(display) { return display.height / (display.scale || 1) }
  function visualPosition(display) {
    if (DisplayState.currentMode !== "mirror") return { x: display.x, y: display.y }
    let x = 0
    const ordered = root.displays.slice().sort((a, b) => a.name.localeCompare(b.name))
    for (const item of ordered) {
      if (item.name === display.name) return { x: x, y: 0 }
      x += root.logicalWidth(item) + 48
    }
    return { x: x, y: 0 }
  }
  function bounds() {
    if (!root.displays.length) return { minX: 0, minY: 0, width: 1, height: 1 }
    const first = root.visualPosition(root.displays[0])
    let minX = first.x, minY = first.y
    let maxX = minX, maxY = minY
    for (const display of root.displays) {
      const pos = root.visualPosition(display)
      minX = Math.min(minX, pos.x)
      minY = Math.min(minY, pos.y)
      maxX = Math.max(maxX, pos.x + root.logicalWidth(display))
      maxY = Math.max(maxY, pos.y + root.logicalHeight(display))
    }
    return { minX: minX, minY: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
  }
  function mapScale() {
    const b = root.bounds()
    return Math.min(Math.max(1, layoutCanvas.width - 24) / b.width,
                    Math.max(1, layoutCanvas.height - 24) / b.height)
  }
  function mapX(display) {
    const b = root.bounds(), factor = root.mapScale()
    return (layoutCanvas.width - b.width * factor) / 2 + (root.visualPosition(display).x - b.minX) * factor
  }
  function mapY(display) {
    const b = root.bounds(), factor = root.mapScale()
    return (layoutCanvas.height - b.height * factor) / 2 + (root.visualPosition(display).y - b.minY) * factor
  }
  function tileWidth(display) { return root.logicalWidth(display) * root.mapScale() }
  function tileHeight(display) { return root.logicalHeight(display) * root.mapScale() }

  function commitDrop(name, visualX, visualY) {
    const moving = root.displays.find(display => display.name === name)
    if (!moving || !root.canArrange) return
    let target = null, nearest = Number.MAX_VALUE
    const movingCenterX = visualX + root.tileWidth(moving) / 2
    const movingCenterY = visualY + root.tileHeight(moving) / 2
    for (const display of root.displays) {
      if (display.name === name) continue
      const dx = movingCenterX - (root.mapX(display) + root.tileWidth(display) / 2)
      const dy = movingCenterY - (root.mapY(display) + root.tileHeight(display) / 2)
      const distance = dx * dx + dy * dy
      if (distance < nearest) { nearest = distance; target = display }
    }
    if (!target) return

    const b = root.bounds(), factor = root.mapScale()
    const originX = (layoutCanvas.width - b.width * factor) / 2 - b.minX * factor
    const originY = (layoutCanvas.height - b.height * factor) / 2 - b.minY * factor
    const logicalX = (visualX - originX) / factor
    const logicalY = (visualY - originY) / factor
    const dx = movingCenterX - (root.mapX(target) + root.tileWidth(target) / 2)
    const dy = movingCenterY - (root.mapY(target) + root.tileHeight(target) / 2)

    let x, y
    if (Math.abs(dx) >= Math.abs(dy)) {
      x = dx >= 0 ? target.x + root.logicalWidth(target) : target.x - root.logicalWidth(moving)
      y = Math.round(logicalY)
    } else {
      x = Math.round(logicalX)
      y = dy >= 0 ? target.y + root.logicalHeight(target) : target.y - root.logicalHeight(moving)
    }
    DisplayState.setDisplayPosition(name, x, y)
  }

  Column {
    width: parent.width
    spacing: 16

    Row {
      width: parent.width
      height: 32
      spacing: 12
      R1Icon {
        width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
        glyph: "\uf26c"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 22; color: Colors.text
      }
      Text {
        id: displayTitle
        anchors.verticalCenter: parent.verticalCenter
        text: "Display"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 23
        font.weight: Font.DemiBold; color: Colors.text
      }
      Item { width: Math.max(0, parent.width - 36 - displayTitle.implicitWidth - 70); height: 1 }
      Text {
        id: applyLabel
        width: 70; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
        text: DisplayState.changeBusy ? "Applying…" : ""
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.primary
      }
    }

    Column {
      width: parent.width
      spacing: 8
      Row {
        width: parent.width; height: 18
        Text { id: layoutLabel; text: "DISPLAY LAYOUT"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
        Item { width: Math.max(0, parent.width - layoutLabel.implicitWidth - 180); height: 1 }
        Text {
          id: dragHint
          width: 180; horizontalAlignment: Text.AlignRight
        text: root.canArrange ? "Drag a screen to reposition" : DisplayState.currentMode === "mirror" ? "Mirrored · arrange in Extend" : root.displays.length > 1 ? "Switch to Extend to arrange" : ""
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: Tokens.mutedText
        }
      }
      Rectangle {
        width: parent.width; height: 200; radius: 24
        color: Colors.surface_alt
        clip: true
        Item {
          id: layoutCanvas
          anchors.fill: parent; anchors.margins: 12
          clip: true
          Repeater {
            model: root.displays
            delegate: Rectangle {
              id: screenTile
              required property var modelData
              required property int index
              property bool dragging: false
              property real previewX: 0
              property real previewY: 0
              property real dragOriginX: 0
              property real dragOriginY: 0
              readonly property real normalX: root.mapX(modelData)
              readonly property real normalY: root.mapY(modelData)
              readonly property bool selected: index === DisplayState.selectedIdx

              x: dragging ? previewX : normalX
              y: dragging ? previewY : normalY
              width: root.tileWidth(modelData)
              height: root.tileHeight(modelData)
              radius: 12
              color: selected ? Colors.primary_container : Colors.surface
              border.width: dragging ? 2 : selected ? 2 : 0
              border.color: dragging || selected ? Colors.primary : Colors.border
              opacity: modelData.disabled ? 0.5 : 1
              z: dragging ? 5 : index === DisplayState.selectedIdx ? 2 : 1

              Column {
                anchors.centerIn: parent
                width: Math.max(1, parent.width - 12)
                spacing: 3
                Text {
                  width: parent.width; horizontalAlignment: Text.AlignHCenter
                  text: String(index + 1); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22
                  color: screenTile.selected ? Colors.on_primary_container : Colors.text
                }
                Text {
                  width: parent.width; horizontalAlignment: Text.AlignHCenter
                  text: modelData.name; elide: Text.ElideRight
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                  color: screenTile.selected ? Colors.on_primary_container : Colors.text_alt
                }
                Text {
                  visible: screenTile.height > 56
                  width: parent.width; horizontalAlignment: Text.AlignHCenter
                  text: modelData.width + " × " + modelData.height
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                  color: screenTile.selected ? Colors.on_primary_container : Tokens.mutedText
                }
              }

              TapHandler { onTapped: DisplayState.selectDisplay(index) }
              DragHandler {
                id: screenDrag
                target: null
                enabled: root.canArrange
                onActiveChanged: {
                  if (active) {
                    DisplayState.selectDisplay(index)
                    screenTile.previewX = screenTile.x
                    screenTile.previewY = screenTile.y
                    screenTile.dragOriginX = screenTile.x
                    screenTile.dragOriginY = screenTile.y
                    screenTile.dragging = true
                  } else if (screenTile.dragging) {
                    root.commitDrop(modelData.name, screenTile.previewX, screenTile.previewY)
                    screenTile.dragging = false
                  }
                }
                onTranslationChanged: if (active) {
                  screenTile.previewX = screenTile.dragOriginX + translation.x
                  screenTile.previewY = screenTile.dragOriginY + translation.y
                }
              }
            }
          }
          Text {
            anchors.centerIn: parent
            visible: root.displays.length === 0
            text: "No displays detected"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt
          }
        }
      }
    }

    Column {
      width: parent.width; spacing: 4
      Row {
        width: parent.width
        Text {
          id: selectedNameLabel
          width: parent.width - 70
          text: !root.selectedDisplay ? "No display selected"
            : /^(eDP|LVDS|DSI)/i.test(root.selectedDisplay.name) ? "Built-in display · " + root.selectedDisplay.name : root.selectedDisplay.name
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold
          color: Colors.text; elide: Text.ElideRight
        }
        Item { width: Math.max(0, parent.width - selectedNameLabel.width - 70); height: 1 }
        Text {
          id: displayStatus
          width: 70; horizontalAlignment: Text.AlignRight
          text: root.selectedDisplay ? (root.selectedDisplay.disabled ? "Disabled" : root.selectedDisplay.focused ? "This display" : "") : ""
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
          color: root.selectedDisplay && root.selectedDisplay.disabled ? Tokens.mutedText : Colors.primary
        }
      }
      Text {
        text: root.selectedDisplay ? root.selectedDisplay.width + " × " + root.selectedDisplay.height + " · " + root.selectedDisplay.refresh.toFixed(2) + " Hz" : ""
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
      }
    }

    Column {
      width: parent.width; spacing: 8
      Text { text: "RESOLUTION · REFRESH RATE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
      Column {
        width: parent.width; spacing: 6
        Rectangle {
          width: parent.width; height: 40; radius: 20; color: Colors.surface_alt
          border.width: root.resolutionOpen ? 1 : 0; border.color: Colors.primary
          Text {
            anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
            text: root.selectedDisplay ? root.selectedDisplay.width + " × " + root.selectedDisplay.height : "No display selected"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text
          }
          Text {
            anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter
            text: root.selectedDisplay ? root.selectedDisplay.refresh.toFixed(2) + " Hz" : ""
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt
          }
          R1Icon {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            glyph: "\uf078"; rotation: root.resolutionOpen ? 180 : 0
            font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14; color: Colors.text_alt
            Behavior on rotation { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }
          }
          MouseArea { anchors.fill: parent; enabled: !!root.selectedDisplay && !DisplayState.changeBusy; onClicked: root.resolutionOpen = !root.resolutionOpen }
        }
        Rectangle {
          width: parent.width; height: root.resolutionOpen ? Math.min(resolutionList.contentHeight + 12, 180) : 0
          visible: root.resolutionOpen; radius: 16; color: Colors.surface_high; border.width: 1; border.color: Colors.border; clip: true
          ListView {
            id: resolutionList
            anchors.fill: parent; anchors.margins: 6; clip: true
            model: root.selectedDisplay ? root.selectedDisplay.modes : []
            delegate: Item {
              required property var modelData
              required property int index
              width: resolutionList.width; height: 36
              readonly property bool chosen: root.selectedDisplay
                && root.selectedDisplay.width === modelData.width
                && root.selectedDisplay.height === modelData.height
                && Math.abs(root.selectedDisplay.refresh - modelData.refresh) < 0.02
              Rectangle { anchors.fill: parent; radius: 10; color: parent.chosen ? Colors.surface_alt : "transparent" }
              Text {
                anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: modelData.width + " × " + modelData.height
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: parent.chosen ? Colors.text : Colors.text_alt
              }
              Text {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: modelData.refresh.toFixed(2) + " Hz"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: parent.chosen ? Colors.text : Colors.text_alt
              }
              MouseArea {
                anchors.fill: parent; enabled: !DisplayState.changeBusy
                onClicked: { DisplayState.applyDisplayMode(modelData); root.resolutionOpen = false }
              }
            }
          }
        }
      }
    }

    Column {
      width: parent.width; spacing: 8
      Row {
        width: parent.width
        Text { id: brightnessLabel; text: "BRIGHTNESS"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
        Item { width: Math.max(0, parent.width - brightnessLabel.implicitWidth - 90); height: 1 }
        Text {
          id: brightnessValue
          width: 90; horizontalAlignment: Text.AlignRight
          text: root.selectedDisplay && DisplayState.selectedHasBacklight ? DisplayState.percentFor(DisplayState.selectedDevice) + "%" : "Unavailable"
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
          color: root.selectedDisplay && DisplayState.selectedHasBacklight ? Colors.primary : Tokens.mutedText
        }
      }
      SliderBar {
        width: parent.width; height: 40; trackHeight: 40
        enabled: root.selectedDisplay && DisplayState.selectedHasBacklight
        opacity: enabled ? 1 : 0.38
        value: DisplayState.curFor(DisplayState.selectedDevice) / DisplayState.maxFor(DisplayState.selectedDevice)
        trackColor: Colors.surface_alt; barRadius: 20
        onChanged: value => DisplayState.applyBrightness(DisplayState.selectedDevice,
          Math.round(value * DisplayState.maxFor(DisplayState.selectedDevice)))
      }
    }

    Column {
      width: parent.width; spacing: 8
      Text { text: "SCALE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
      Row {
        width: parent.width; spacing: 8
        Repeater {
          model: [1, 1.25, 1.5, 2]
          PillButton {
            required property var modelData
            width: (parent.width - 24) / 4; height: 40; filled: true
            inactiveFillColor: Colors.surface_alt
            active: root.selectedDisplay && root.selectedDisplay.scale === modelData
            enabled: !!root.selectedDisplay && !DisplayState.changeBusy
            text: Math.round(modelData * 100) + "%"; textSize: 14
            onClicked: DisplayState.applyScale(DisplayState.selectedName, modelData)
          }
        }
      }
    }

    Column {
      width: parent.width; spacing: 8
      Text { text: "DISPLAY MODE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
      Row {
        width: parent.width; spacing: 8
        Repeater {
          model: [{ label: "Extend", value: "extend" }, { label: "Mirror", value: "mirror" }, { label: "External", value: "external" }]
          PillButton {
            required property var modelData
            width: (parent.width - 16) / 3; height: 40; filled: true
            inactiveFillColor: Colors.surface_alt
            active: DisplayState.currentMode === modelData.value
            enabled: root.displays.length > 0 && !DisplayState.changeBusy
              && (modelData.value === "extend" || root.displays.length > 1)
            text: modelData.label; textSize: 14
            onClicked: {
              if (modelData.value === DisplayState.currentMode) return
              // Release the fullscreen input grab before its screen becomes
              // mirrored or disabled. Reopen from the surviving bar afterward.
              root.pendingDisplayMode = modelData.value
              root.close()
              applyModeTimer.restart()
            }
          }
        }
      }
    }

    Text {
      visible: DisplayState.changeError !== ""
      width: parent.width; wrapMode: Text.WordWrap
      text: DisplayState.changeError
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Tokens.errorText
    }
  }
}
