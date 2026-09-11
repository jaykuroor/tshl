import Quickshell
import QtQuick

// Key-driven heads-up display: one metric only, with the percentage spelled
// out. Distinct from the hover drawer, which shows both and no number.
// Its own window so it can exist only while shown — closed, there is no
// surface at all and nothing to click through.
PanelWindow {
  id: osd

  required property var modelData
  property string icon: "?"
  property int value: 0

  // wide enough for "100%" at fontLarge; the bar matches so the column centres
  readonly property int cellWidth: Theme.spaceXxl + Theme.spaceMd
  readonly property int dismissDelay: Theme.slow * 6  // ~1.9s from the last key press

  signal requestedValue(int value)

  function reveal() {
    visible = true;
    dismissTimer.restart();
  }

  function dismiss() {
    dismissTimer.stop();
    visible = false;
  }

  visible: false
  screen: modelData
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  color: "transparent"
  aboveWindows: true
  focusable: false
  // Deliberately no exclusiveZone here. In Quickshell setting one defeats
  // ExclusionMode.Ignore: the surface stops reserving space but is still
  // pushed out of other surfaces' exclusive zones, which shoved this off
  // vertical centre by exactly the height of the bars above it.
  exclusionMode: ExclusionMode.Ignore

  // Input is confined to the box. The surface is full-screen so the box can be
  // centred against the real screen, but a full-screen *input* region would
  // mean every media keypress swallowed the next click anywhere on screen for
  // the whole dismiss delay — and the media keys get used while something else
  // has the pointer. So this one dismisses on the timer only, which is the
  // "or appropriate time" half of the requirement.
  // Knob: to get outside-click dismissal back, drop this mask and add a
  // full-screen MouseArea that calls dismiss(), and accept the eaten click.
  mask: Region {
    item: box
  }

  Timer {
    id: dismissTimer
    interval: osd.dismissDelay
    onTriggered: osd.dismiss()
  }

  Rectangle {
    id: box
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    width: column.width + Theme.spaceSm * 2
    height: column.height + Theme.spaceSm * 2
    color: Theme.bg

    // absorbs presses that land on the box but not on the gauge (the border,
    // the percentage) so they do nothing rather than falling through to the
    // gauge's parent; the track's own MouseArea still handles dragging
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: dismissTimer.restart()
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

    Column {
      id: column
      x: Theme.spaceSm
      y: Theme.spaceSm
      spacing: Theme.spaceSm

      MetricControlBar {
        width: osd.cellWidth
        height: Theme.spaceXxl * 5
        icon: osd.icon
        value: osd.value
        showValue: false
        onInteractionStarted: dismissTimer.stop()
        onInteractionFinished: dismissTimer.restart()
        onRequestedValue: value => osd.requestedValue(value)
      }

      Text {
        width: osd.cellWidth
        horizontalAlignment: Text.AlignHCenter
        color: Theme.fg
        font.family: Theme.mono
        font.weight: Theme.fontWeight
        font.pixelSize: Theme.fontLarge
        text: Math.max(0, Math.min(100, osd.value)) + "%"
      }
    }
  }
}
