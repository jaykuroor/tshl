import QtQuick

Item {
  id: strip

  required property string outputName

  readonly property string mono: Theme.mono
  // 15px is the one size where JetBrains Mono's 0.6em advance lands on a whole
  // number (9.0), so the three-column cell is exactly 27px with no rounding
  readonly property int cellSize: Theme.fontLarge
  // One dock slot is exactly three monospace columns: shade, icon, shade.
  // Measured off ruler.implicitWidth rather than fm.advanceWidth(): the latter
  // is a method call, so the binding cannot re-run when the font finishes
  // loading and would keep whatever the fallback metrics said. Ten columns
  // dilutes the glyph's right bearing; the integer column keeps every glyph on
  // a whole pixel, and block ink slightly exceeds it so bars tile with no seam.
  readonly property int columnWidth: Math.round(ruler.implicitWidth / 10)
  property int itemWidth: 3 * columnWidth

  property var items: NiriService.windowsForOutput(outputName)
  property int focusedIndex: {
    for (var i = 0; i < items.length; i++) {
      if (items[i].id === NiriService.focusedId)
        return i;
    }
    return -1;
  }

  // Whatever width the bar hands us, minus a fixed gutter each side for the
  // overflow counters. The gutter is reserved unconditionally so the viewport
  // never depends on whether a counter is showing — that would be a loop.
  readonly property real gutter: 4 * columnWidth
  readonly property real contentWidth: items.length * itemWidth
  // odd slot count keeps the focused slot dead centre *and* on the character
  // grid, so nothing is ever half-clipped at the viewport edges
  readonly property int slots: Math.max(1, 2 * Math.floor((Math.max(0, width - 2 * gutter) / itemWidth - 1) / 2) + 1)
  readonly property real viewportWidth: Math.min(contentWidth, slots * itemWidth)
  readonly property bool scrolling: contentWidth > viewportWidth

  // counted off the live row position, so they tick over mid-scroll
  readonly property int hiddenLeft: Math.max(0, Math.min(items.length, Math.floor((1 - iconRow.x) / itemWidth)))
  readonly property int hiddenRight: Math.max(0, Math.min(items.length, items.length - Math.ceil((viewportWidth - 1 - iconRow.x) / itemWidth)))

  // The counters keep showing their last real count while they fade out —
  // binding the label straight to the live count renders a "+0" for the length
  // of the fade every time the last hidden window comes into view.
  property int shownLeft: 0
  property int shownRight: 0

  onHiddenLeftChanged: if (hiddenLeft > 0)
    shownLeft = hiddenLeft
  onHiddenRightChanged: if (hiddenRight > 0)
    shownRight = hiddenRight

  // sharp focus position in row coords, plus a laggy copy the dither rides on:
  // the reverse-video block snaps to the new icon while the shading drags
  // across the slots in between. trailGap closes once the two meet, so the
  // smear only exists while the focus is actually moving.
  readonly property real focusCenter: (focusedIndex >= 0 ? focusedIndex : 0) * itemWidth + itemWidth / 2
  property real blurCenter: focusCenter
  readonly property real trailGap: Math.min(1, Math.abs(focusCenter - blurCenter) / itemWidth)
  readonly property real trailDir: focusCenter >= blurCenter ? 1 : -1
  // How far back the smear reaches. A fixed length cannot keep up with a jump
  // of arbitrary size — focus twenty windows away and a two-slot smudge is
  // left behind off-viewport — so it stretches to cover whatever ground the
  // focus actually took, with a floor for ordinary one-slot steps.
  readonly property real trailSpan: Math.max(itemWidth * 2.5, Math.abs(focusCenter - blurCenter))

  Behavior on blurCenter {
    enabled: !slide.running
    NumberAnimation {
      // signature smear timing, deliberately slower than any chrome duration
      duration: 760
      easing.type: Theme.easing
    }
  }

  // workspace switches are vertical in niri, so the strip wipes in from the
  // side the new workspace came from instead of sliding sideways
  property int wsIdx: NiriService.activeWorkspaceIdx[outputName] || 0
  property int prevWsIdx: wsIdx

  onWsIdxChanged: {
    if (prevWsIdx > 0 && wsIdx > 0 && wsIdx !== prevWsIdx) {
      slide.from = (wsIdx > prevWsIdx ? 1 : -1) * strip.height;
      slide.restart();
    }
    prevWsIdx = wsIdx;
  }

  NumberAnimation {
    id: slide
    target: iconRow
    property: "y"
    to: 0
    // signature workspace wipe, likewise deliberate
    duration: 460
    easing.type: Theme.easing
  }

  FontMetrics {
    id: fm
    font.family: strip.mono
    font.pixelSize: strip.cellSize
  }

  Text {
    id: ruler
    visible: false
    font: fm.font
    text: "██████████"
  }

  Text {
    anchors.right: viewport.left
    anchors.rightMargin: strip.columnWidth
    anchors.verticalCenter: parent.verticalCenter
    color: Theme.dim
    font.family: strip.mono
    font.pixelSize: strip.cellSize
    renderType: Text.QtRendering
    text: strip.shownLeft > 0 ? "+" + strip.shownLeft : ""
    opacity: strip.hiddenLeft > 0 ? 1 : 0

    // a workspace wipe swaps the whole list at once: fading the old count out
    // across it just leaves a stale number floating over the new windows
    Behavior on opacity {
      enabled: !slide.running
      NumberAnimation {
        duration: Theme.fast
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -Theme.spaceXs
      // only live while the counter is actually showing, which also guarantees
      // there is something at the far end to jump to
      enabled: strip.hiddenLeft > 0
      cursorShape: Qt.PointingHandCursor
      onClicked: NiriService.focusAndCenter(strip.items[0].id)
    }
  }

  Text {
    anchors.left: viewport.right
    anchors.leftMargin: strip.columnWidth
    anchors.verticalCenter: parent.verticalCenter
    color: Theme.dim
    font.family: strip.mono
    font.pixelSize: strip.cellSize
    renderType: Text.QtRendering
    text: strip.shownRight > 0 ? "+" + strip.shownRight : ""
    opacity: strip.hiddenRight > 0 ? 1 : 0

    Behavior on opacity {
      enabled: !slide.running
      NumberAnimation {
        duration: Theme.fast
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -Theme.spaceXs
      enabled: strip.hiddenRight > 0
      cursorShape: Qt.PointingHandCursor
      onClicked: NiriService.focusAndCenter(strip.items[strip.items.length - 1].id)
    }
  }

  Item {
    id: viewport
    anchors.horizontalCenter: parent.horizontalCenter
    width: strip.viewportWidth
    height: strip.height
    clip: true

    Row {
      id: iconRow
      height: parent.height

      // keeps the focused window's icon dead center, mirroring niri's scroll;
      // once everything fits there is nothing to scroll, so it sits flush
      x: strip.scrolling && strip.focusedIndex >= 0 ? strip.viewportWidth / 2 - (strip.focusedIndex + 0.5) * strip.itemWidth : 0

      Behavior on x {
        enabled: !slide.running
        NumberAnimation {
          duration: Theme.slow
          easing.type: Theme.easing
        }
      }

      Repeater {
        model: strip.items

        delegate: Item {
          id: iconCell
          required property var modelData
          required property int index

          readonly property bool active: modelData.id === NiriService.focusedId

          width: strip.itemWidth
          height: strip.height

          Rectangle {
            anchors.fill: parent
            color: iconCell.active ? Theme.fg : "transparent"

            Behavior on color {
              ColorAnimation {
                duration: Theme.fast
              }
            }
          }

          // Three columns, each sampling the smear on its own, so the trail is a
          // gradient sweeping across the slot. The block glyph still steps, but
          // its grey level compensates for the jump in coverage, so the ink the
          // eye actually sees is continuous — that's what kills the chop.
          Row {
            anchors.centerIn: parent
            // sits under the focused box, which is opaque, so no visible: guard
            z: -1

            Repeater {
              model: 3

              delegate: Text {
                required property int index

                readonly property real px: (iconCell.index + (index + 0.5) / 3) * strip.itemWidth
                // distance back from the focus box; negative is ahead of it,
                // and nothing smears ahead. Anchoring the bright end to the box
                // rather than to the lagging centre is what keeps the smear
                // attached to it no matter how far the focus jumped.
                readonly property real behind: (strip.focusCenter - px) * strip.trailDir
                readonly property real ink: behind < 0 ? 0 : Math.max(0, Math.min(1, (1 - behind / strip.trailSpan) * 1.25)) * strip.trailGap
                readonly property real density: ink > 0.75 ? 1.0 : ink > 0.5 ? 0.75 : ink > 0.25 ? 0.5 : 0.25

                width: strip.columnWidth
                horizontalAlignment: Text.AlignHCenter
                color: Qt.rgba(ink / density, ink / density, ink / density, 1)
                font.family: strip.mono
                font.pixelSize: strip.cellSize
                renderType: Text.QtRendering
                text: ink > 0.75 ? "█" : ink > 0.5 ? "▓" : ink > 0.25 ? "▒" : "░"
              }
            }
          }

          Text {
            anchors.centerIn: parent
            color: iconCell.active ? Theme.bg : Theme.fg
            font.family: strip.mono
            font.weight: Theme.fontWeight
            font.pixelSize: strip.cellSize
            // distance-field glyphs keep subpixel positions while the row slides
            renderType: Text.QtRendering
            text: NiriService.iconFor(iconCell.modelData.app_id)

            Behavior on color {
              ColorAnimation {
                duration: Theme.fast
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: NiriService.focusAndCenter(iconCell.modelData.id)
          }
        }
      }
    }
  }
}
