import QtQuick

// A segmented level meter, the way a TUI draws one: a ladder of discrete rungs
// that light from the bottom, a step button at each end, and a readout you can
// type into.
//
// Exactly 20 rungs, so one rung is 5% and one click of a step button moves
// exactly one rung. The rung height is what gives, not the count — it is
// snapped down to whole panel pixels and the slack is absorbed by centring the
// ladder, because 20 equal parts of an arbitrary height otherwise land on
// fractional pixels and the ladder renders with uneven rungs.
//
// There is one colour state. An earlier version reverse-videoed the whole chip
// when "active", which flipped the gauge with it, and on a white chip the only
// colour that can read as filled is darker than the track — so a full bar had
// to be drawn in black and read as solid absence. Ink is always bright.
Item {
  id: bar

  property string icon: "?"
  property int value: 0
  // one click, one rung
  readonly property int step: 5

  // volume has a mute toggle in the icon slot; brightness keeps the identical
  // slot with a plain glyph in it, so both columns stay the same shape
  property bool canMute: false
  property bool muted: false

  property bool editing: false

  signal requestedValue(int value)
  signal muteToggled
  signal interactionStarted
  signal interactionFinished

  implicitWidth: Theme.spaceXxl
  implicitHeight: Theme.spaceXxl * 5

  readonly property int segmentCount: 20
  readonly property real segSpacing: Theme.border
  readonly property real segHeight: Theme.snap((track.height - segSpacing * (segmentCount - 1)) / segmentCount)
  readonly property int litCount: Math.round(clampedValue(value) / 100 * segmentCount)
  // muted still shows the level, just not as live ink
  readonly property color inkColor: muted ? Theme.dim : Theme.fg

  function clampedValue(raw) {
    return Math.max(0, Math.min(100, Math.round(raw)));
  }

  function valueFromY(localY) {
    var ratio = 1 - Math.max(0, Math.min(1, localY / ladder.height));
    return clampedValue(ratio * 100);
  }

  function nudge(delta) {
    bar.interactionStarted();
    bar.requestedValue(clampedValue(bar.value + delta));
    bar.interactionFinished();
  }

  function beginEdit() {
    bar.interactionStarted();
    bar.editing = true;
  }

  function commitEdit() {
    if (!bar.editing) {
      return;
    }
    bar.editing = false;
    var parsed = parseInt(valueInput.text, 10);
    if (!isNaN(parsed)) {
      bar.requestedValue(clampedValue(parsed));
    }
    bar.interactionFinished();
  }

  function cancelEdit() {
    if (!bar.editing) {
      return;
    }
    bar.editing = false;
    bar.interactionFinished();
  }

  // two per bar, so it earns its keep. Press repeats while held: 20 clicks to
  // cross the range is fine for a nudge and tedious for a sweep.
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

    Timer {
      id: holdTimer
      repeat: true
      // first repeat waits, the rest run at the fast tick: ~2.5s from 0 to 100
      interval: Theme.slow
      onTriggered: {
        interval = Theme.fast;
        button.activated();
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
      onPressed: {
        button.activated();
        holdTimer.interval = Theme.slow;
        holdTimer.restart();
      }
      onReleased: holdTimer.stop()
      onCanceled: holdTimer.stop()
      // dragging off the button stops the repeat rather than letting it run on
      onExited: holdTimer.stop()
    }
  }

  // Icon slot. Same geometry in both columns; only the volume one reacts.
  Item {
    id: iconSlot
    width: Theme.spaceXl
    height: Theme.spaceXl
    anchors {
      top: parent.top
      topMargin: Theme.spaceXs
      horizontalCenter: parent.horizontalCenter
    }

    Rectangle {
      anchors.fill: parent
      color: bar.canMute && muteMouse.containsMouse ? Theme.fg : "transparent"

      Behavior on color {
        ColorAnimation {
          duration: Theme.fast
        }
      }
    }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Theme.textNudge
      color: bar.canMute && muteMouse.containsMouse ? Theme.bg : bar.inkColor
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: bar.canMute && bar.muted ? ")x(" : bar.icon

      Behavior on color {
        ColorAnimation {
          duration: Theme.fast
        }
      }
    }

    MouseArea {
      id: muteMouse
      anchors.fill: parent
      enabled: bar.canMute
      hoverEnabled: bar.canMute
      cursorShape: Qt.PointingHandCursor
      onClicked: bar.muteToggled()
    }
  }

  StepButton {
    id: plusButton
    glyph: "+"
    anchors {
      top: iconSlot.bottom
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
      spacing: bar.segSpacing

      Repeater {
        model: bar.segmentCount

        delegate: Rectangle {
          required property int index

          width: ladder.width
          height: bar.segHeight
          // the ladder fills upward, so the bottom-most delegate lights first
          color: (bar.segmentCount - index) <= bar.litCount ? bar.inkColor : Theme.off

          Behavior on color {
            ColorAnimation {
              duration: Theme.fast
            }
          }
        }
      }
    }

    // drag anywhere in the track; the value is read off the ladder, which is
    // centred inside it and so may be a couple of px shorter
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
      bottom: valueField.top
      bottomMargin: Theme.spaceSm
      horizontalCenter: parent.horizontalCenter
    }
    onActivated: bar.nudge(-bar.step)
  }

  // Readout, and the entry field. Click the number to type one.
  Item {
    id: valueField
    width: Theme.spaceXl
    height: Theme.spaceLg
    anchors {
      bottom: parent.bottom
      bottomMargin: Theme.spaceXs
      horizontalCenter: parent.horizontalCenter
    }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Theme.textNudge
      visible: !bar.editing
      color: bar.inkColor
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontMicro
      text: bar.clampedValue(bar.value).toString().padStart(2, "0")
    }

    TextInput {
      id: valueInput
      anchors.fill: parent
      anchors.verticalCenterOffset: Theme.textNudge
      visible: bar.editing
      enabled: bar.editing
      color: Theme.fg
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontMicro
      horizontalAlignment: TextInput.AlignHCenter
      verticalAlignment: TextInput.AlignVCenter
      selectByMouse: true
      // the platform default is a blue block, which is the only colour that
      // would appear anywhere in this shell
      selectionColor: Theme.fg
      selectedTextColor: Theme.bg
      cursorDelegate: Rectangle {
        width: Theme.border
        color: Theme.fg
      }
      maximumLength: 3
      inputMethodHints: Qt.ImhDigitsOnly
      // clamped here as well as on commit: the validator stops 0-100 being
      // exceeded while typing, the clamp catches paste and empty input
      validator: IntValidator {
        bottom: 0
        top: 100
      }

      onEditingFinished: bar.commitEdit()
      Keys.onEscapePressed: bar.cancelEdit()

      // the surface only becomes keyboard-focusable once editing starts, so
      // focus has to be taken after that has had a chance to apply
      onVisibleChanged: if (visible) {
        text = bar.clampedValue(bar.value).toString();
        Qt.callLater(function () {
          valueInput.forceActiveFocus();
          valueInput.selectAll();
        });
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: !bar.editing
      hoverEnabled: true
      cursorShape: Qt.IBeamCursor
      onClicked: bar.beginEdit()
    }
  }
}
