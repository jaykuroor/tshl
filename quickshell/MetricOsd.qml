import Quickshell
import QtQuick

// Key-driven heads-up display: one metric instead of two. Deliberately built
// the same way as the drawer in VolumeBrightnessPanel — same band height, same
// padding, same MetricControlBar, same slide — so the two presentations read as
// one component showing a different number of columns, not as two designs.
PanelWindow {
  id: osd

  required property var modelData
  // passed in rather than recomputed, so it cannot drift from the drawer's
  required property int bandHeight
  property string icon: "?"
  property int value: 0

  property bool open: false
  readonly property int boxWidth: Theme.spaceMd * 2 + Theme.spaceXxl
  readonly property int dismissDelay: Theme.slow * 6  // ~1.9s from the last key press

  signal requestedValue(int value)

  function reveal() {
    open = true;
    dismissTimer.restart();
  }

  function dismiss() {
    dismissTimer.stop();
    open = false;
  }

  screen: modelData
  anchors.right: true
  implicitWidth: boxWidth
  implicitHeight: bandHeight
  color: "transparent"
  aboveWindows: true
  focusable: false
  // Deliberately no exclusiveZone here. In Quickshell setting one defeats
  // ExclusionMode.Ignore: the surface stops reserving space but is still
  // pushed out of other surfaces' exclusive zones, which shoved this off
  // vertical centre by exactly the height of the bars above it.
  exclusionMode: ExclusionMode.Ignore

  // Closed, the input region is empty and the box is parked off-screen behind
  // the clip, so the surface stays mapped but is neither visible nor clickable.
  // Dismissal is on the timer only: an outside-click catcher would mean a
  // full-screen input region for the whole delay after every media keypress,
  // eating the next click anywhere on screen.
  // Knob: for outside-click dismissal, mask this full-screen while open and add
  // a MouseArea behind the box that calls dismiss().
  mask: Region {
    item: osd.open ? box : nullZone
  }

  Item {
    id: nullZone
    width: 0
    height: 0
  }

  Timer {
    id: dismissTimer
    interval: osd.dismissDelay
    onTriggered: osd.dismiss()
  }

  Item {
    anchors.fill: parent
    clip: true

    Rectangle {
      id: box
      width: osd.boxWidth
      height: parent.height
      // parked fully past the right edge when closed
      x: osd.open ? 0 : width
      color: Theme.bg

      Behavior on x {
        NumberAnimation {
          duration: Theme.base
          easing.type: Theme.easing
        }
      }

      // No right border: the box is hard against the screen edge, so an outline
      // there would draw a seam down the side of the display rather than close
      // the shape. Left, top and bottom only — it reads as emerging from the
      // edge, which is also what the slide is saying.
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

      MetricControlBar {
        anchors.centerIn: parent
        width: Theme.spaceXxl
        height: parent.height - Theme.spaceMd * 2
        icon: osd.icon
        value: osd.value
        onInteractionStarted: dismissTimer.stop()
        onInteractionFinished: dismissTimer.restart()
        onRequestedValue: value => osd.requestedValue(value)
      }
    }
  }
}
