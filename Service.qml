import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Photo Walls: a photo per workspace from the active theme's wallpapers, with
// the photographer credited on the desktop.
//
// The theme opts in by shipping `credits.json`, keyed by wallpaper filename:
//   { "01-place-by-name.jpg": { "place": "...", "photographer": "...", "profile": "https://..." } }
// Themes without that file are left alone: one wallpaper, no credit.
//
//   * Each workspace keeps its own photo; switching swaps it instantly, so you
//     land on the workspace's photo rather than watching it change.
//   * Every 15 minutes the photos are dealt out afresh (with a cross-fade).
//   * `omarchy-shell photo-walls next` (or the bar icon) gives the current
//     workspace a new photo; `shuffle` re-deals now.
//   * A small pill in the bottom-left corner names the place and photographer;
//     clicking it opens their profile.
Item {
  id: root

  property var shell: null
  property bool suspended: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string themeDir: stateHome + "/omarchy/current/theme"
  readonly property string backgroundLink: stateHome + "/omarchy/current/background"
  readonly property string dataDir: stateHome + "/eludif.photo-walls"
  readonly property int shuffleMinutes: 15

  property string backgroundPath: ""
  property var credits: ({})
  property var assignments: ({})
  readonly property var photos: Object.keys(credits).filter(function(name) {
    return /^[^\/]+\.(jpe?g|png|webp)$/i.test(name)
  }).sort()
  readonly property bool themed: photos.length > 0
  readonly property int activeWorkspace: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
    ? Hyprland.focusedMonitor.activeWorkspace.id : -1

  // ---- Credit for the photo on screen --------------------------------------

  readonly property string fileName: String(backgroundPath).split("/").pop()
  readonly property var entry: {
    var e = Object.prototype.hasOwnProperty.call(credits, fileName) ? credits[fileName] : null
    return Util.isPlainObject(e) ? e : null
  }
  // Credits are file data: plain text only, bounded, and only https links open.
  function field(name, limit) {
    var value = entry ? entry[name] : ""
    return typeof value === "string" ? value.replace(/[\r\n\t]+/g, " ").trim().slice(0, limit) : ""
  }
  readonly property string place: field("place", 80)
  readonly property string photographer: field("photographer", 60)
  readonly property string profile: {
    var url = field("profile", 300)
    return /^https:\/\/[A-Za-z0-9.-]+\/[^\s"'<>]*$/.test(url) ? url : ""
  }
  readonly property bool hasCredit: place.length > 0 && photographer.length > 0

  // ---- Photo per workspace --------------------------------------------------

  function pick(ws) {
    var current = assignments[ws]
    var taken = {}
    for (var key in assignments) if (key !== String(ws)) taken[assignments[key]] = true
    var pool = photos.filter(function(p) { return p !== current && !taken[p] })
    if (pool.length === 0) pool = photos.filter(function(p) { return p !== current })
    if (pool.length === 0) pool = photos
    return pool.length ? pool[Math.floor(Math.random() * pool.length)] : ""
  }

  function assign(ws, photo) {
    var next = Object.assign({}, assignments)
    next[ws] = photo
    assignments = next
    saveAssignments()
  }

  function show(ws, fade) {
    if (!themed || suspended || ws < 0) return
    var photo = assignments[ws]
    if (!photo || photos.indexOf(photo) === -1) {
      photo = pick(ws)
      if (!photo) return
      assign(ws, photo)
    }
    if (photo === fileName) return
    var target = themeDir + "/backgrounds/" + photo
    if (fade) {
      Util.execArgv(["omarchy-theme-bg-set", target])
    } else {
      Util.execArgv(["ln", "-nsf", target, backgroundLink])
      Util.execArgv(["omarchy-shell", "-q", "background", "setInstant", target])
    }
    backgroundPath = target
  }

  function next() {
    if (!themed || activeWorkspace < 0) return
    assign(activeWorkspace, pick(activeWorkspace))
    show(activeWorkspace, true)
  }

  function shuffle() {
    if (!themed) return
    assignments = ({})
    saveAssignments()
    show(activeWorkspace, true)
  }

  onActiveWorkspaceChanged: Qt.callLater(function() { root.show(root.activeWorkspace, false) })
  onThemedChanged: if (themed) Qt.callLater(function() { root.show(root.activeWorkspace, false) })

  Timer {
    interval: root.shuffleMinutes * 60 * 1000
    running: root.themed && !root.suspended
    repeat: true
    onTriggered: root.shuffle()
  }

  IpcHandler {
    target: "photo-walls"

    function next(): void { root.next() }
    function shuffle(): void { root.shuffle() }
    function credit(): string {
      return root.hasCredit ? root.place + " · " + root.photographer + (root.profile ? " · " + root.profile : "") : ""
    }
  }

  // ---- Files ----------------------------------------------------------------

  function parseCredits() {
    var text = String(creditsFile.text() || "")
    if (text.length === 0 || text.length > 200000) { credits = ({}); return }
    try {
      var data = JSON.parse(text)
      credits = Util.isPlainObject(data) ? data : ({})
    } catch (e) {
      credits = ({})
    }
  }

  FileView {
    id: creditsFile
    path: root.themeDir + "/credits.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.parseCredits()
    onLoadFailed: root.credits = ({})
  }

  function saveAssignments() {
    assignmentsFile.setText(JSON.stringify(assignments))
  }

  FileView {
    id: assignmentsFile
    path: root.dataDir + "/workspaces.json"
    onLoaded: {
      try {
        var data = JSON.parse(String(text() || "{}"))
        if (Util.isPlainObject(data)) root.assignments = data
      } catch (e) {}
      Qt.callLater(function() { root.show(root.activeWorkspace, false) })
    }
  }

  Component.onCompleted: Util.execArgv(["mkdir", "-p", root.dataDir])

  // The background link also changes from outside (the theme switcher, the
  // background picker), so keep reading it.
  Process {
    id: readlinkProc
    command: ["readlink", "-f", "--", root.backgroundLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next && next !== root.backgroundPath) root.backgroundPath = next
      }
    }
  }

  Timer {
    interval: 2000
    running: !root.suspended
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!readlinkProc.running) readlinkProc.running = true
  }

  // ---- Desktop credit -------------------------------------------------------

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.hasCredit && !root.suspended
      color: "transparent"
      anchors { bottom: true; left: true }
      margins { bottom: 24; left: 24 }
      implicitWidth: pill.width
      implicitHeight: pill.height
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "photo-walls-credit"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        id: pill
        width: row.implicitWidth + 28
        height: row.implicitHeight + 14
        radius: height / 2
        color: Qt.rgba(0.06, 0.10, 0.08, mouse.containsMouse ? 0.92 : 0.72)
        border.width: 1
        border.color: mouse.containsMouse && root.profile.length > 0 ? Qt.rgba(0.22, 0.85, 0.54, 0.8) : Qt.rgba(0.96, 1.0, 0.98, 0.12)
        Behavior on color { ColorAnimation { duration: Style.duration(150) } }

        Row {
          id: row
          anchors.centerIn: parent
          spacing: 10

          Text {
            textFormat: Text.PlainText
            text: root.place
            color: Qt.rgba(0.86, 0.91, 0.87, 1.0)
            font.family: Style.font.family
            font.pixelSize: 15
          }
          Text {
            textFormat: Text.PlainText
            text: "·"
            color: Qt.rgba(0.49, 0.60, 0.55, 1.0)
            font.family: Style.font.family
            font.pixelSize: 15
          }
          Text {
            textFormat: Text.PlainText
            text: strings.t("credit.photoBy").arg(root.photographer) + (root.profile.length > 0 ? "  ↗" : "")
            color: mouse.containsMouse && root.profile.length > 0 ? "#39D98A" : Qt.rgba(0.71, 0.79, 0.74, 1.0)
            font.family: Style.font.family
            font.pixelSize: 15
          }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.profile.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (root.profile.length > 0) Util.execArgv(["xdg-open", root.profile])
        }
      }
    }
  }
}
