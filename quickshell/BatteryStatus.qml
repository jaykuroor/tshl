import Quickshell
import Quickshell.Services.UPower
import QtQuick

Rectangle {
  id: batteryStatus
  width: statusContent.implicitWidth + Theme.spaceXs * 2
  color: activeHover ? Theme.fg : "transparent"

  property var popupParentWindow
  property var popupAnchorItem: batteryStatus
  property bool menuOpen: false
  property bool menuVisible: false
  property bool activeHover: batteryMouse.containsMouse || menuOpen
  // 12 monospace columns of body text (86.4) plus row and menu padding,
  // rounded up onto the 4-grid. The old 120 left the labels floating.
  property int menuTargetWidth: 96
  property int menuTargetHeight: profileItems.length * Theme.rowHeight + Theme.spaceXs * 2
  property real menuAnimatedHeight: menuOpen ? menuTargetHeight : 0

  Behavior on menuAnimatedHeight {
    NumberAnimation {
      duration: Theme.base
      easing.type: Theme.easing
    }
  }

  property var battery: UPower.displayDevice
  property real rawPercentage: battery ? battery.percentage : -1
  property bool available: battery && battery.isPresent && rawPercentage >= 0
  property int percentage: available
    ? Math.round(rawPercentage <= 1 ? rawPercentage * 100 : rawPercentage)
    : 0
  property bool charging: battery && (
    battery.state === UPowerDeviceState.Charging
    || battery.state === UPowerDeviceState.FullyCharged
  )
  property var profileItems: PowerProfiles.hasPerformanceProfile ? [
    { "profile": PowerProfile.PowerSaver, "icon": "S", "label": "save" },
    { "profile": PowerProfile.Balanced, "icon": "B", "label": "bal" },
    { "profile": PowerProfile.Performance, "icon": "P", "label": "perf" }
  ] : [
    { "profile": PowerProfile.PowerSaver, "icon": "S", "label": "save" },
    { "profile": PowerProfile.Balanced, "icon": "B", "label": "bal" }
  ]

  function profileIcon(profile) {
    if (profile === PowerProfile.PowerSaver) return "S";
    if (profile === PowerProfile.Performance) return "P";
    return "B";
  }

  function openMenu() {
    closeMenuTimer.stop();
    menuVisible = true;
    openMenuTimer.restart();
  }

  function closeMenu() {
    openMenuTimer.stop();
    menuOpen = false;
    closeMenuTimer.restart();
  }

  Behavior on color {
    ColorAnimation {
      duration: Theme.fast
    }
  }

  Timer {
    id: closeMenuTimer
    interval: Theme.slow
    onTriggered: {
      if (!batteryStatus.menuOpen) {
        batteryStatus.menuVisible = false;
      }
    }
  }

  Timer {
    id: openMenuTimer
    interval: 32
    onTriggered: {
      if (batteryStatus.menuVisible) {
        batteryStatus.menuOpen = true;
      }
    }
  }

  MouseArea {
    id: batteryMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: batteryStatus.menuOpen ? batteryStatus.closeMenu() : batteryStatus.openMenu()
  }

  Row {
    id: statusContent
    anchors.centerIn: parent
    anchors.verticalCenterOffset: Theme.textNudge
    spacing: 0

    property color targetTextColor: batteryStatus.activeHover ? Theme.bg : Theme.fg
    property color textColor: targetTextColor

    Behavior on textColor {
      ColorAnimation {
        duration: Theme.fast
      }
    }

    Text {
      color: statusContent.textColor
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: "["
    }

    Text {
      id: profileLetter
      color: statusContent.textColor
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: batteryStatus.profileIcon(PowerProfiles.profile)
      SequentialAnimation {
        id: profileBlink
        loops: 2
        NumberAnimation {
          target: profileLetter
          property: "opacity"
          to: 0
          duration: Theme.base
        }
        NumberAnimation {
          target: profileLetter
          property: "opacity"
          to: 1
          duration: Theme.base
        }
      }
    }

    Text {
      color: statusContent.textColor
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: batteryStatus.available
        ? " " + batteryStatus.percentage + "%]" + (batteryStatus.charging ? "+" : "-")
        : " --%] "
    }

    Connections {
      target: PowerProfiles
      function onProfileChanged() {
        statusPulse.restart();
        profileBlink.restart();
      }
    }

    SequentialAnimation {
      id: statusPulse
      PropertyAction {
        target: statusContent
        property: "scale"
        value: 1.12
      }
      NumberAnimation {
        target: statusContent
        property: "scale"
        to: 1
        duration: Theme.base
        easing.type: Easing.OutBack
      }
    }
  }

  PopupWindow {
    id: powerProfilePopup
    visible: batteryStatus.menuVisible
    implicitWidth: profileMenu.width
    implicitHeight: profileMenu.height
    color: "transparent"
    grabFocus: true

    anchor {
      window: batteryStatus.popupParentWindow
      item: batteryStatus.popupAnchorItem
      edges: Edges.Bottom | Edges.Right
      gravity: Edges.Bottom | Edges.Left
      adjustment: PopupAdjustment.SlideX
      margins {
        top: 0
      }
    }

    onClosed: {
      if (batteryStatus.menuOpen) {
        batteryStatus.closeMenu();
      }
    }

    Rectangle {
      id: profileMenu
      width: batteryStatus.menuTargetWidth
      height: Math.max(1, batteryStatus.menuAnimatedHeight)
      color: Theme.bg
      clip: true
      transformOrigin: Item.TopRight

      property real outlineWidth: Theme.border

      Rectangle {
        width: profileMenu.outlineWidth
        height: parent.height
        color: Theme.fg
        anchors.left: parent.left
      }

      Rectangle {
        width: profileMenu.outlineWidth
        height: parent.height
        color: Theme.fg
        anchors.right: parent.right
      }

      Rectangle {
        height: profileMenu.outlineWidth
        color: Theme.fg
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
        }
      }

      Column {
        x: Theme.spaceXs
        y: batteryStatus.menuOpen ? Theme.spaceXs : -Theme.spaceMd
        width: parent.width - Theme.spaceXs * 2
        // contiguous rows: the hover fill reads as one band instead of stripes
        spacing: 0
        opacity: batteryStatus.menuOpen ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.fast
            easing.type: Theme.easing
          }
        }

        Behavior on y {
          NumberAnimation {
            duration: Theme.base
            easing.type: Theme.easing
          }
        }

        Repeater {
          model: batteryStatus.profileItems

          Rectangle {
            id: profileRow
            width: parent.width
            height: Theme.rowHeight
            color: inverted ? Theme.fg : "transparent"

            property bool active: PowerProfiles.profile === modelData.profile
            property bool inverted: profileMouse.containsMouse || active

            Behavior on color {
              ColorAnimation {
                duration: Theme.fast
              }
            }

            Text {
              id: rowText
              anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: Theme.textNudge
              }
              leftPadding: Theme.spaceXs
              rightPadding: Theme.spaceXs
              color: profileRow.inverted ? Theme.bg : Theme.fg
              font.family: Theme.mono
              font.weight: Theme.fontWeight
              font.pixelSize: Theme.fontBody
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              text: (profileRow.active ? ">" : " ") + modelData.icon + " [" + modelData.label + "]"

              Behavior on color {
                ColorAnimation {
                  duration: Theme.fast
                }
              }

              Behavior on x {
                NumberAnimation {
                  duration: Theme.fast
                  easing.type: Theme.easing
                }
              }
            }

            Rectangle {
              anchors {
                right: parent.right
                rightMargin: Theme.spaceXs
                verticalCenter: parent.verticalCenter
              }
              width: profileRow.active ? Theme.spaceXs : 0
              height: Theme.spaceXs
              color: profileRow.inverted ? Theme.bg : Theme.fg
              opacity: profileRow.active ? 1 : 0

              Behavior on width {
                NumberAnimation {
                  duration: Theme.fast
                  easing.type: Easing.OutBack
                }
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: Theme.fast
                }
              }
            }

            MouseArea {
              id: profileMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                PowerProfiles.profile = modelData.profile;
                batteryStatus.closeMenu();
              }
            }
          }
        }
      }
    }
  }
}
