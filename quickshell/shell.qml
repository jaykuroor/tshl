import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: shellRoot

  signal revealControls(string metric)

  IpcHandler {
    target: "controls"

    function reveal(metric) {
      shellRoot.revealControls(metric);
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Scope {
        required property var modelData

        PanelWindow {
          id: panel
          screen: modelData
          anchors {
            top: true
            left: true
            right: true
          }
          implicitHeight: 35
          color: "black"

          Rectangle {
            id: barFrame
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 2
            anchors.bottomMargin: 0
            color: "black"

            property real outlineWidth: 1.8
            property real dropdownRight: width
            property real dropdownWidth: batteryStatus.menuVisible ? batteryStatus.menuTargetWidth : 0
            property real dropdownLeft: Math.max(0, dropdownRight - dropdownWidth)

            Rectangle {
              height: barFrame.outlineWidth
              color: "white"
              anchors {
                left: parent.left
                right: parent.right
                top: parent.top
              }
            }

            Rectangle {
              width: barFrame.outlineWidth
              color: "white"
              anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
              }
            }

            Rectangle {
              width: barFrame.outlineWidth
              color: "white"
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
              color: "white"
            }

            Rectangle {
              x: Math.min(parent.width, barFrame.dropdownRight)
              y: parent.height - height
              width: Math.max(0, parent.width - x)
              height: barFrame.outlineWidth
              color: "white"
            }

            Item {
              id: batteryMenuAnchor
              x: barFrame.width - width
              y: barFrame.height - height
              width: batteryStatus.menuTargetWidth
              height: 1
            }

            Item {
              id: statusGroup
              anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
              }
              width: dateTimeStatus.width + 10 + batteryStatus.width
              height: 20

              DateTimeStatus {
                id: dateTimeStatus
                anchors {
                  right: batteryStatus.left
                  rightMargin: 10
                  verticalCenter: parent.verticalCenter
                }
                height: parent.height
              }

              BatteryStatus {
                id: batteryStatus
                popupParentWindow: panel
                popupAnchorItem: batteryMenuAnchor
                anchors {
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                }
                height: parent.height
              }
            }
          }
        }

        VolumeBrightnessPanel {
          modelData: modelData
          controller: shellRoot
        }
      }
    }
  }
}
