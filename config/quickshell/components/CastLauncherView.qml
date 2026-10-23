import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import "../launcher/plugin/ui" as Cast
import "../launcher/plugin/compat" as CastCompat
import "./popuppos.js" as Pos

// Opt-in presentation for LauncherBase. Search, selection and activation remain
// in the existing controller; no desktop commands are owned by this view.
PanelWindow {
  id: view
  required property var controller
  readonly property string uiFont: CastCompat.Style.font.menuFamily
  readonly property bool hasHeaderAction: !controller.detailMode && (controller.listStatusActionText !== ""
    || (controller.footerActionVisible && controller.footerActionText !== "")
    )
  property alias inputItem: searchInput
  property alias listItem: resultsList
  property alias navItem: navKeys

  visible: controller.presentationVisible
  screen: Pos.focusedWorkspaceScreen(Quickshell.screens, Hyprland.monitorFor,
    Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.monitor : Hyprland.focusedMonitor)
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: controller.sockName
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Rectangle {
    anchors.fill: parent
    color: Colors.scrim
    opacity: view.controller.opened ? 0.3 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.motionStandard; easing.type: Tokens.motionEasing } }
  }
  MouseArea { anchors.fill: parent; onClicked: view.controller.closeLauncher() }

  Rectangle {
    id: card
    objectName: "castLauncherCard"
    anchors.centerIn: parent
    width: Math.min(680, parent.width - 32)
    height: Math.min(view.controller.cardHeight, parent.height - 32)
    radius: 20
    color: Colors.surface_high
    border.width: 1
    border.color: Colors.outline_variant
    opacity: view.controller.opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.motionStandard; easing.type: Tokens.motionEasing } }
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: "#50000000"
      shadowBlur: 0.6
      shadowVerticalOffset: 8
    }
    MouseArea { anchors.fill: parent }

    Item {
      id: header
      objectName: "castLauncherHeader"
      anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
      height: 64

      Cast.BrandMark {
        width: 26
        height: 26
        anchors { left: parent.left; leftMargin: 19; verticalCenter: parent.verticalCenter }
      }

      TextInput {
        id: searchInput
        objectName: "castLauncherSearch"
        anchors {
          left: parent.left; right: escapeButton.left; verticalCenter: parent.verticalCenter
          leftMargin: 56; rightMargin: 14
        }
        visible: view.controller.searchEnabled && !view.controller.detailMode
        font.family: view.uiFont
        font.pixelSize: 17
        color: Colors.text
        selectionColor: Colors.text_selection
        selectedTextColor: Colors.on_text_selection
        selectByMouse: true
        clip: true
        echoMode: view.controller.promptMode && view.controller.promptPassword ? TextInput.Password : TextInput.Normal
        cursorDelegate: Rectangle { width: 2; height: searchInput.cursorRectangle.height; color: Colors.primary }

        Text {
          anchors.fill: parent
          visible: searchInput.text === ""
          text: view.controller.promptMode ? "Enter password…"
            : (view.controller.searchPlaceholder || view.controller.title)
          font: searchInput.font
          color: Colors.text
          opacity: 0.55
          elide: Text.ElideRight
        }
        onTextEdited: if (!view.controller.promptMode) view.controller.query = text
        onAccepted: {
          if (view.controller.detailMode) view.controller.detailAcceptRequested()
          else if (view.controller.promptMode) {
            const value = text
            view.controller.exitPrompt()
            view.controller.promptSubmitted(value)
          } else view.controller.activate()
        }
        Keys.onDownPressed: function(event) { view.controller.step(1); event.accepted = true }
        Keys.onUpPressed: function(event) { view.controller.step(-1); event.accepted = true }
        Keys.onEscapePressed: function(event) {
          if (view.controller.detailMode) view.controller.detailBackRequested()
          else if (view.controller.promptMode) view.controller.exitPrompt()
          else view.controller.closeLauncher()
          event.accepted = true
        }
        Keys.onTabPressed: function(event) {
          if (view.controller.footerActionText !== "" || view.controller.listStatusActionText !== "") view.controller.footerActionClicked()
          event.accepted = true
        }
        Keys.onBacktabPressed: function(event) { event.accepted = true }
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_PageUp) { view.controller.step(10); event.accepted = true }
          else if (event.key === Qt.Key_PageDown) { view.controller.step(-10); event.accepted = true }
          else if (view.controller.tryItemAction(event)) event.accepted = true
        }
      }

      Text {
        anchors { left: parent.left; right: escapeButton.left; verticalCenter: parent.verticalCenter; leftMargin: 56; rightMargin: 14 }
        visible: !view.controller.searchEnabled || view.controller.detailMode
        text: view.controller.detailMode ? view.controller.headerTitle : (view.controller.headerText || view.controller.headerTitle || view.controller.title)
        font.family: view.uiFont
        font.pixelSize: 17
        color: Colors.text
        elide: Text.ElideRight
      }
      Item {
        id: escapeButton
        anchors { right: headerAction.visible ? headerAction.left : parent.right; rightMargin: headerAction.visible ? 8 : 18; verticalCenter: parent.verticalCenter }
        width: escapeHint.implicitWidth
        height: escapeHint.implicitHeight
        Cast.KeyHint {
          id: escapeHint
          keys: "Esc"
          color: Colors.text
          fontFamily: view.uiFont
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (view.controller.detailMode) view.controller.detailBackRequested()
            else if (view.controller.promptMode) view.controller.exitPrompt()
            else view.controller.closeLauncher()
          }
        }
      }
      PillButton {
        id: headerAction
        objectName: "castLauncherHeaderAction"
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        visible: view.hasHeaderAction
        height: 28
        radius: 7
        text: view.controller.listStatusActionText || view.controller.footerActionText
        glyph: view.controller.footerActionGlyph
        fontFamily: view.uiFont
        textSize: 12
        active: view.controller.footerActionActive
        filled: true
        fillColor: Colors.primary_container
        activeTextColor: Colors.on_primary_container
        onClicked: view.controller.footerActionClicked()
      }
      Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Colors.divider }
    }

    Item {
      id: navKeys
      anchors.fill: parent
      visible: !view.controller.searchEnabled
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down) { view.controller.step(1); event.accepted = true }
        else if (event.key === Qt.Key_Up) { view.controller.step(-1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (view.controller.detailMode) view.controller.detailAcceptRequested()
          else view.controller.activate()
          event.accepted = true
        }
        else if (event.key === Qt.Key_Escape) {
          if (view.controller.detailMode) view.controller.detailBackRequested()
          else view.controller.closeLauncher()
          event.accepted = true
        }
        else if (view.controller.tryNavItemAction(event)) event.accepted = true
      }
    }

    Item {
      id: body
      anchors { top: header.bottom; bottom: footer.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: listError.visible ? listError.height + 24 : 8 }

      Text {
        id: sectionLabel
        objectName: "castLauncherSection"
        anchors { top: parent.top; left: parent.left; leftMargin: 12 }
        height: visible ? 30 : 0
        visible: !view.controller.promptMode && !view.controller.detailMode
        verticalAlignment: Text.AlignVCenter
        text: view.controller.headerTitle.toUpperCase()
        font.family: view.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.7
        color: Colors.text_alt
      }
      ListView {
        id: resultsList
        objectName: "castLauncherResults"
        anchors { top: sectionLabel.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        visible: !view.controller.promptMode && !view.controller.detailMode
        model: view.controller.results
        boundsBehavior: Flickable.StopAtBounds
        interactive: true

        CastCompat.PointerMoveGate { id: pointerGate; referenceItem: card }
        Connections {
          target: view.controller
          function onOpenedChanged() { pointerGate.reset() }
          function onQueryChanged() { pointerGate.reset() }
        }

        delegate: Rectangle {
          id: resultRow
          required property var modelData
          required property int index
          readonly property bool selected: view.controller.selectedIndex === index
          objectName: "castLauncherRow"
          width: ListView.view.width
          height: 56
          radius: 10
          color: selected ? Colors.primary_container : "transparent"

          R1Icon {
            id: glyph
            width: 26
            height: 26
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            visible: view.controller.itemIcon(resultRow.modelData.item) === ""
            glyph: view.controller.itemGlyph(resultRow.modelData.item)
            font.pixelSize: 20
            color: resultRow.selected ? Colors.on_primary_container : Colors.text_alt
          }
          Image {
            id: rowImage
            objectName: "castLauncherRowImage"
            width: 40
            height: 40
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            visible: view.controller.itemIcon(resultRow.modelData.item) !== ""
            source: view.controller.itemIcon(resultRow.modelData.item)
            sourceSize: Qt.size(80, 80)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            clip: true
          }
          Column {
            id: rowText
            anchors { left: rowImage.visible ? rowImage.right : glyph.right; right: rowMeta.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
            spacing: 3
            Text {
              width: parent.width
              text: view.controller.itemTitle(resultRow.modelData.item)
              textFormat: Text.PlainText
              font.family: view.uiFont
              font.pixelSize: 15
              font.weight: Font.Medium
              color: resultRow.selected ? Colors.on_primary_container : Colors.text
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              visible: text !== ""
              text: view.controller.itemSubtitleLive(resultRow.modelData.item)
              textFormat: Text.PlainText
              font.family: view.uiFont
              font.pixelSize: 12
              color: resultRow.selected ? Colors.on_primary_container : Colors.text_alt
              opacity: resultRow.selected ? 0.7 : 1
              elide: Text.ElideRight
            }
          }
          Item {
            id: rowMeta
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: view.controller.metaAsKeys ? shortcutKeys.implicitWidth : metaText.implicitWidth
            height: view.controller.metaAsKeys ? shortcutKeys.implicitHeight : metaText.implicitHeight
            Text {
              id: metaText
              visible: !view.controller.metaAsKeys
              text: view.controller.itemMeta(resultRow.modelData.item)
              font.family: view.uiFont
              font.pixelSize: 12
              color: resultRow.selected ? Colors.on_primary_container : Colors.text_alt
            }
            Cast.KeyHint {
              id: shortcutKeys
              objectName: "castLauncherShortcutKeys"
              visible: view.controller.metaAsKeys
              keys: view.controller.itemMeta(resultRow.modelData.item)
              fontFamily: view.uiFont
              color: resultRow.selected ? Colors.on_primary_container : Colors.text
            }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function(mouse) {
              if (pointerGate.moved(resultRow, mouse)) view.controller.selectedIndex = resultRow.index
            }
            onClicked: view.controller.activateAt(resultRow.index)
          }
        }
      }
      Rectangle {
        objectName: "castLauncherScrollbar"
        visible: resultsList.visible && resultsList.contentHeight > resultsList.height
        anchors.right: parent.right
        width: 2
        height: Math.max(24, resultsList.height * resultsList.height / Math.max(1, resultsList.contentHeight))
        y: sectionLabel.height + Math.max(0, Math.min(1, resultsList.contentY / Math.max(1, resultsList.contentHeight - resultsList.height))) * (resultsList.height - height)
        radius: 1
        color: Colors.text_alt
        opacity: 0.25
      }
      Loader {
        objectName: "castLauncherDetail"
        anchors.fill: parent
        visible: view.controller.detailMode
        active: view.controller.detailMode
        sourceComponent: view.controller.detailContent
      }
      Column {
        anchors.centerIn: parent
        visible: view.controller.results.length === 0 && !view.controller.promptMode && !view.controller.detailMode
        spacing: 12
        R1Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          iconName: view.controller.loading ? "" : view.controller.emptyIconName
          glyph: view.controller.loading ? "\uf110" : ""
          font.pixelSize: 24
          color: Colors.text_alt
          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: Tokens.busyRotation
            loops: Animation.Infinite
            running: view.controller.loading && !Tokens.reducedMotion
          }
        }
        Text {
          text: view.controller.loading ? view.controller.loadingText : view.controller.emptyText
          font.family: view.uiFont
          font.pixelSize: 14
          color: Colors.text_alt
        }
      }
      Column {
        id: passwordPrompt
        objectName: "castLauncherPasswordPrompt"
        anchors.centerIn: parent
        width: Math.min(480, parent.width - 48)
        visible: view.controller.promptMode && !view.controller.detailMode
        spacing: 12
        R1Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          glyph: "\uf023"
          font.pixelSize: 24
          color: Colors.primary
        }
        Text {
          width: parent.width
          text: view.controller.promptTitle
          textFormat: Text.PlainText
          font.family: view.uiFont
          font.pixelSize: 17
          font.weight: Font.Medium
          color: Colors.text
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
        }
        Text {
          width: parent.width
          text: "Enter the network password to connect."
          font.family: view.uiFont
          font.pixelSize: 14
          color: Colors.text_alt
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
        }
        Text {
          objectName: "castLauncherPromptError"
          width: parent.width
          visible: view.controller.promptError !== ""
          text: view.controller.promptError
          textFormat: Text.PlainText
          font.family: view.uiFont
          font.pixelSize: 14
          color: Colors.error_text
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    Text {
      id: listError
      objectName: "castLauncherListError"
      anchors { left: parent.left; right: parent.right; bottom: footer.top; leftMargin: 24; rightMargin: 24; bottomMargin: 12 }
      visible: view.controller.listErrorText !== ""
      text: view.controller.listErrorText
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      font.family: view.uiFont
      font.pixelSize: 14
      color: Colors.error_text
    }

    Item {
      id: footer
      objectName: "castLauncherFooter"
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
      height: 40
      Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Colors.divider }
      Row {
        objectName: "castLauncherFooterContext"
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8
        Cast.BrandMark { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: view.controller.headerTitle + (view.controller.countShown ? " · " + view.controller.resultCount : "")
          font.family: view.uiFont
          font.pixelSize: 12
          color: Colors.text_alt
        }
      }
      Row {
        objectName: "castLauncherFooterActions"
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8
        Text { visible: !view.controller.promptMode && !view.controller.detailMode; anchors.verticalCenter: parent.verticalCenter; text: "Navigate"; font.family: view.uiFont; font.pixelSize: 12; color: Colors.text_alt }
        Cast.KeyHint { visible: !view.controller.promptMode && !view.controller.detailMode; anchors.verticalCenter: parent.verticalCenter; keys: "↑ ↓"; color: Colors.text; fontFamily: view.uiFont }
        Rectangle { visible: !view.controller.promptMode && view.controller.deactivatable; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: Colors.divider }
        Text { visible: view.controller.deactivatable; anchors.verticalCenter: parent.verticalCenter; text: view.controller.primaryActionText; font.family: view.uiFont; font.pixelSize: 12; color: Colors.text }
        Cast.KeyHint { visible: view.controller.deactivatable; anchors.verticalCenter: parent.verticalCenter; keys: "↵"; color: Colors.text; fontFamily: view.uiFont }
        Repeater {
          model: view.controller.promptMode ? [] : view.controller.itemActions
          delegate: Row {
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: Colors.divider }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: {
                const words = (modelData.hint || "").split(" ").slice(1).join(" ")
                return words.charAt(0).toUpperCase() + words.slice(1)
              }
              font.family: view.uiFont
              font.pixelSize: 12
              color: Colors.text_alt
            }
            Cast.KeyHint { anchors.verticalCenter: parent.verticalCenter; keys: (modelData.hint || "").split(" ")[0].replace(/\+/g, " "); color: Colors.text; fontFamily: view.uiFont }
          }
        }
        Rectangle { visible: view.hasHeaderAction && !view.controller.promptMode; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: Colors.divider }
        Text { visible: view.hasHeaderAction && !view.controller.promptMode; anchors.verticalCenter: parent.verticalCenter; text: "Toggle"; font.family: view.uiFont; font.pixelSize: 12; color: Colors.text_alt }
        Cast.KeyHint { visible: view.hasHeaderAction && !view.controller.promptMode; anchors.verticalCenter: parent.verticalCenter; keys: "Tab"; color: Colors.text; fontFamily: view.uiFont }
      }
    }
  }
}
