import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: shellRoot

  signal revealControls(string metric)

  IpcHandler {
    target: "controls"

    // the parameter type is load-bearing: Quickshell refuses to expose an IPC
    // function with an untyped argument, so an untyped `metric` meant every
    // `quickshell ipc call controls reveal ...` from the keybinds was dropped
    function reveal(metric: string): void {
      shellRoot.revealControls(metric);
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Scope {
        id: screenScope
        required property var modelData

        PanelWindow {
          id: panel
          screen: modelData
          anchors {
            top: true
            left: true
            right: true
          }
          implicitHeight: Theme.barHeight
          color: Theme.bg

          Rectangle {
            id: barFrame
            anchors.fill: parent
            anchors.leftMargin: Theme.barInset
            anchors.rightMargin: Theme.barInset
            // the frame hangs off the top edge, so it is guttered above and
            // open below; the dropdown breaks through the bottom line
            anchors.topMargin: Theme.spaceXs
            anchors.bottomMargin: 0
            color: Theme.bg

            property real outlineWidth: Theme.border
            // The menu hangs centred under the battery chip, so the chip sits
            // dead centre above it.
            //
            // The gap punched in the bottom border is the menu's INTERIOR, not
            // its full width. That difference is the whole trick: at full width
            // the horizontal border stopped where the menu's vertical border
            // began, so the two lines met corner-to-corner and left a notch the
            // thickness of the border in both axes. Running the bottom border
            // over the top of the menu's own side borders instead makes each
            // corner a solid square and the outline continuous.
            // aligned to the panel's pixel grid: the popup surface and this
            // border are drawn by different surfaces, and a fractional x rounds
            // the two apart by a pixel, which is exactly the notch it leaves
            property real menuX: Theme.align(statusGroup.x + batteryStatus.x + (batteryStatus.width - batteryStatus.menuTargetWidth) / 2)
            // One panel pixel of bias. The popup is a separate surface, and the
            // compositor places it a pixel off where this window computes the
            // same coordinate, so the two borders miss each other by one. The
            // bias is toward OVERLAP on purpose: white over white is invisible,
            // while one pixel the other way is the notch that shows.
            // ponytail: if a compositor ever places popups exactly, this just
            // becomes a 1px-thicker corner rather than a bug.
            property real cornerBias: Theme.device(1)
            property real dropdownLeft: batteryStatus.menuExtended ? menuX + outlineWidth + cornerBias : width
            property real dropdownRight: batteryStatus.menuExtended ? menuX + batteryStatus.menuTargetWidth - outlineWidth + cornerBias : width

            Rectangle {
              height: barFrame.outlineWidth
              color: Theme.fg
              anchors {
                left: parent.left
                right: parent.right
                top: parent.top
              }
            }

            Rectangle {
              width: barFrame.outlineWidth
              color: Theme.fg
              anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
              }
            }

            Rectangle {
              width: barFrame.outlineWidth
              color: Theme.fg
              anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
              }
            }

            Rectangle {
              x: 0
              y: parent.height - height
              width: Math.max(0, barFrame.dropdownLeft)
              height: barFrame.outlineWidth
              color: Theme.fg
            }

            Rectangle {
              x: Math.min(parent.width, barFrame.dropdownRight)
              y: parent.height - height
              width: Math.max(0, parent.width - x)
              height: barFrame.outlineWidth
              color: Theme.fg
            }

            // The menu hangs off the frame's bottom edge, not off the battery
            // chip — the chip's own bottom sits a few px inside the bar, and
            // anchoring there would start the menu inside the frame instead of
            // growing out of it. Width matches the menu so the gap punched in
            // the bottom border lines up with the menu's side borders exactly,
            // which is what makes it read as the panel extruding rather than a
            // separate box that happens to be touching.
            // Sits one border-width ABOVE the frame's bottom edge, so the popup
            // begins at the TOP of the panel's bottom border rather than below
            // it. That overlap is what lets the menu's bottom border be the
            // panel's bottom border: it starts life exactly on top of it, is
            // carried down as the menu extends, and is carried back. Anchored
            // flush instead, the border had to be clipped into existence on the
            // way out and clipped away on the way back, which is the frame
            // where that stretch rendered thinner than the rest of the line.
            Item {
              id: batteryMenuAnchor
              x: barFrame.menuX
              y: barFrame.height - Theme.border - height
              width: batteryStatus.menuTargetWidth
              height: 1
            }

            WindowIcons {
              outputName: panel.screen.name
              anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
              }
              // symmetric about the bar centre: keeps a clear gap to whatever
              // sits on the right, and never wider than 80% of the screen so
              // there is always a tenth of it blank on each side. The clearance
              // is the widest gap in the bar — icons and status are separate
              // regions, so they get more air than the groups inside them.
              width: Math.max(0, Math.min(2 * (statusGroup.x - Theme.spaceXxl) - barFrame.width, panel.screen.width * 0.8))
              height: Theme.rowHeight
            }

            // battery, date, time — one even rhythm rather than two groups.
            // DateTimeStatus is itself a Row on the same spacing token, so the
            // three read as equally spaced despite the nesting.
            Row {
              id: statusGroup
              anchors {
                right: parent.right
                rightMargin: Theme.spaceLg
                verticalCenter: parent.verticalCenter
              }
              height: Theme.rowHeight
              spacing: Theme.spaceSm

              BatteryStatus {
                id: batteryStatus
                popupParentWindow: panel
                popupAnchorItem: batteryMenuAnchor
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.rowHeight
              }

              DateTimeStatus {
                id: dateTimeStatus
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        VolumeBrightnessPanel {
          // qualified deliberately: a bare `modelData` here binds the panel's
          // own property to itself, which left it with no screen at all — so
          // its vertical centring never ran and it pinned to the top margin
          modelData: screenScope.modelData
          controller: shellRoot
        }
      }
    }
  }
}
