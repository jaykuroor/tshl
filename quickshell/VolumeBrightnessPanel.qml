import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: root

  required property var modelData
  property var controller

  // The reveal band and the drawer are the same rectangle: middle third of the
  // screen, hard against the right edge. One rect to mask, one rect to punch
  // out of the dismiss layer, and no dead strip between the two.
  readonly property int bandHeight: Math.round(modelData.height / 3)
  readonly property int barWidth: Theme.spaceXxl
  readonly property int drawerWidth: Theme.spaceSm * 3 + barWidth * 2

  // Dismissal delays are interaction timings rather than motion, so they are
  // multiples of the slowest motion token rather than tokens themselves.
  readonly property int hideDelay: Theme.slow * 4    // ~1.3s grace after the cursor leaves
  readonly property int dwellDelay: Theme.fast       // 120ms of contact = intent, not a brush

  property bool expanded: false
  property bool dragging: false
  property string osdMetric: "volume"
  property int volumeValue: 0
  property int brightnessValue: 0
  property bool volumeDirty: false
  property bool brightnessDirty: false

  // the two presentations are mutually exclusive: whichever opens closes the other
  onExpandedChanged: if (expanded) {
    refresh();
    osd.dismiss();
  }

  function clampPercent(value) {
    return Math.max(0, Math.min(100, value));
  }

  function refresh() {
    volumeQuery.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    brightnessQuery.exec(["brightnessctl", "--class=backlight", "info"]);
  }

  function setVolume(value) {
    volumeValue = clampPercent(value);
    volumeDirty = true;
    if (!volumeSetTimer.running) {
      volumeSetTimer.start();
    }
  }

  function setBrightness(value) {
    brightnessValue = Math.max(1, clampPercent(value));
    brightnessDirty = true;
    if (!brightnessSetTimer.running) {
      brightnessSetTimer.start();
    }
  }

  Connections {
    target: root.controller

    function onRevealControls(metric) {
      root.osdMetric = metric === "brightness" ? "brightness" : "volume";
      root.expanded = false;
      root.refresh();
      osd.reveal();
    }
  }

  Process {
    id: volumeQuery
    stdout: StdioCollector {
      id: volumeStdout
      waitForEnd: true
    }
    onExited: {
      var match = volumeStdout.text.match(/Volume:\s*([0-9.]+)/);
      if (match) {
        root.volumeValue = root.clampPercent(Math.round(parseFloat(match[1]) * 100));
      }
    }
  }

  Process {
    id: brightnessQuery
    stdout: StdioCollector {
      id: brightnessStdout
      waitForEnd: true
    }
    onExited: {
      var match = brightnessStdout.text.match(/Current brightness:\s*\d+\s*\((\d+)%\)/);
      if (match) {
        root.brightnessValue = root.clampPercent(parseInt(match[1]));
      }
    }
  }

  Timer {
    id: volumeSetTimer
    interval: 45
    onTriggered: {
      if (root.volumeDirty) {
        root.volumeDirty = false;
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (root.volumeValue / 100).toFixed(2), "-l", "1.0"]);
        volumeRefreshTimer.restart();
      }
    }
  }

  Timer {
    id: brightnessSetTimer
    interval: 45
    onTriggered: {
      if (root.brightnessDirty) {
        root.brightnessDirty = false;
        Quickshell.execDetached(["brightnessctl", "--class=backlight", "set", root.brightnessValue + "%"]);
        brightnessRefreshTimer.restart();
      }
    }
  }

  Timer {
    id: volumeRefreshTimer
    interval: 120
    onTriggered: volumeQuery.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
  }

  Timer {
    id: brightnessRefreshTimer
    interval: 120
    onTriggered: brightnessQuery.exec(["brightnessctl", "--class=backlight", "info"])
  }

  Timer {
    id: dwellTimer
    interval: root.dwellDelay
    onTriggered: root.expanded = true
  }

  Timer {
    id: hideTimer
    interval: root.hideDelay
    onTriggered: if (!root.dragging)
      root.expanded = false
  }

  // Fixed size, always mapped. Nothing here is ever resized while animating:
  // the drawer slides inside a window whose geometry never changes, because a
  // Wayland surface resize per frame is what made the old version chop.
  PanelWindow {
    id: drawerWindow
    screen: root.modelData
    anchors.right: true
    implicitWidth: root.drawerWidth
    implicitHeight: root.bandHeight
    color: "transparent"
    aboveWindows: true
    focusable: false
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    // Collapsed, the only live pixels on this surface are a sliver at the very
    // edge inside the band; everything else on screen clicks straight through.
    mask: Region {
      item: root.expanded ? content : hotZone
    }

    Item {
      id: content
      anchors.fill: parent
      clip: true

      Item {
        id: hotZone
        anchors {
          right: parent.right
          top: parent.top
          bottom: parent.bottom
        }
        width: Theme.spaceXs

        // HoverHandler rather than MouseArea: it does not claim the cursor shape
        HoverHandler {
          enabled: !root.expanded
          onHoveredChanged: hovered ? dwellTimer.restart() : dwellTimer.stop()
        }
      }

      Rectangle {
        id: drawer
        width: root.drawerWidth
        height: parent.height
        // parked fully past the right edge, so the collapsed state draws nothing
        x: root.expanded ? 0 : width
        color: Theme.bg

        Behavior on x {
          NumberAnimation {
            duration: Theme.base
            easing.type: Theme.easing
          }
        }

        HoverHandler {
          enabled: root.expanded
          onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart()
        }

        Rectangle {
          width: Theme.border
          color: Theme.fg
          anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
          }
        }

        Rectangle {
          width: Theme.border
          color: Theme.fg
          anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
          }
        }

        Rectangle {
          height: Theme.border
          color: Theme.fg
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
          }
        }

        Rectangle {
          height: Theme.border
          color: Theme.fg
          anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
          }
        }

        Row {
          anchors.centerIn: parent
          spacing: Theme.spaceSm

          MetricControlBar {
            width: root.barWidth
            height: drawer.height - Theme.spaceSm * 2
            icon: ")))"
            value: root.volumeValue
            onInteractionStarted: {
              root.dragging = true;
              hideTimer.stop();
            }
            onInteractionFinished: {
              root.dragging = false;
              hideTimer.restart();
            }
            onRequestedValue: value => root.setVolume(value)
          }

          MetricControlBar {
            width: root.barWidth
            height: drawer.height - Theme.spaceSm * 2
            icon: "*"
            value: root.brightnessValue
            onInteractionStarted: {
              root.dragging = true;
              hideTimer.stop();
            }
            onInteractionFinished: {
              root.dragging = false;
              hideTimer.restart();
            }
            onRequestedValue: value => root.setBrightness(value)
          }
        }
      }
    }
  }

  // Outside-click catcher. Only mapped while the drawer is open, so the closed
  // state has no full-screen surface at all. Layer-shell gives no stacking
  // guarantee between two surfaces on the same layer, so the drawer's rect is
  // punched out of this one's input region rather than trusted to sit on top.
  PanelWindow {
    id: dismissLayer
    visible: root.expanded
    screen: root.modelData
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    aboveWindows: true
    focusable: false
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      width: dismissLayer.width
      height: dismissLayer.height

      Region {
        intersection: Intersection.Subtract
        // padded by one grid step: the compositor centres the drawer window
        // itself, so its y can land a pixel off what is computed here
        x: dismissLayer.width - root.drawerWidth - Theme.spaceXs
        y: Math.round((dismissLayer.height - root.bandHeight) / 2) - Theme.spaceXs
        width: root.drawerWidth + Theme.spaceXs
        height: root.bandHeight + Theme.spaceXs * 2
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: root.expanded = false
    }
  }

  MetricOsd {
    id: osd
    modelData: root.modelData
    icon: root.osdMetric === "volume" ? ")))" : "*"
    value: root.osdMetric === "volume" ? root.volumeValue : root.brightnessValue
    onRequestedValue: value => root.osdMetric === "volume" ? root.setVolume(value) : root.setBrightness(value)
  }
}
