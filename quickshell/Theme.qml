pragma Singleton

import Quickshell
import QtQuick

// Single source of truth for every size, gap, weight and duration in the shell.
// Nothing below is a taste call that can be made per-file: if a component needs
// a number, it comes from here, so the whole surface stays in proportion.
Singleton {
  id: theme

  // --- device grid -----------------------------------------------------------
  // eDP-1 is a 1920x1080 panel presented at niri scale 1.25, i.e. 1536x864
  // logical. One logical px is therefore 1.25 real panel pixels, and anything
  // that has to read as a hard edge must land on a whole one or it smears
  // across two and turns grey.
  //
  // This deliberately does NOT use Screen.devicePixelRatio: Qt reports 2 here,
  // because it renders into a 2x buffer and lets the compositor downscale to
  // the fractional output. That 2 describes Qt's buffer, not the panel, so it
  // is the wrong number for deciding whether a line is crisp. Measured
  // pixel-density ratios don't recover the scale either (they give ~1.37).
  //
  // So it is a calibration constant, and this is the knob: if the output scale
  // changes, or a second monitor arrives, change this one number.
  readonly property real scale: 1.25

  // logical size that renders as exactly `px` whole panel pixels
  function device(px) {
    return px / theme.scale;
  }

  // largest logical size not exceeding `px` that is still a whole number of
  // panel pixels. For dividing a run of space into N equal parts that all have
  // to land on the pixel grid — a ladder of meter rungs, say — where the
  // straight division almost never does.
  function snap(px) {
    return Math.max(device(1), Math.floor(px * theme.scale) / theme.scale);
  }

  // nearest position on the panel's pixel grid. For a coordinate rather than a
  // size: where two separately-drawn edges have to meet exactly — a border on
  // one surface continuing into a border on another — a fraction of a logical
  // pixel is enough to round the two apart and leave a notch at the join.
  function align(px) {
    return Math.round(px * theme.scale) / theme.scale;
  }

  // --- spacing ---------------------------------------------------------------
  // 4px soft grid. Every multiple of 4 is also a whole number of device pixels
  // at 1.25 scale (4 -> 5), so the grid and the panel agree.
  // Applied under the internal <= external rule: padding inside a group is
  // always tighter than the gap that separates it from the next group, so
  // proximity does the grouping instead of borders.
  readonly property int spaceXs: 4    // padding inside a chip
  readonly property int spaceSm: 8    // between related items (time <-> date)
  readonly property int spaceMd: 12
  readonly property int spaceLg: 16   // between groups, and group -> edge
  readonly property int spaceXl: 24
  readonly property int spaceXxl: 32

  // --- type ------------------------------------------------------------------
  // Major third (1.25) off a 12px body, rounded to whole px: 9.6 -> 10, 12, 15.
  // Three sizes is the whole scale; a dense status bar does not need more.
  // fontLarge is also the one size where JetBrains Mono's 0.6em advance lands
  // on an exact integer (15 * 0.6 = 9.0), which is what keeps the icon strip's
  // character grid free of sub-pixel seams.
  readonly property int fontMicro: 10
  readonly property int fontBody: 12
  readonly property int fontLarge: 15

  readonly property string mono: "JetBrainsMono Nerd Font"
  // one weight everywhere: the palette is two colours, so weight is the only
  // hierarchy left and splitting it just makes things look accidental
  readonly property int fontWeight: Font.Bold

  // monospace advance at a given size, for laying out on the character grid
  function column(pixelSize) {
    return pixelSize * 0.6;
  }

  // Optical centring correction for text, one panel pixel down.
  // Qt centres a text item by its line box, and the line box reserves room for
  // descenders. Nothing in this bar has a descender — it is all digits, caps
  // and brackets — so the ink ends up sitting high inside its own box. Measured
  // on a screenshot rather than guessed: the readout had 11 panel px of space
  // above the ink and 13 below.
  // Text only. The icon strip centres a filled box rather than ink and already
  // measures dead centre, so nudging it would break what is already correct.
  readonly property real textNudge: device(1)

  // --- line ------------------------------------------------------------------
  // Exactly 2 panel px.
  //
  // Measured honestly: the old 1.8 literal (2.25 panel px) also rendered as a
  // clean 2px line, because Qt's scene graph snaps axis-aligned rectangle edges
  // to whole device pixels on its own. So this is not a blur fix. What it buys
  // is that the width is now a stated intent — 2 panel pixels — instead of an
  // arbitrary number that happened to survive rounding, and it stays 2 panel px
  // if the scale above ever changes, where 1.8 would have drifted.
  readonly property real border: device(2)

  // --- colour ----------------------------------------------------------------
  readonly property color fg: "white"
  readonly property color bg: "black"
  readonly property color dim: "#8a8a8a"
  // unlit. Dark enough to read as "off" next to fg, light enough that the
  // full extent of a meter is still visible against bg — which is the job the
  // old end caps were doing badly.
  readonly property color off: "#3a3a3a"

  // --- structure -------------------------------------------------------------
  readonly property int barHeight: 36        // 4-grid, 45 device px
  readonly property int barInset: spaceSm    // frame inset from the screen edge
  readonly property int rowHeight: spaceXl   // 24: content band inside the bar

  // --- motion ----------------------------------------------------------------
  // Three durations. Chrome that must feel instant, the default, and panels
  // that travel a real distance.
  readonly property int fast: 120
  readonly property int base: 200
  readonly property int slow: 320
  readonly property int easing: Easing.OutCubic
}
