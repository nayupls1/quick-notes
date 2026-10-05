import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar note icon + popup checklist. All file edits go through the
// `quick-notes` script so voice capture and the panel share one writer;
// the panel just watches the notes file and the capture state file.
Panel {
  id: root
  moduleName: "local.quick-notes"
  ipcTarget: "local.quick-notes"

  readonly property string home: Quickshell.env("HOME")
  readonly property string script: home + "/.local/bin/quick-notes"
  readonly property string notesFile: {
    var p = String(setting("notesFile", "") || Quickshell.env("QUICK_NOTES_FILE") || "")
    if (p === "") return home + "/notes/quick-notes.md"
    return p.startsWith("~/") ? home + p.slice(1) : p
  }
  readonly property string stateFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quick-notes/state"
  readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/quick-notes/config"
  property bool notificationsOn: true

  function parseConfig(raw) {
    var m = String(raw || "").match(/^notifications=(\w+)\s*$/gm)
    notificationsOn = !m || m[m.length - 1] !== "notifications=off"
  }
  readonly property string hotkey: String(setting("hotkey", "") || "")

  property var items: []          // [{ line, text, done }]
  property string captureState: "idle"
  readonly property int openCount: items.filter(function(i) { return !i.done }).length
  readonly property int doneCount: items.length - openCount
  readonly property bool busy: captureState === "recording" || captureState === "transcribing" || captureState === "thinking"

  function parse(raw) {
    var lines = String(raw || "").split("\n")
    var next = []
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*[-*] \[([ xX])\] (.*)$/)
      if (m) next.push({ line: i + 1, text: m[2], done: m[1] !== " " })
    }
    items = next
  }

  function run(args) {
    Quickshell.execDetached(["env", "QUICK_NOTES_FILE=" + notesFile, script].concat(args))
  }

  function statusText() {
    if (captureState === "recording") return "Listening…"
    if (captureState === "transcribing") return "Transcribing…"
    if (captureState === "thinking") return "Codex is writing notes…"
    if (items.length === 0) return hotkey !== "" ? "Hold " + hotkey + " to dictate" : "Right-click the icon to dictate"
    return openCount + " open · " + doneCount + " done"
  }

  // The notes file may not exist yet (or be replaced by `sed -i`), so
  // re-read it whenever the panel opens or a capture finishes.
  onOpenedChanged: if (opened) { input.text = ""; notesView.reload() }
  onCaptureStateChanged: if (captureState === "idle") notesView.reload()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    id: notesView
    path: root.notesFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.items = []
  }

  FileView {
    path: root.configFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseConfig(text())
    onLoadFailed: root.notificationsOn = true
  }

  FileView {
    path: root.stateFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.captureState = String(text() || "idle").trim()
    onLoadFailed: root.captureState = "idle"
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.captureState === "recording" ? "󰍬" : (root.busy ? "󰔟" : "󰎚")
    active: root.busy
    tooltipText: root.opened ? "" : root.statusText()
    onPressed: function(b) {
      if (b === Qt.RightButton) root.run(["start"])
      else if (b === Qt.MiddleButton) root.bar.run("xdg-open " + JSON.stringify(root.notesFile))
      else root.toggle()
    }

    SequentialAnimation on opacity {
      running: root.captureState === "recording"
      loops: Animation.Infinite
      onStopped: button.opacity = 1
      NumberAnimation { from: 1.0; to: 0.35; duration: 600; easing.type: Easing.InOutSine }
      NumberAnimation { from: 0.35; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: input
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      Item {
        width: parent.width
        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

        Text {
          id: heroIcon
          text: "󰎚"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.display
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          id: heroLabels
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.right: bell.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Quick notes"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: root.statusText().toUpperCase()
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            elide: Text.ElideRight
            width: parent.width
          }
        }

        Text {
          id: bell
          text: root.notificationsOn ? "󰂚" : "󰂛"
          color: root.bar.foreground
          opacity: bellMouse.containsMouse ? 1 : (root.notificationsOn ? 0.8 : 0.45)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter

          MouseArea {
            id: bellMouse
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.notificationsOn = !root.notificationsOn
              root.run(["notifications", root.notificationsOn ? "on" : "off"])
            }
          }

          PanelToolTip {
            visible: bellMouse.containsMouse
            text: root.notificationsOn ? "Notify when notes are added" : "Silent — errors only"
          }
        }
      }

      TextField {
        id: input
        width: parent.width
        placeholderText: "Type a note and press Enter"
        foreground: root.bar.foreground
        Keys.onEscapePressed: root.close()
        onAccepted: {
          var t = text.trim()
          if (t !== "") root.run(["add-raw", t])
          text = ""
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      Flickable {
        id: list
        width: parent.width
        height: Math.min(contentHeight, Style.space(420))
        contentHeight: itemsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: itemsColumn
          width: list.width
          spacing: Style.space(2)

          Text {
            visible: root.items.length === 0
            text: "No notes yet."
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.items

            Rectangle {
              id: row
              required property var modelData
              width: itemsColumn.width
              implicitHeight: Math.max(Style.spacing.popupRowHeight, label.implicitHeight + Style.space(8))
              radius: Style.cornerRadius
              color: rowMouse.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent, Color.urgent) : "transparent"

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(["toggle", String(row.modelData.line)])
              }

              Text {
                id: check
                text: row.modelData.done ? "󰄵" : "󰄱"
                color: root.bar.foreground
                opacity: row.modelData.done ? 0.5 : 1
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                anchors.left: parent.left
                anchors.leftMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: label
                text: row.modelData.text
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: root.bar.foreground
                opacity: row.modelData.done ? 0.45 : 1
                font.strikeout: row.modelData.done
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                anchors.left: check.right
                anchors.leftMargin: Style.space(10)
                anchors.right: removeBtn.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: removeBtn
                text: "󰅖"
                visible: rowMouse.containsMouse || removeMouse.containsMouse
                color: root.bar.foreground
                opacity: removeMouse.containsMouse ? 1 : 0.5
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                  id: removeMouse
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.run(["remove", String(row.modelData.line)])
                }
              }
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        readonly property real cellWidth: (width - spacing * 2) / 3

        Button {
          width: parent.cellWidth
          iconText: root.captureState === "recording" ? "󰓛" : "󰍬"
          text: root.captureState === "recording" ? "Stop" : "Dictate"
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          active: root.captureState === "recording"
          onClicked: root.run([root.captureState === "recording" ? "stop" : "start"])
        }

        Button {
          width: parent.cellWidth
          iconText: "󰃢"
          text: "Clear done"
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          enabled: root.doneCount > 0
          onClicked: root.run(["clear-done"])
        }

        Button {
          width: parent.cellWidth
          iconText: "󰏫"
          text: "Open file"
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          onClicked: {
            root.close()
            root.bar.run("xdg-open " + JSON.stringify(root.notesFile))
          }
        }
      }
    }
  }
}
