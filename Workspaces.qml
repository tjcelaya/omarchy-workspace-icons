import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspace switcher that renders "1: [icons] | 2: [icons] | 3: | ..." — each workspace
// number followed by the icons of the windows on it. Window-to-icon resolution runs in
// bin/wsicons-state (desktop entries, Omarchy webapps, the program inside terminals); this
// file turns its icon names into image paths with the same themed lookup the launcher uses.
BarWidget {
  id: root
  moduleName: "tjcelaya.workspace-icons"

  readonly property string stateScript: {
    var url = String(Qt.resolvedUrl("bin/wsicons-state"))
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  readonly property string separator: String(root.setting("separator", "|"))
  readonly property bool dedupe: root.setting("dedupe", true) !== false
  readonly property int pollSec: Math.max(1, Number(root.setting("pollSec", 3)) || 3)
  readonly property int iconSize: Math.max(10, Number(root.setting("iconSize", 14)) || 14)
  readonly property var persistentIds: parseIds(String(root.setting("persistentWorkspaces", "1-5")))
  readonly property color textColor: bar && bar.barForeground ? bar.barForeground : Color.bar.text
  readonly property color activeColor: bar && bar.urgent ? bar.urgent : Color.bar.active

  // [{ws, class, title, program, icon, glyph}] from the last helper run.
  property var windows: []

  function parseIds(raw) {
    var ids = []
    var parts = raw.split(/[,\s]+/)
    for (var i = 0; i < parts.length; i++) {
      var range = parts[i].match(/^(\d+)(?:-(\d+))?$/)
      if (!range) continue
      var first = Number(range[1])
      var last = range[2] ? Number(range[2]) : first
      for (var id = first; id <= last && id <= 99; id++) {
        if (ids.indexOf(id) === -1) ids.push(id)
      }
    }
    return ids
  }

  function workspaceIds() {
    var ids = root.persistentIds.slice()
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && ids.indexOf(id) === -1) ids.push(id)
    }
    for (var j = 0; j < root.windows.length; j++) {
      var ws = root.windows[j].ws
      if (ws > 0 && ids.indexOf(ws) === -1) ids.push(ws)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    if (value.length > 0) {
      var themed = Quickshell.iconPath(value, true)
      if (themed.length > 0) return themed
    }
    return ""
  }

  // Image source or glyph for a window: {source, glyph}.
  function windowIcon(w) {
    if (w.glyph) return { source: "", glyph: w.glyph }
    var source = root.iconSource(w.icon)
    if (source === "") {
      var entry = DesktopEntries.heuristicLookup(w["class"])
      source = entry ? root.iconSource(entry.icon) : ""
    }
    if (source === "") source = Quickshell.iconPath("application-x-executable", true)
    return { source: source, glyph: "" }
  }

  function windowsOn(ws) {
    return root.windows.filter(function(w) { return w.ws === ws })
  }

  // Bar icons for one workspace, in window order, one per distinct icon when deduping.
  function iconsFor(ws) {
    var items = []
    var seen = ({})
    var list = root.windowsOn(ws)
    for (var i = 0; i < list.length; i++) {
      var item = root.windowIcon(list[i])
      var key = item.glyph || item.source
      if (root.dedupe && seen[key]) continue
      seen[key] = true
      items.push(item)
    }
    return items
  }

  // Hover panel rows for one workspace: each window, then the agents inside it.
  function rowsFor(ws) {
    var rows = []
    var list = root.windowsOn(ws)
    for (var i = 0; i < list.length; i++) {
      var w = list[i]
      var icon = root.windowIcon(w)
      rows.push({ kind: "window", source: icon.source, glyph: icon.glyph, address: w.address,
                  title: w.title || w["class"], subtitle: w.program || "" , status: "", focus: [] })
      var agents = w.agents || []
      for (var j = 0; j < agents.length; j++) {
        var a = agents[j]
        var dir = String(a.cwd || "").replace(/\/$/, "").split("/").pop() || a.cwd
        rows.push({ kind: "agent", source: "", glyph: a.status === "working" ? "\uDB81\uDC6E" : "\uDB80\uDD8D",
                    address: "", title: a.agent + " · " + dir, subtitle: [a.cwd, a.status, a.pane].filter(function(x) { return x }).join(" · "),
                    status: a.status || "", focus: a.focus || [] })
      }
    }
    return rows
  }

  function focusWindow(address) {
    if (!root.bar || !address) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ window = \"address:" + address + "\" })")
      + " >/dev/null 2>&1 || hyprctl dispatch focuswindow " + Util.shellQuote("address:" + address))
  }

  function activateRow(row) {
    if (row.kind === "agent" && row.focus.length > 0) Quickshell.execDetached(row.focus)
    else root.focusWindow(row.address)
    root.hoverCell = null
    root.panelCell = null
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function refresh() {
    if (stateProc.running) {
      refreshAgain = true
      return
    }
    stateProc.running = true
  }

  property bool refreshAgain: false

  // Workspace cell under the pointer. The panel stays while the cell or the panel is hovered.
  property Item hoverCell: null
  property Item panelCell: null
  readonly property var panelRows: panelCell ? root.rowsFor(panelCell.ws) : []

  onHoverCellChanged: {
    if (hoverCell) { panelCell = hoverCell; panelClose.stop() }
    else panelClose.restart()
  }

  Timer {
    id: panelClose
    interval: 250
    onTriggered: if (!root.hoverCell && !panelHover.hovered) root.panelCell = null
  }

  PopupWindow {
    id: panelWindow
    visible: root.panelCell !== null && root.panelRows.length > 0
    color: "transparent"
    implicitWidth: Math.ceil(panelBubble.implicitWidth)
    implicitHeight: Math.ceil(panelBubble.implicitHeight)

    anchor {
      item: root.panelCell
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: root.bar && root.bar.position === "bottom" ? (Edges.Top | Edges.Right) : (Edges.Bottom | Edges.Right)
      rect.x: 0
      rect.y: root.bar && root.bar.position === "bottom" ? -4 : (root.panelCell ? root.panelCell.height + 4 : 0)
      rect.width: 1
      rect.height: 1
    }

    BorderSurface {
      id: panelBubble
      implicitWidth: panelColumn.implicitWidth + 16
      implicitHeight: panelColumn.implicitHeight + 12
      color: Color.tooltip.background
      borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
      radius: Style.cornerRadius

      HoverHandler {
        id: panelHover
        onHoveredChanged: if (!hovered) panelClose.restart()
      }

      Column {
        id: panelColumn
        anchors.centerIn: parent
        spacing: 2

        Repeater {
          model: root.panelRows

          Rectangle {
            id: row
            required property var modelData
            readonly property bool agent: modelData.kind === "agent"
            readonly property real indent: agent ? 8 + root.iconSize + 8 : 8
            readonly property real textWidth: Math.min(Math.max(titleText.implicitWidth, subtitleText.visible ? subtitleText.implicitWidth : 0), 360)
            width: indent + rowContent.implicitWidth + 8
            height: rowContent.implicitHeight + 8
            radius: Style.cornerRadius / 2
            color: rowArea.containsMouse ? Qt.rgba(Color.tooltip.text.r, Color.tooltip.text.g, Color.tooltip.text.b, 0.12) : "transparent"

            RowLayout {
              id: rowContent
              anchors.left: parent.left
              anchors.leftMargin: row.indent
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8

              Item {
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize
                Image {
                  anchors.fill: parent
                  visible: row.modelData.glyph === ""
                  source: row.modelData.source
                  sourceSize.width: root.iconSize * 2
                  sourceSize.height: root.iconSize * 2
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }
                Text {
                  anchors.centerIn: parent
                  visible: row.modelData.glyph !== ""
                  text: row.modelData.glyph
                  color: row.modelData.status === "working" ? root.activeColor : Color.tooltip.text
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: root.iconSize
                }
              }

              ColumnLayout {
                spacing: 1
                Layout.preferredWidth: row.textWidth
                Text {
                  id: titleText
                  Layout.preferredWidth: row.textWidth
                  textFormat: Text.PlainText
                  text: row.modelData.title
                  elide: Text.ElideRight
                  color: Color.tooltip.text
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                }
                Text {
                  id: subtitleText
                  Layout.preferredWidth: row.textWidth
                  visible: row.modelData.subtitle !== ""
                  textFormat: Text.PlainText
                  text: row.modelData.subtitle
                  elide: Text.ElideRight
                  color: Color.tooltip.text
                  opacity: 0.6
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activateRow(row.modelData)
            }
          }
        }
      }
    }
  }

  Process {
    id: stateProc
    command: [
      "python3", root.stateScript,
      "--terminals", String(root.setting("terminalClasses", "foot,footclient,Alacritty,kitty,com.mitchellh.ghostty")),
      "--programs", String(root.setting("programIcons", "")),
      "--agent-icon", String(root.setting("agentIcon", "\uDB81\uDE74"))
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.windows = JSON.parse(text).windows || []
        } catch (e) {
          console.warn("workspace-icons: bad helper output:", e)
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) console.warn("workspace-icons: helper exited with", code)
      if (root.refreshAgain) {
        root.refreshAgain = false
        root.refresh()
      }
    }
  }

  // Window events refresh quickly; the timer catches programs starting or exiting inside a
  // terminal, which Hyprland does not report.
  Timer {
    id: eventDebounce
    interval: 120
    onTriggered: root.refresh()
  }

  Timer {
    interval: root.pollSec * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      switch (event.name) {
      case "openwindow":
      case "closewindow":
      case "movewindow":
      case "movewindowv2":
      case "windowtitle":
      case "windowtitlev2":
      case "activewindow":
      case "createworkspace":
      case "destroyworkspace":
        eventDebounce.restart()
      }
    }
  }

  Component.onCompleted: root.refresh()

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rows: root.vertical ? -1 : 1
    columns: root.vertical ? 1 : -1
    columnSpacing: 0
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      RowLayout {
        id: group
        required property int modelData
        required property int index

        readonly property var icons: root.iconsFor(modelData)
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property bool occupied: icons.length > 0

        spacing: 0

        Text {
          visible: !root.vertical && group.index > 0 && root.separator.length > 0
          text: root.separator
          color: root.textColor
          opacity: 0.35
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          Layout.leftMargin: Style.spaceReal(1)
          Layout.rightMargin: Style.spaceReal(1)
        }

        WidgetButton {
          id: cell
          bar: root.bar
          text: ""
          labelVisible: false
          hasVisualContent: true
          useActiveColor: false
          dimmed: !group.occupied && !group.focused
          // The bar's shared tooltip is centered plain text; this widget shows its own panel.
          tooltipText: ""
          readonly property int ws: group.modelData
          onTooltipHoveredChanged: {
            if (tooltipHovered) root.hoverCell = cell
            else if (root.hoverCell === cell) root.hoverCell = null
          }
          fixedWidth: root.vertical ? root.barSize : content.implicitWidth + Style.spaceReal(3) * 2
          fixedHeight: root.vertical ? content.implicitHeight + Style.spaceReal(2) * 2 : root.barSize
          onPressed: function() { root.focusWorkspace(group.modelData) }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Style.spaceReal(2)
            anchors.rightMargin: Style.spaceReal(2)
            height: 2
            radius: 1
            color: root.activeColor
            visible: group.focused && !root.vertical
          }

          GridLayout {
            id: content
            anchors.centerIn: parent
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            columnSpacing: Style.spaceReal(1.5)
            rowSpacing: Style.spaceReal(1)

            Text {
              text: (group.modelData === 10 ? "0" : String(group.modelData)) + (root.vertical ? "" : ":")
              color: group.focused ? root.activeColor : root.textColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: group.focused
              Layout.alignment: Qt.AlignCenter
            }

            Repeater {
              model: group.icons

              Item {
                required property var modelData
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize
                Layout.alignment: Qt.AlignCenter

                Image {
                  anchors.fill: parent
                  visible: modelData.glyph === ""
                  source: modelData.source
                  sourceSize.width: root.iconSize * 2
                  sourceSize.height: root.iconSize * 2
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  asynchronous: true
                }

                Text {
                  anchors.centerIn: parent
                  visible: modelData.glyph !== ""
                  text: modelData.glyph
                  color: root.textColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: root.iconSize
                }
              }
            }
          }
        }
      }
    }
  }
}
