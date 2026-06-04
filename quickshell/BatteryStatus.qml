import Quickshell
import Quickshell.Services.UPower
import QtQuick

Rectangle {
  id: batteryStatus
  width: statusContent.implicitWidth + 10
  color: activeHover ? "white" : "transparent"

  property var popupParentWindow
  property var popupAnchorItem: batteryStatus
  property bool menuOpen: false
  property bool menuVisible: false
  property bool activeHover: batteryMouse.containsMouse || menuOpen
  property int menuTargetWidth: 120
  property int menuTargetHeight: profileItems.length * 22 + 8
  property real menuAnimatedHeight: menuOpen ? menuTargetHeight : 0

  Behavior on menuAnimatedHeight {
    NumberAnimation {
      duration: 210
      easing.type: Easing.OutCubic
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
      duration: 120
    }
  }

  Timer {
    id: closeMenuTimer
    interval: 230
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
    spacing: 0

    property color targetTextColor: batteryStatus.activeHover ? "black" : "white"
    property color textColor: targetTextColor

    Behavior on textColor {
      ColorAnimation {
        duration: 120
      }
    }

    Text {
      color: statusContent.textColor
      font.family: "JetBrainsMono Nerd Font"
      font.weight: Font.Bold
      font.pixelSize: 12
      text: "["
    }

    Text {
      id: profileLetter
      color: statusContent.textColor
      font.family: "JetBrainsMono Nerd Font"
      font.weight: Font.Bold
      font.pixelSize: 12
      text: batteryStatus.profileIcon(PowerProfiles.profile)
      SequentialAnimation {
        id: profileBlink
        loops: 2
        NumberAnimation {
          target: profileLetter
          property: "opacity"
          to: 0
          duration: 300
        }
        NumberAnimation {
          target: profileLetter
          property: "opacity"
          to: 1
          duration: 300
        }
      }
    }

    Text {
      color: statusContent.textColor
      font.family: "JetBrainsMono Nerd Font"
      font.weight: Font.Bold
      font.pixelSize: 12
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
        duration: 180
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
      color: "black"
      clip: true
      transformOrigin: Item.TopRight

      property real outlineWidth: 1.8

      Rectangle {
        width: profileMenu.outlineWidth
        height: parent.height
        color: "white"
        anchors.left: parent.left
      }

      Rectangle {
        width: profileMenu.outlineWidth
        height: parent.height
        color: "white"
        anchors.right: parent.right
      }

      Rectangle {
        height: profileMenu.outlineWidth
        color: "white"
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
        }
      }

      Column {
        x: 4
        y: batteryStatus.menuOpen ? 4 : -14
        width: parent.width - 8
        spacing: 2
        opacity: batteryStatus.menuOpen ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
          }
        }

        Behavior on y {
          NumberAnimation {
            duration: 210
            easing.type: Easing.OutCubic
          }
        }

        Repeater {
          model: batteryStatus.profileItems

          Rectangle {
            id: profileRow
            width: parent.width
            height: 20
            color: inverted ? "white" : "transparent"

            property bool active: PowerProfiles.profile === modelData.profile
            property bool inverted: profileMouse.containsMouse || active

            Behavior on color {
              ColorAnimation {
                duration: 110
              }
            }

            Text {
              id: rowText
              anchors.fill: parent
              leftPadding: 5
              rightPadding: 5
              color: profileRow.inverted ? "black" : "white"
              font.family: "JetBrainsMono Nerd Font"
              font.weight: Font.Bold
              font.pixelSize: 12
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              text: (profileRow.active ? ">" : " ") + modelData.icon + " [" + modelData.label + "]"

              Behavior on color {
                ColorAnimation {
                  duration: 110
                }
              }

              Behavior on x {
                NumberAnimation {
                  duration: 120
                  easing.type: Easing.OutCubic
                }
              }
            }

            Rectangle {
              anchors {
                right: parent.right
                rightMargin: 5
                verticalCenter: parent.verticalCenter
              }
              width: profileRow.active ? 5 : 0
              height: 5
              color: profileRow.inverted ? "black" : "white"
              opacity: profileRow.active ? 1 : 0

              Behavior on width {
                NumberAnimation {
                  duration: 140
                  easing.type: Easing.OutBack
                }
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: 100
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
