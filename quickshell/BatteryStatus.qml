import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Battery as a bordered chip with a segmented meter — the slider's vertical
// ladder rotated. Same rules as that component: segments for a level, a border
// because this one is clickable (it opens the profile menu), dim for unlit.
//
// Note what it deliberately does NOT do: reverse-video on hover, the way it
// used to. A gauge cannot be inverted — on a white chip the only colour that
// reads as filled is darker than the track, so a full battery would draw as a
// solid black block. Hover lifts the background instead, and the unlit segments
// switch to bg so they stay legible against it.
Rectangle {
  id: batteryStatus

  property var popupParentWindow
  property var popupAnchorItem: batteryStatus
  property bool menuOpen: false
  property bool menuVisible: false
  property bool hovered: batteryMouse.containsMouse || menuOpen

  readonly property int segmentCount: 10  // one segment per 10%

  width: content.width + Theme.spaceSm * 2
  color: hovered ? Theme.off : "transparent"
  border.width: Theme.border
  border.color: Theme.fg

  // the menu drops directly under the chip and matches its width, so the gap it
  // punches in the bar's bottom border lines up with the chip exactly
  property int menuTargetWidth: Math.max(96, width)
  property int menuTargetHeight: profileItems.length * Theme.rowHeight + Theme.spaceXs * 2
  property real menuAnimatedHeight: menuOpen ? menuTargetHeight : 0

  Behavior on color {
    ColorAnimation {
      duration: Theme.fast
    }
  }

  Behavior on menuAnimatedHeight {
    NumberAnimation {
      duration: Theme.base
      easing.type: Theme.easing
    }
  }

  property var battery: UPower.displayDevice
  property real rawPercentage: battery ? battery.percentage : -1
  property bool available: battery && battery.isPresent && rawPercentage >= 0
  property int percentage: available ? Math.round(rawPercentage <= 1 ? rawPercentage * 100 : rawPercentage) : 0
  property bool charging: battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)
  readonly property int litCount: available ? Math.round(percentage / 100 * segmentCount) : 0

  property var profileItems: PowerProfiles.hasPerformanceProfile ? [
    {
      "profile": PowerProfile.PowerSaver,
      "icon": "S",
      "label": "save"
    },
    {
      "profile": PowerProfile.Balanced,
      "icon": "B",
      "label": "bal"
    },
    {
      "profile": PowerProfile.Performance,
      "icon": "P",
      "label": "perf"
    }
  ] : [
    {
      "profile": PowerProfile.PowerSaver,
      "icon": "S",
      "label": "save"
    },
    {
      "profile": PowerProfile.Balanced,
      "icon": "B",
      "label": "bal"
    }
  ]

  function profileIcon(profile) {
    if (profile === PowerProfile.PowerSaver)
      return "S";
    if (profile === PowerProfile.Performance)
      return "P";
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
    id: content
    anchors.centerIn: parent
    spacing: Theme.spaceSm

    Text {
      id: profileLetter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Theme.textNudge
      color: Theme.fg
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

    Row {
      id: meter
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.border

      Repeater {
        model: batteryStatus.segmentCount

        delegate: Rectangle {
          required property int index

          width: Theme.spaceXs
          height: Theme.spaceMd
          // fills left to right, so the first delegate is the first to light
          color: (index + 1) <= batteryStatus.litCount ? Theme.fg : batteryStatus.hovered ? Theme.bg : Theme.off

          Behavior on color {
            ColorAnimation {
              duration: Theme.fast
            }
          }
        }
      }
    }

    // fixed-length monospace string, so the chip never changes width as the
    // charge ticks over and the layout beside it never shifts
    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Theme.textNudge
      color: Theme.fg
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: (batteryStatus.available ? batteryStatus.percentage.toString() : "--").padStart(3, " ") + (batteryStatus.charging ? "+" : " ")
    }

    Connections {
      target: PowerProfiles
      function onProfileChanged() {
        profileBlink.restart();
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
      edges: Edges.Bottom | Edges.Left
      gravity: Edges.Bottom | Edges.Right
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
