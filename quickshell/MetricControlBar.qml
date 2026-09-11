import QtQuick

// A segmented level meter, the way a TUI draws one: a ladder of discrete
// blocks that light from the bottom, with a step button at each end.
//
// Discrete rather than a continuous fill because a continuous bar has to prove
// where it starts and ends — the old one needed end caps for that and still
// read as a floating block. A ladder shows its own extent: the unlit rungs are
// the scale.
//
// There is one state. An earlier version reverse-videoed the whole chip when
// "active", which flipped the gauge colours with it, and on a white chip the
// only colour that can read as filled is darker than the track — so a full bar
// had to be drawn in black and read as solid absence. Ink is always bright.
Item {
  id: bar

  property string icon: "?"
  property int value: 0
  // one click ≈ one rung at the counts this lays out at
  property int step: 5

  signal requestedValue(int value)
  signal interactionStarted
  signal interactionFinished

  implicitWidth: Theme.spaceXxl
  implicitHeight: Theme.spaceXxl * 5

  // Rungs are a fixed pitch and the count follows the space, so the ladder
  // fills whatever height it is given instead of stretching to fit. The gap is
  // a border width because that is the one sub-grid value that lands on whole
  // panel pixels.
  readonly property real segPitch: Theme.spaceSm + Theme.border
  readonly property int segmentCount: Math.max(1, Math.floor((track.height + Theme.border) / segPitch))
  readonly property int litCount: Math.round(clampedValue(value) / 100 * segmentCount)

  function clampedValue(raw) {
    return Math.max(0, Math.min(100, raw));
  }

  function valueFromY(localY) {
    var ratio = 1 - Math.max(0, Math.min(1, localY / ladder.height));
    return clampedValue(Math.round(ratio * 100));
  }

  function nudge(delta) {
    bar.interactionStarted();
    bar.requestedValue(clampedValue(bar.value + delta));
    bar.interactionFinished();
  }

  // two of these per bar, so it earns its keep; inverts on hover like every
  // other hit target in the shell
  component StepButton: Rectangle {
    id: button

    property string glyph: "+"
    signal activated

    width: Theme.spaceXl
    height: Theme.spaceXl
    color: buttonMouse.containsMouse ? Theme.fg : "transparent"
    border.width: Theme.border
    border.color: Theme.fg

    Behavior on color {
      ColorAnimation {
        duration: Theme.fast
      }
    }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Theme.textNudge
      color: buttonMouse.containsMouse ? Theme.bg : Theme.fg
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: button.glyph

      Behavior on color {
        ColorAnimation {
          duration: Theme.fast
        }
      }
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.activated()
    }
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

  StepButton {
    id: plusButton
    glyph: "+"
    anchors {
      top: iconText.bottom
      topMargin: Theme.spaceSm
      horizontalCenter: parent.horizontalCenter
    }
    onActivated: bar.nudge(bar.step)
  }

  Item {
    id: track
    anchors {
      top: plusButton.bottom
      topMargin: Theme.spaceXs
      bottom: minusButton.top
      bottomMargin: Theme.spaceXs
      horizontalCenter: parent.horizontalCenter
    }
    width: Theme.spaceXl

    Column {
      id: ladder
      anchors.centerIn: parent
      width: parent.width
      spacing: Theme.border

      Repeater {
        model: bar.segmentCount

        delegate: Rectangle {
          required property int index

          width: ladder.width
          height: Theme.spaceSm
          // the ladder fills upward, so the bottom-most delegate lights first
          color: (bar.segmentCount - index) <= bar.litCount ? Theme.fg : Theme.off

          Behavior on color {
            ColorAnimation {
              duration: Theme.fast
            }
          }
        }
      }
    }

    // drag anywhere in the track; the value is read off the ladder, which is
    // centred inside it and so may be a few px shorter
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function (mouse) {
        bar.interactionStarted();
        bar.requestedValue(bar.valueFromY(mouse.y - ladder.y));
      }
      onPositionChanged: function (mouse) {
        if (pressed) {
          bar.requestedValue(bar.valueFromY(mouse.y - ladder.y));
        }
      }
      onReleased: bar.interactionFinished()
      onCanceled: bar.interactionFinished()
    }
  }

  StepButton {
    id: minusButton
    glyph: "-"
    anchors {
      bottom: valueText.top
      bottomMargin: Theme.spaceSm
      horizontalCenter: parent.horizontalCenter
    }
    onActivated: bar.nudge(-bar.step)
  }

  Text {
    id: valueText
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
