import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "my.cava"

  property bool popupOpen: false

  readonly property var cava: bar && bar.shell ? bar.shell.serviceFor("my.cava") : null
  readonly property int barCount: clampInt(setting("bars", 10), 10, 4, 64)
  readonly property int stroke: clampInt(setting("barWidth", 3), 3, 1, 8)
  readonly property int gap: clampInt(setting("gap", 2), 2, 0, 8)
  readonly property int fps: clampInt(setting("framerate", 30), 30, 10, 60)
  readonly property int padding: 8
  readonly property var levels: cava && cava.levels ? cava.levels : []
  readonly property bool playing: cava ? cava.playing === true : false
  readonly property color barColor: bar ? bar.barForeground : Color.bar.text
  readonly property color idleColor: bar ? bar.background : Color.bar.background
  readonly property int span: barCount * stroke + Math.max(0, barCount - 1) * gap
  readonly property int track: Math.max(4, (vertical ? width : height) - 8)
  readonly property bool opened: popupOpen
  readonly property string currentSection: sectionFromLayout(bar ? bar.layoutConfig : null)

  implicitWidth: vertical ? barSize : span + padding * 2
  implicitHeight: vertical ? span + padding * 2 : barSize

  function clampInt(value, fallback, min, max) {
    var n = Number(value)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, Math.round(n)))
  }

  function levelAt(index) {
    if (index < 0 || index >= levels.length) return 0
    var n = Number(levels[index])
    return isFinite(n) ? Math.max(0, Math.min(1, n)) : 0
  }

  function syncService() {
    if (!cava || typeof cava.applySettings !== "function") return
    cava.applySettings({ bars: barCount, framerate: fps })
  }

  function persist(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) {
      if (k !== "id") entry[k] = root.settings[k]
    }
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function sectionFromLayout(layout) {
    if (!layout) return ""
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]]
      if (!entries) continue
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i]
        var id = (entry && typeof entry === "object") ? String(entry.id || "") : String(entry || "")
        if (id === root.moduleName) return sections[s]
      }
    }
    return ""
  }

  function moveTo(section) {
    if (["left", "center", "right"].indexOf(section) === -1) return
    if (section === root.currentSection) return
    root.close()
    var registry = root.bar && root.bar.shell ? root.bar.shell.pluginRegistry : null
    if (registry && typeof registry.moveBarWidget === "function") {
      registry.moveBarWidget(root.moduleName, { section: section })
      return
    }
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run("omarchy bar move " + root.moduleName + " --section " + section)
  }

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { popupOpen = !popupOpen }
  function closeForPopoutSwitch() { popupOpen = false }

  onCavaChanged: syncService()
  onBarCountChanged: syncService()
  onFpsChanged: syncService()
  Component.onCompleted: syncService()

  Row {
    visible: !root.vertical
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: root.gap
    height: root.track

    Repeater {
      model: root.barCount

      Rectangle {
        required property int index
        width: root.stroke
        height: root.playing ? Math.max(1, Math.round(root.track * root.levelAt(index))) : 0
        anchors.bottom: parent.bottom
        color: root.playing ? root.barColor : root.idleColor
      }
    }
  }

  Column {
    visible: root.vertical
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.gap
    width: root.track

    Repeater {
      model: root.barCount

      Rectangle {
        required property int index
        height: root.stroke
        width: root.playing ? Math.max(1, Math.round(root.track * root.levelAt(index))) : 0
        anchors.left: parent.left
        color: root.playing ? root.barColor : root.idleColor
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle()
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(240))
    contentHeight: popup.fittedContentHeight(Math.max(menuColumn.childrenRect.height, Style.space(280)))

    Column {
      id: menuColumn
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "Cava"
        color: root.bar ? root.bar.foreground : Color.bar.text
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      NumberField {
        width: parent.width
        label: "Bars"
        value: root.barCount
        from: 4
        to: 64
        foreground: root.bar ? root.bar.foreground : Color.bar.text
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onModified: function(value) { root.persist("bars", value) }
      }

      NumberField {
        width: parent.width
        label: "Bar width"
        value: root.stroke
        from: 1
        to: 8
        foreground: root.bar ? root.bar.foreground : Color.bar.text
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onModified: function(value) { root.persist("barWidth", value) }
      }

      NumberField {
        width: parent.width
        label: "Gap"
        value: root.gap
        from: 0
        to: 8
        foreground: root.bar ? root.bar.foreground : Color.bar.text
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onModified: function(value) { root.persist("gap", value) }
      }

      Text {
        text: "Position"
        color: Qt.darker(root.bar ? root.bar.foreground : Color.bar.text, 1.4)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Button {
        width: parent.width
        text: "Left"
        selected: root.currentSection === "left"
        bordered: true
        foreground: root.bar ? root.bar.foreground : Color.bar.text
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onClicked: root.moveTo("left")
      }

      Button {
        width: parent.width
        text: "Center"
        selected: root.currentSection === "center"
        bordered: true
        foreground: root.bar ? root.bar.foreground : Color.bar.text
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onClicked: root.moveTo("center")
      }

      Button {
        width: parent.width
        text: "Right"
        selected: root.currentSection === "right"
        bordered: true
        foreground: root.bar ? root.bar.foreground : Color.bar.text
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onClicked: root.moveTo("right")
      }
    }
  }
}
