import Quickshell
import QtQuick

// Time and date are one group, so they sit closer to each other than the group
// sits to the battery beside it. That ordering is the whole point: before, the
// time/date gap was 24px of ink-to-ink while the gap to the battery was 19, so
// the eye read the date as belonging to the battery.
Rectangle {
  id: dateTimeStatus

  width: readout.width + Theme.spaceXs * 2
  color: dateTimeHover.hovered ? Theme.fg : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: Theme.fast
    }
  }

  SystemClock {
    id: systemClock
    precision: SystemClock.Minutes
  }

  HoverHandler {
    id: dateTimeHover
  }

  Row {
    id: readout
    anchors.centerIn: parent
    anchors.verticalCenterOffset: Theme.textNudge
    spacing: Theme.spaceSm

    readonly property var weekdayLetters: ["U", "M", "T", "W", "R", "F", "S"]

    Text {
      color: dateTimeHover.hovered ? Theme.bg : Theme.fg
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: Qt.formatDateTime(systemClock.date, "hh:mm")

      Behavior on color {
        ColorAnimation {
          duration: Theme.fast
        }
      }
    }

    Text {
      color: dateTimeHover.hovered ? Theme.bg : Theme.fg
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: systemClock.date.getDate() + readout.weekdayLetters[systemClock.date.getDay()]

      Behavior on color {
        ColorAnimation {
          duration: Theme.fast
        }
      }
    }
  }
}
