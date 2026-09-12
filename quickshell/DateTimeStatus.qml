import Quickshell
import QtQuick

// Date then time, as plain readouts.
//
// This is a Row using the same spacing token as the status group that holds it,
// which is what makes the three items — battery, date, time — sit on one even
// rhythm instead of the old two-group arrangement. The battery is a separate
// sibling, so nesting is invisible in the result.
//
// No hover treatment, deliberately: following the slider, a border or an
// inversion means "you can click this", and these two do nothing. The battery
// beside them is bordered because it does.
Row {
  id: dateTimeStatus

  spacing: Theme.spaceLg

  readonly property var weekdayLetters: ["U", "M", "T", "W", "R", "F", "S"]

  SystemClock {
    id: systemClock
    precision: SystemClock.Minutes
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Theme.textNudge
    color: Theme.fg
    font.family: Theme.mono
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontBody
    text: systemClock.date.getDate() + dateTimeStatus.weekdayLetters[systemClock.date.getDay()]
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Theme.textNudge
    color: Theme.fg
    font.family: Theme.mono
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontBody
    text: Qt.formatDateTime(systemClock.date, "hh:mm")
  }
}
