import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// Photo Walls bar icon: click for a new photo on this workspace; the tooltip
// names the place and photographer of the one on screen. Shown only while the
// active theme ships a credits.json.
BarWidget {
  id: root
  moduleName: "eludif.photo-walls"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  property var credits: ({})
  property string fileName: ""

  readonly property var entry: {
    var e = Object.prototype.hasOwnProperty.call(credits, fileName) ? credits[fileName] : null
    return Util.isPlainObject(e) ? e : null
  }
  // The tooltip is an Omarchy component that may treat markup-shaped text as
  // rich text, so credit text from the theme loses <, > and & before it gets there.
  function field(name, limit) {
    var value = entry ? entry[name] : ""
    return typeof value === "string" ? value.replace(/[\r\n\t]+/g, " ").replace(/[<>&]/g, "").trim().slice(0, limit) : ""
  }
  readonly property string place: field("place", 80)
  readonly property string photographer: field("photographer", 60)

  FileView {
    id: creditsFile
    path: root.stateHome + "/omarchy/current/theme/credits.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var t = String(text() || "")
        var d = t.length > 0 && t.length < 200000 ? JSON.parse(t) : null
        root.credits = Util.isPlainObject(d) ? d : ({})
      } catch (e) { root.credits = ({}) }
    }
    onLoadFailed: root.credits = ({})
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", "--", root.stateHome + "/omarchy/current/background"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.fileName = String(text || "").trim().split("/").pop()
    }
  }

  Timer {
    interval: 3000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!readlinkProc.running) readlinkProc.running = true
  }

  visible: Object.keys(credits).length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋩"
    tooltipText: root.place && root.photographer
      ? strings.t("widget.tooltip").arg(root.place).arg(root.photographer)
      : strings.t("widget.tooltipNoCredit")
    onPressed: function(mouseButton) {
      Util.execArgv(["omarchy-shell", "photo-walls", "next"])
      readlinkTimer.restart()
    }
  }

  Timer {
    id: readlinkTimer
    interval: 1500
    onTriggered: if (!readlinkProc.running) readlinkProc.running = true
  }
}
