pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool dndEnabled: false

  Timer {
    id: fileReloadTimer
    interval: 100
    repeat: false
    onTriggered: fileView.reload()
  }

  Timer {
    id: fileWriteTimer
    interval: 100
    repeat: false
    onTriggered: fileView.writeAdapter()
  }

  FileView {
    id: fileView
    path: Quickshell.statePath("dnd-state.json")
    watchChanges: true
    onFileChanged: fileReloadTimer.restart()
    onAdapterUpdated: fileWriteTimer.restart()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
        fileWriteTimer.restart()
    }

    adapter: JsonAdapter {
      id: jsonAdapter
      property bool dndEnabled: false
    }
  }

  Connections {
    target: jsonAdapter
    function onDndEnabledChanged() {
      root.dndEnabled = jsonAdapter.dndEnabled
    }
  }

  onDndEnabledChanged: {
    if (jsonAdapter.dndEnabled !== dndEnabled)
      jsonAdapter.dndEnabled = dndEnabled
  }
}
