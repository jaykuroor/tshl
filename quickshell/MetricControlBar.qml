import QtQuick

// A vertical gauge: dark empty track, bright ink rising from the bottom.
//
// There used to be an `active` flag that reverse-videoed the whole chip, and
// the gauge colours flipped with it. That is unfixable, not just miscoloured:
// on a white chip the only colour brighter than the track is the chip itself,
// so a full bar has to be drawn in black and reads as a solid block of absence.
// A gauge cannot be reverse-videoed. Ink is always bright, track is always
// dark, in the only state there is.
Item {
  id: bar

  property string icon: "?"
  property int value: 0
  // the OSD spells the percentage out below the bar, so it hides this one
  property bool showValue: true

  signal requestedValue(int value)
  signal interactionStarted
  signal interactionFinished

  implicitWidth: Theme.spaceXxl
  implicitHeight: Theme.spaceXxl * 5

  function clampedValue(raw) {
    return Math.max(0, Math.min(100, raw));
  }

  function valueFromY(localY) {
    var ratio = 1 - Math.max(0, Math.min(1, localY / levelTrack.height));
    return clampedValue(Math.round(ratio * 100));
  }

  Text {
    id: iconText
    anchors {
      top: parent.top
      topMargin: Theme.spaceXs
      horizontalCenter: parent.horizontalCenter
    }
    color: Theme.fg
    font.family: Theme.mono
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontBody
    text: bar.icon
  }

  Rectangle {
    id: levelTrack
    anchors {
      top: iconText.bottom
      topMargin: Theme.spaceSm
      bottom: valueText.top
      bottomMargin: Theme.spaceSm
      horizontalCenter: parent.horizontalCenter
    }
    width: Theme.spaceMd
    // empty track: always the dark one
    color: Theme.bg

    // fill: always the ink
    Rectangle {
      anchors {
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }
      height: parent.height * bar.clampedValue(bar.value) / 100
      color: Theme.fg
    }

    // end caps, also ink: they mark the track's extent, which is the only thing
    // showing where 0 and 100 are once the track itself is background-coloured
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

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function (mouse) {
        bar.interactionStarted();
        bar.requestedValue(bar.valueFromY(mouse.y));
      }
      onPositionChanged: function (mouse) {
        if (pressed) {
          bar.requestedValue(bar.valueFromY(mouse.y));
        }
      }
      onReleased: bar.interactionFinished()
      onCanceled: bar.interactionFinished()
    }
  }

  Text {
    id: valueText
    visible: bar.showValue
    // collapses so the track can claim the space when the OSD hides it
    height: visible ? implicitHeight : 0
    anchors {
      bottom: parent.bottom
      bottomMargin: Theme.spaceXs
      horizontalCenter: parent.horizontalCenter
    }
    color: Theme.fg
    font.family: Theme.mono
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontMicro
    text: bar.clampedValue(bar.value).toString().padStart(2, "0")
  }
}
