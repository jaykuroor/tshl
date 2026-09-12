import Quickshell
import Quickshell.Services.UPower
import QtQuick

// `[S 96%]-` — brackets for the cell, the trailing sign for charge direction.
// Plain text that reverse-videoes on hover, which is safe here precisely
// because there is no gauge in it: inversion only breaks on a meter, where the
// filled end would have to be drawn dark and read as absence.
Rectangle {
  id: batteryStatus

  property var popupParentWindow
  property var popupAnchorItem: batteryStatus
  property bool menuOpen: false
  property bool menuVisible: false
  property bool activeHover: batteryMouse.containsMouse || menuOpen

  width: statusContent.width + Theme.spaceXs * 2
  color: activeHover ? Theme.fg : "transparent"

  property int menuTargetWidth: Math.max(96, width)
  property int menuTargetHeight: profileItems.length * Theme.rowHeight + Theme.spaceXs * 2

  // 0 = fully retracted behind the bar, 1 = fully extended.
  //
  // The slide lives here rather than on the menu's own y so the bar can open
  // its bottom-border gap off the same number. Bound to menuVisible instead,
  // the gap stayed open for the whole close delay — which has to outlast the
  // slide so the surface is not torn down mid-animation — and for the ~120ms
  // between the menu finishing its retract and the popup unmapping, the border
  // had a hole in it with nothing in front of it.
  property real menuReveal: menuOpen ? 1 : 0
  readonly property bool menuExtended: menuReveal > 0

  Behavior on menuReveal {
    NumberAnimation {
      duration: Theme.base
      easing.type: Theme.easing
    }
  }

  Behavior on color {
    ColorAnimation {
      duration: Theme.fast
    }
  }

  property var battery: UPower.displayDevice
  property real rawPercentage: battery ? battery.percentage : -1
  property bool available: battery && battery.isPresent && rawPercentage >= 0
  property int percentage: available ? Math.round(rawPercentage <= 1 ? rawPercentage * 100 : rawPercentage) : 0
  property bool charging: battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

  // --- "only when the user did it" -------------------------------------------
  // Both UPower and PowerProfiles publish their opening values as ordinary
  // property changes, so a plain onProfileChanged fires once during startup and
  // the indicator blinked at every login. There is no flag on the signal saying
  // "this one was you", so the component ignores everything until the services
  // have settled, and records the values it saw in the meantime.
  property bool settled: false
  property int knownProfile: -1
  property int lastPercentage: -1

  // levels that blink on the way down: 20, 15, and every value from 10 to 0
  readonly property var alertLevels: [20, 15, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]

  Timer {
    // long enough for UPower and PowerProfiles to publish their initial state;
    // this is a service-settling window, not a design value, so it is not a token
    interval: 2000
    running: true
    onTriggered: {
      batteryStatus.knownProfile = PowerProfiles.profile;
      batteryStatus.lastPercentage = batteryStatus.percentage;
      batteryStatus.settled = true;
    }
  }

  onPercentageChanged: {
    if (!settled) {
      lastPercentage = percentage;
      return;
    }
    // only on the way down, so "first reached" means the step into the level,
    // and coming back up re-arms it
    if (lastPercentage >= 0 && percentage < lastPercentage && alertLevels.indexOf(percentage) >= 0) {
      percentBlink.restart();
    }
    lastPercentage = percentage;
  }

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
    // must outlast the slide, or the surface is torn down mid-animation
    interval: Theme.slow
    onTriggered: {
      if (!batteryStatus.menuOpen) {
        batteryStatus.menuVisible = false;
      }
    }
  }

  Timer {
    id: openMenuTimer
    // one frame, so the window is mapped before the slide starts from its
    // closed position rather than being born halfway down
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

    property color textColor: batteryStatus.activeHover ? Theme.bg : Theme.fg

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
      id: percentText
      color: statusContent.textColor
      font.family: Theme.mono
      font.weight: Theme.fontWeight
      font.pixelSize: Theme.fontBody
      text: batteryStatus.available ? " " + batteryStatus.percentage + "%]" + (batteryStatus.charging ? "+" : "-") : " --%] "

      // same shape and duration as the mode blink, so a low-battery step reads
      // as the same kind of event
      SequentialAnimation {
        id: percentBlink
        loops: 2
        NumberAnimation {
          target: percentText
          property: "opacity"
          to: 0
          duration: Theme.base
        }
        NumberAnimation {
          target: percentText
          property: "opacity"
          to: 1
          duration: Theme.base
        }
      }
    }

    Connections {
      target: PowerProfiles
      function onProfileChanged() {
        if (!batteryStatus.settled) {
          batteryStatus.knownProfile = PowerProfiles.profile;
          return;
        }
        if (PowerProfiles.profile === batteryStatus.knownProfile) {
          return;
        }
        batteryStatus.knownProfile = PowerProfiles.profile;
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

  // The window is a FIXED size and the menu slides down inside it, clipped.
  //
  // It used to set implicitWidth/implicitHeight from the menu's own animating
  // height, so every frame of the open resized the Wayland popup surface — a
  // configure round-trip per frame, which the compositor cannot interpolate.
  // That is the same fault the volume drawer had. On top of it three animations
  // ran at once on different properties and durations (the height, plus the
  // rows' y and opacity), so the contents were easing against a box that was
  // itself still moving. Now the surface never changes size and exactly one
  // property animates: y.
  PopupWindow {
    id: powerProfilePopup
    visible: batteryStatus.menuVisible
    implicitWidth: batteryStatus.menuTargetWidth
    // one border taller than the menu: the surface starts at the top of the
    // panel's bottom border so that border can be carried down and back
    implicitHeight: batteryStatus.menuTargetHeight + Theme.border
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

    Item {
      anchors.fill: parent
      clip: true

      Rectangle {
        id: profileMenu
        width: parent.width
        height: batteryStatus.menuTargetHeight
        // Fully retracted, the box sits exactly one border-width into the
        // surface, so the only part of it left unclipped is its own bottom
        // border — landing precisely where the panel's bottom border is drawn.
        // Extending carries that line down; retracting carries it back. It is
        // never partially clipped, so it is never thinner than the rest of the
        // line, and at rest it is indistinguishable from the panel's border
        // underneath it.
        y: Theme.border - height * (1 - batteryStatus.menuReveal)
        color: Theme.bg

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
          y: Theme.spaceXs
          width: parent.width - Theme.spaceXs * 2
          // contiguous rows: the hover fill reads as one band instead of stripes
          spacing: 0

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
}
