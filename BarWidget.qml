import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Wallpaper Roulette: a thin bar widget that fires scripts/rotate.sh on a timer
// (and on click). All of the wallpaper/theme logic lives in the script so it can
// be run and tested outside the shell.
BarWidget {
  id: root
  moduleName: "io.github.keegan-sucks.wallpaper-roulette"

  property string wallpaperDir: ""
  property int intervalMinutes: 30
  property bool autoEnabled: true
  property bool applyMatchingTheme: true
  property bool notify: false
  property string glyph: "󰋫"

  readonly property int intervalMs: Math.max(1, root.intervalMinutes) * 60000

  readonly property string rotateScript: {
    var u = Qt.resolvedUrl("scripts/rotate.sh").toString()
    return u.replace(/^file:\/\//, "")
  }

  function configuredInt(key, fallback, minimum, maximum) {
    var v = Number(root.setting(key, fallback))
    if (!isFinite(v)) v = fallback
    return Math.max(minimum, Math.min(maximum, Math.round(v)))
  }

  function applySettings() {
    root.wallpaperDir = String(root.setting("wallpaperDir", ""))
    root.intervalMinutes = configuredInt("intervalMinutes", 30, 1, 1440)
    root.autoEnabled = root.setting("autoEnabled", true) !== false
    root.applyMatchingTheme = root.setting("applyMatchingTheme", true) !== false
    root.notify = root.setting("notify", false) === true
    root.glyph = String(root.setting("glyph", "󰋫"))
  }

  // Persist a single setting so it survives a shell restart, mirroring the
  // inline-update path the first-party widgets use.
  function persistSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings)
      if (existing !== "id") entry[existing] = root.settings[existing]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function rotateNow() {
    var args = ["bash", root.rotateScript,
      "--apply-theme", root.applyMatchingTheme ? "1" : "0",
      "--notify", root.notify ? "1" : "0"]
    if (root.wallpaperDir.length > 0) { args.push("--dir"); args.push(root.wallpaperDir) }
    Quickshell.execDetached(args)
  }

  function toggleAuto() {
    root.autoEnabled = !root.autoEnabled
    root.persistSetting("autoEnabled", root.autoEnabled)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onSettingsChanged: applySettings()
  Component.onCompleted: applySettings()

  // The rotation clock. Restarts whenever the interval or enabled state changes.
  Timer {
    interval: root.intervalMs
    repeat: true
    running: root.autoEnabled
    onTriggered: root.rotateNow()
  }

  IpcHandler {
    target: "io.github.keegan-sucks.wallpaper-roulette"

    function next(): void { root.rotateNow() }
    function toggle(): void { root.toggleAuto() }
    function status(): string {
      return JSON.stringify({
        autoEnabled: root.autoEnabled,
        intervalMinutes: root.intervalMinutes,
        applyMatchingTheme: root.applyMatchingTheme,
        wallpaperDir: root.wallpaperDir
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : glyphText.implicitWidth + button.scaledHorizontalMargin * 2
    active: root.autoEnabled
    tooltipText: "Wallpaper Roulette · " + (root.autoEnabled
      ? ("auto every " + root.intervalMinutes + " min")
      : "paused")
      + "\nClick: shuffle now · Right-click: " + (root.autoEnabled ? "pause" : "resume")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleAuto()
      else root.rotateNow()
    }

    Text {
      id: glyphText
      anchors.centerIn: parent
      text: root.glyph
      color: root.autoEnabled ? button.activeColor : button.foreground
      opacity: root.autoEnabled ? 1.0 : 0.6
      font.family: button.fontFamily
      font.pixelSize: Math.round(Style.font.iconLarge * 1.1)
      renderType: Text.NativeRendering
    }
  }
}
