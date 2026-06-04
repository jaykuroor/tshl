import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
  id: controlsPanel
  required property var modelData
  property var controller

  screen: modelData
  anchors {
    top: true
    right: true
  }
  margins {
    top: Math.max(42, Math.round((modelData.height - panelHeight) / 2))
  }
  implicitWidth: animatedWidth
  implicitHeight: panelHeight
  color: "transparent"
  aboveWindows: true
  focusable: false
  exclusiveZone: 0
  exclusionMode: ExclusionMode.Ignore

  property int triggerWidth: 5
  property int panelHeight: 194
  property int barWidth: 34
  property int barSpacing: 8
  property int drawerPadding: 8
  property int shownBars: visibleMetric === "both" ? 2 : 1
  property int drawerWidth: drawerPadding * 2 + shownBars * barWidth + (shownBars - 1) * barSpacing
  property real animatedWidth: expanded ? drawerWidth : triggerWidth
  property bool expanded: false
  property bool dragging: false
  property string visibleMetric: "both"
  property int volumeValue: 0
  property int brightnessValue: 0
  property bool volumeDirty: false
  property bool brightnessDirty: false

  function clampPercent(value) {
    return Math.max(0, Math.min(100, value));
  }

  function showMetric(metric) {
    visibleMetric = metric === "volume" || metric === "brightness" ? metric : "both";
    expanded = true;
    refreshVisible();
    hideTimer.restart();
  }

  function hideIfIdle() {
    if (!dragging && !panelMouse.containsMouse) {
      expanded = false;
    }
  }

  function refreshVisible() {
    if (visibleMetric !== "brightness") {
      volumeQuery.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }
    if (visibleMetric !== "volume") {
      brightnessQuery.exec(["brightnessctl", "--class=backlight", "info"]);
    }
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

  Behavior on animatedWidth {
    NumberAnimation {
      duration: 190
      easing.type: Easing.OutCubic
    }
  }

  Connections {
    target: controlsPanel.controller
    function onRevealControls(metric) {
      controlsPanel.showMetric(metric);
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
        controlsPanel.volumeValue = controlsPanel.clampPercent(Math.round(parseFloat(match[1]) * 100));
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
        controlsPanel.brightnessValue = controlsPanel.clampPercent(parseInt(match[1]));
      }
    }
  }

  Timer {
    id: volumeSetTimer
    interval: 45
    onTriggered: {
      if (controlsPanel.volumeDirty) {
        controlsPanel.volumeDirty = false;
        Quickshell.execDetached([
          "wpctl",
          "set-volume",
          "@DEFAULT_AUDIO_SINK@",
          (controlsPanel.volumeValue / 100).toFixed(2),
          "-l",
          "1.0"
        ]);
        volumeRefreshTimer.restart();
      }
    }
  }

  Timer {
    id: brightnessSetTimer
    interval: 45
    onTriggered: {
      if (controlsPanel.brightnessDirty) {
        controlsPanel.brightnessDirty = false;
        Quickshell.execDetached([
          "brightnessctl",
          "--class=backlight",
          "set",
          controlsPanel.brightnessValue + "%"
        ]);
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
    id: hideTimer
    interval: 1250
    onTriggered: controlsPanel.hideIfIdle()
  }

  Item {
    anchors.fill: parent
    clip: true

    MouseArea {
      id: panelMouse
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        if (controlsPanel.animatedWidth <= controlsPanel.triggerWidth + 1) {
          controlsPanel.showMetric("both");
        } else {
          hideTimer.stop();
        }
      }
      onExited: hideTimer.restart()
    }

    Rectangle {
      id: drawer
      x: controlsPanel.animatedWidth - width
      width: controlsPanel.drawerWidth
      height: parent.height
      color: "black"

      property real outlineWidth: 1.8

      Rectangle {
        width: drawer.outlineWidth
        color: "white"
        anchors {
          left: parent.left
          top: parent.top
          bottom: parent.bottom
        }
      }

      Rectangle {
        height: drawer.outlineWidth
        color: "white"
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
      }

      Rectangle {
        height: drawer.outlineWidth
        color: "white"
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
        }
      }

      Rectangle {
        width: drawer.outlineWidth
        color: "white"
        anchors {
          right: parent.right
          top: parent.top
          bottom: parent.bottom
        }
      }

      Row {
        anchors.centerIn: parent
        spacing: controlsPanel.barSpacing

        MetricControlBar {
          visible: controlsPanel.visibleMetric !== "brightness"
          width: visible ? controlsPanel.barWidth : 0
          height: 170
          icon: ")))"
          value: controlsPanel.volumeValue
          active: controlsPanel.visibleMetric === "volume"
          onInteractionStarted: {
            controlsPanel.dragging = true;
            hideTimer.stop();
          }
          onInteractionFinished: {
            controlsPanel.dragging = false;
            hideTimer.restart();
          }
          onRequestedValue: function(value) {
            controlsPanel.setVolume(value);
          }
        }

        MetricControlBar {
          visible: controlsPanel.visibleMetric !== "volume"
          width: visible ? controlsPanel.barWidth : 0
          height: 170
          icon: "*"
          value: controlsPanel.brightnessValue
          active: controlsPanel.visibleMetric === "brightness"
          onInteractionStarted: {
            controlsPanel.dragging = true;
            hideTimer.stop();
          }
          onInteractionFinished: {
            controlsPanel.dragging = false;
            hideTimer.restart();
          }
          onRequestedValue: function(value) {
            controlsPanel.setBrightness(value);
          }
        }
      }
    }
  }
}
