import Quickshell
import QtQuick

// Date then time, as plain readouts.
//
// This is a Row using the same spacing token as the status group that holds it,
// which is what makes the three items — battery, date, time — sit on one even
// rhythm instead of the old two-group arrangement. The battery is a separate
// sibling, so nesting is invisible in the result.
//
// No hover treatment, deliberately: an inversion means "you can click this",
// and these two do nothing. The battery beside them inverts because it opens
// the profile menu.
Row {
  id: dateTimeStatus

  // matches the status group's spacing so all three items sit on one rhythm
  spacing: Theme.spaceSm

  readonly property var weekdayLetters: ["U", "M", "T", "W", "R", "F", "S"]

  SystemClock {
    id: systemClock
    precision: SystemClock.Minutes
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Theme.textNudge
    // the battery pads its hover box by the same amount, so padding every item
    // equally is what keeps the three ink-to-ink gaps identical
    leftPadding: Theme.spaceXs
    rightPadding: Theme.spaceXs
    color: Theme.fg
    font.family: Theme.mono
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontBody
    text: systemClock.date.getDate() + dateTimeStatus.weekdayLetters[systemClock.date.getDay()]
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Theme.textNudge
    // the battery pads its hover box by the same amount, so padding every item
    // equally is what keeps the three ink-to-ink gaps identical
    leftPadding: Theme.spaceXs
    rightPadding: Theme.spaceXs
    color: Theme.fg
    font.family: Theme.mono
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontBody
    text: Qt.formatDateTime(systemClock.date, "hh:mm")
  }
}
