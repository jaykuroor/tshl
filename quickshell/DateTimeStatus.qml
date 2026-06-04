import Quickshell
import QtQuick

Rectangle {
  id: dateTimeStatus
  width: clock.width + 14 + dateIndicator.width
  color: dateTimeHover.hovered ? "white" : "transparent"

  property int sectionPadding: 4

  SystemClock {
    id: systemClock
    precision: SystemClock.Minutes
  }

  HoverHandler {
    id: dateTimeHover
  }

  Rectangle {
    id: dateIndicator
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    width: dateText.implicitWidth + dateTimeStatus.sectionPadding * 2
    height: parent.height
    color: "transparent"

    property var weekdayLetters: ["U", "M", "T", "W", "R", "F", "S"]

    Text {
      id: dateText
      anchors.centerIn: parent
      color: dateTimeHover.hovered ? "black" : "white"
      font.family: "JetBrainsMono Nerd Font"
      font.weight: Font.Bold
      font.pixelSize: 12
      text: systemClock.date.getDate() + dateIndicator.weekdayLetters[systemClock.date.getDay()]
    }
  }

  Rectangle {
    id: clock
    anchors {
      right: dateIndicator.left
      rightMargin: 16
      verticalCenter: parent.verticalCenter
    }
    width: clockText.implicitWidth + dateTimeStatus.sectionPadding * 2
    height: parent.height
    color: "transparent"

    Text {
      id: clockText
      anchors.centerIn: parent
      color: dateTimeHover.hovered ? "black" : "white"
      font.family: "JetBrainsMono Nerd Font"
      font.weight: Font.Bold
      font.pixelSize: 12
      text: Qt.formatDateTime(systemClock.date, "hh:mm")
    }
  }
}
