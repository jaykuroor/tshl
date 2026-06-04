import QtQuick

Rectangle {
  id: metricControlBar
  width: 34
  height: 170
  color: active ? "white" : "transparent"

  property string icon: "?"
  property int value: 0
  property bool active: false
  property real outlineWidth: 1.8

  signal requestedValue(int value)
  signal interactionStarted()
  signal interactionFinished()

  function clampedValue(rawValue) {
    return Math.max(0, Math.min(100, rawValue));
  }

  function valueFromY(localY) {
    var ratio = 1 - Math.max(0, Math.min(1, localY / levelTrack.height));
    return clampedValue(Math.round(ratio * 100));
  }

  Behavior on color {
    ColorAnimation {
      duration: 110
    }
  }

  Text {
    id: iconText
    anchors {
      top: parent.top
      topMargin: 5
      horizontalCenter: parent.horizontalCenter
    }
    color: metricControlBar.active ? "black" : "white"
    font.family: "JetBrainsMono Nerd Font"
    font.weight: Font.Bold
    font.pixelSize: 12
    text: metricControlBar.icon

    Behavior on color {
      ColorAnimation {
        duration: 110
      }
    }
  }

  Rectangle {
    id: levelTrack
    anchors {
      top: iconText.bottom
      topMargin: 7
      bottom: valueText.top
      bottomMargin: 7
      horizontalCenter: parent.horizontalCenter
    }
    width: 12
    color: metricControlBar.active ? "black" : "white"

    Rectangle {
      anchors {
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }
      height: parent.height * metricControlBar.clampedValue(metricControlBar.value) / 100
      color: metricControlBar.active ? "white" : "black"
    }

    Rectangle {
      height: metricControlBar.outlineWidth
      color: metricControlBar.active ? "white" : "black"
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
      }
    }

    Rectangle {
      height: metricControlBar.outlineWidth
      color: metricControlBar.active ? "white" : "black"
      anchors {
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) {
        metricControlBar.interactionStarted();
        metricControlBar.requestedValue(metricControlBar.valueFromY(mouse.y));
      }
      onPositionChanged: function(mouse) {
        if (pressed) {
          metricControlBar.requestedValue(metricControlBar.valueFromY(mouse.y));
        }
      }
      onReleased: metricControlBar.interactionFinished()
      onCanceled: metricControlBar.interactionFinished()
    }
  }

  Text {
    id: valueText
    anchors {
      bottom: parent.bottom
      bottomMargin: 5
      horizontalCenter: parent.horizontalCenter
    }
    color: metricControlBar.active ? "black" : "white"
    font.family: "JetBrainsMono Nerd Font"
    font.weight: Font.Bold
    font.pixelSize: 10
    text: metricControlBar.clampedValue(metricControlBar.value).toString().padStart(2, "0")

    Behavior on color {
      ColorAnimation {
        duration: 110
      }
    }
  }
}
