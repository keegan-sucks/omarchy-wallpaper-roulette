import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Wallpaper Roulette: a thin bar widget that fires scripts/rotate.sh on a timer
// (and on click) and opens scripts/pick.sh on right-click. All of the
// wallpaper/theme logic lives in the scripts so it can be run and tested
// outside the shell.
BarWidget {
  id: root
  moduleName: "io.github.keegan-sucks.wallpaper-roulette"

  property string wallpaperDir: ""
  property int intervalMinutes: 30
  property bool autoEnabled: true
  property bool applyMatchingTheme: true
  property bool notify: false
  property string glyph: "󰋫"

  readonly property string rotateScript: root.localPath("scripts/rotate.sh")
  readonly property string pickScript: root.localPath("scripts/pick.sh")

  function localPath(relative) {
    return Qt.resolvedUrl(relative).toString().replace(/^file:\/\//, "")
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

  // dueSecs < 0 rotates unconditionally (a click or the `next` IPC call);
  // dueSecs >= 0 passes --if-due so the script rotates only when that many
  // seconds have elapsed since the last rotation.
  function rotateArgs(dueSecs) {
    var a = ["bash", root.rotateScript,
      "--apply-theme", root.applyMatchingTheme ? "1" : "0",
      "--notify", root.notify ? "1" : "0"]
    if (dueSecs >= 0) { a.push("--if-due"); a.push(String(dueSecs)) }
    if (root.wallpaperDir.length > 0) { a.push("--dir"); a.push(root.wallpaperDir) }
    return a
  }

  function rotateNow() {
    Quickshell.execDetached(root.rotateArgs(-1))
  }

  function rotateIfDue() {
    Quickshell.execDetached(root.rotateArgs(Math.max(1, root.intervalMinutes) * 60))
  }

  function toggleAuto() {
    root.autoEnabled = !root.autoEnabled
    root.persistSetting("autoEnabled", root.autoEnabled)
  }

  // The wallpaper picker: the stock Omarchy image carousel over every
  // wallpaper the roulette can land on. pick.sh blocks until the picker
  // closes and then applies the choice itself, so it runs detached.
  function pickArgs(prepare) {
    var a = ["bash", root.pickScript,
      "--apply-theme", root.applyMatchingTheme ? "1" : "0",
      "--notify", root.notify ? "1" : "0"]
    if (prepare) a.push("--prepare")
    if (root.wallpaperDir.length > 0) { a.push("--dir"); a.push(root.wallpaperDir) }
    return a
  }

  function openPicker() {
    Quickshell.execDetached(root.pickArgs(false))
  }

  // Stage the picker's file list and thumbnails ahead of time so the first
  // right-click opens without a pause. Cheap when nothing changed.
  function preparePicker() {
    Quickshell.execDetached(["nice", "-n", "10"].concat(root.pickArgs(true)))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onSettingsChanged: applySettings()
  Component.onCompleted: {
    applySettings()
    preparePicker()
  }

  // The rotation clock. It deliberately does NOT count the whole interval in
  // memory: the shell tears this widget down and rebuilds it on every plugin
  // reload or restart, which would reset such a countdown — that is exactly why
  // auto-rotate would get stuck on one wallpaper for hours. Instead it ticks
  // once a minute and asks the script to rotate only once a full interval has
  // passed since the last rotation, a time the script records on disk. So the
  // schedule is preserved no matter how often the widget is rebuilt.
  // triggeredOnStart makes it check the instant the widget (re)appears, so a
  // rotation that came due while the shell was down happens right away.
  Timer {
    interval: 60000
    repeat: true
    running: root.autoEnabled
    triggeredOnStart: true
    onTriggered: root.rotateIfDue()
  }

  IpcHandler {
    target: "io.github.keegan-sucks.wallpaper-roulette"

    function next(): void { root.rotateNow() }
    function pick(): void { root.openPicker() }
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
      + "\nClick: shuffle now · Right-click: choose a wallpaper"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.openPicker()
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
