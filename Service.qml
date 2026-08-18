import QtQuick
import Quickshell
import Quickshell.Io

// One cava process for every bar surface. Widgets read `levels` (0..1).
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string runtimeDir: {
    var dir = Quickshell.env("XDG_RUNTIME_DIR")
    if (dir && dir.length) return dir + "/my-cava"
    var user = Quickshell.env("USER")
    return "/tmp/my-cava-" + (user && user.length ? user : "user")
  }
  readonly property string configPath: runtimeDir + "/config"

  property int bars: 10
  property int framerate: 30
  property var levels: []
  property bool available: false
  property bool playing: false
  property string lastError: ""
  property bool expectStop: false

  readonly property real silenceThreshold: 0.03

  function clampInt(value, fallback, min, max) {
    var n = Number(value)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, Math.round(n)))
  }

  function applySettings(settings) {
    var nextBars = clampInt(settings && settings.bars, bars, 4, 64)
    var nextFps = clampInt(settings && settings.framerate, framerate, 10, 60)
    if (nextBars === bars && nextFps === framerate && cavaProc.running)
      return
    bars = nextBars
    framerate = nextFps
    restart()
  }

  function configText() {
    return "[general]\n"
      + "framerate = " + framerate + "\n"
      + "bars = " + bars + "\n"
      + "autosens = 1\n"
      + "sensitivity = 100\n"
      + "lower_cutoff_freq = 50\n"
      + "higher_cutoff_freq = 10000\n"
      + "sleep_timer = 3\n"
      + "\n"
      + "[output]\n"
      + "method = raw\n"
      + "raw_target = /dev/stdout\n"
      + "data_format = ascii\n"
      + "ascii_max_range = 1000\n"
      + "bar_delimiter = 59\n"
      + "frame_delimiter = 10\n"
      + "channels = mono\n"
      + "\n"
      + "[smoothing]\n"
      + "monstercat = 0\n"
      + "waves = 0\n"
      + "noise_reduction = 77\n"
  }

  function parseFrame(line) {
    var parts = String(line).split(";")
    var next = []
    var loud = false
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] === "") continue
      var n = Number(parts[i])
      if (!isFinite(n)) n = 0
      var level = Math.max(0, Math.min(1, n / 1000))
      next.push(level)
      if (level >= silenceThreshold) loud = true
    }
    if (next.length === 0) return
    levels = next
    if (loud) {
      playing = true
      silenceTimer.restart()
    }
  }

  function restart() {
    restartTimer.restart()
  }

  function startCava() {
    expectStop = cavaProc.running
    if (cavaProc.running) cavaProc.running = false
    writeConfig.command = [
      "python3", "-c",
      "import pathlib, sys; p = pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True); p.write_text(sys.argv[2])",
      configPath,
      configText()
    ]
    writeConfig.running = true
  }

  Component.onCompleted: startCava()
  Component.onDestruction: {
    expectStop = true
    cavaProc.running = false
  }

  Timer {
    id: silenceTimer
    interval: 450
    onTriggered: root.playing = false
  }

  Timer {
    id: restartTimer
    interval: 80
    onTriggered: root.startCava()
  }

  Timer {
    id: backoff
    interval: 1000
    onTriggered: if (!cavaProc.running) root.startCava()
  }

  Process {
    id: writeConfig
    onExited: function(code) {
      if (code !== 0) {
        root.lastError = "failed to write cava config"
        backoff.restart()
        return
      }
      cavaProc.running = true
    }
  }

  Process {
    id: cavaProc
    command: ["cava", "-p", root.configPath]
    stdout: SplitParser {
      onRead: function(line) { root.parseFrame(line) }
    }
    stderr: SplitParser {
      onRead: function(line) {
        var text = String(line).replace(/^\s+|\s+$/g, "")
        if (text.length) root.lastError = text
      }
    }
    onRunningChanged: if (running) {
      root.available = true
      backoff.interval = 1000
    }
    onExited: function() {
      root.playing = false
      if (root.expectStop) {
        root.expectStop = false
        return
      }
      root.available = false
      backoff.interval = Math.min(8000, Math.max(1000, backoff.interval * 2))
      backoff.restart()
    }
  }
}
