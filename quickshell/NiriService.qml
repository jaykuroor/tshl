pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: niri

  // Windows sorted by their position in niri's scrolling layout.
  property var windows: []
  property int focusedId: -1
  // output name -> active workspace id
  property var activeWorkspace: ({})
  // output name -> active workspace idx (1-based, vertical order in niri)
  property var activeWorkspaceIdx: ({})

  readonly property string placeholderIcon: "◻"

  readonly property var appIcons: ({
    // terminals
    "kitty": "❯",
    "alacritty": "❯",
    "foot": "❯",
    "footclient": "❯",
    "wezterm": "❯",
    "org.wezfurlong.wezterm": "❯",
    "ghostty": "❯",
    "com.mitchellh.ghostty": "❯",
    "konsole": "❯",
    "xterm": "❯",
    "st": "❯",
    // browsers
    "zen": "♁",
    "firefox": "♁",
    "librewolf": "♁",
    "chromium": "♁",
    "google-chrome": "♁",
    "brave-browser": "♁",
    "helium": "♁",
    "vivaldi": "♁",
    "qutebrowser": "♁",
    // editors / IDEs
    "cursor": "✎",
    "code": "✎",
    "code-oss": "✎",
    "codium": "✎",
    "zed": "✎",
    "dev.zed.zed": "✎",
    "sublime_text": "✎",
    "nvim": "✐",
    "neovim": "✐",
    "neovide": "✐",
    "vim": "✐",
    // notes / study
    "obsidian": "◈",
    "anki": "✦",
    // graphics
    "gimp": "◐",
    "org.gimp.gimp": "◐",
    "inkscape": "◐",
    "org.inkscape.inkscape": "◐",
    "krita": "◐",
    // system monitors
    "btop": "⣿",
    "htop": "⣿",
    "nvtop": "⣿",
    "org.gnome.systemmonitor": "⣿",
    // chat
    "discord": "✱",
    "vesktop": "✱",
    "webcord": "✱",
    "slack": "✱",
    "telegram": "✱",
    "org.telegram.desktop": "✱",
    "signal": "✱",
    // media
    "spotify": "♫",
    "rhythmbox": "♫",
    "mpv": "▶",
    "vlc": "▶",
    // games
    "steam": "✜",
    "lutris": "✜",
    // file managers
    "yazi": "▤",
    "nautilus": "▤",
    "org.gnome.nautilus": "▤",
    "thunar": "▤",
    "dolphin": "▤",
    "nemo": "▤",
    "pcmanfm": "▤",
    // documents
    "libreoffice": "▦",
    "zathura": "▥",
    "org.pwmt.zathura": "▥",
    "evince": "▥",
    "org.gnome.evince": "▥",
    "okular": "▥",
    // shell itself
    "quickshell": "◌",
    "org.quickshell": "◌"
  })

  function iconFor(appId) {
    if (!appId)
      return placeholderIcon;
    var key = appId.toLowerCase();
    if (appIcons[key] !== undefined)
      return appIcons[key];
    // dev.zed.Zed -> zed
    var tail = key.split(".").pop();
    if (appIcons[tail] !== undefined)
      return appIcons[tail];
    // libreoffice-writer -> libreoffice
    var head = key.split("-")[0];
    if (appIcons[head] !== undefined)
      return appIcons[head];
    return placeholderIcon;
  }

  function windowsForOutput(output) {
    var ws = activeWorkspace[output];
    if (ws === undefined)
      return [];
    return windows.filter(function (w) {
      return w.workspace_id === ws;
    });
  }

  function focusAndCenter(id) {
    Quickshell.execDetached(["sh", "-c", "niri msg action focus-window --id " + id + " && niri msg action center-window --id " + id]);
  }

  // --- internal state -------------------------------------------------

  property var windowById: ({})
  property var workspaceById: ({})

  function columnOf(w) {
    var pos = w.layout && w.layout.pos_in_scrolling_layout;
    return pos ? pos : null;
  }

  function rebuildWindows() {
    var arr = [];
    for (var k in windowById)
      arr.push(windowById[k]);
    arr.sort(function (a, b) {
      var pa = niri.columnOf(a);
      var pb = niri.columnOf(b);
      // floating windows have no scrolling position; park them at the end
      if (!pa && !pb)
        return a.id - b.id;
      if (!pa)
        return 1;
      if (!pb)
        return -1;
      return pa[0] - pb[0] || pa[1] - pb[1];
    });
    windows = arr;
  }

  function rebuildWorkspaces() {
    var m = {};
    var idx = {};
    for (var k in workspaceById) {
      var ws = workspaceById[k];
      if (ws.is_active) {
        m[ws.output] = ws.id;
        idx[ws.output] = ws.idx;
      }
    }
    // idx lands first so the strip knows the slide direction before its
    // window list swaps underneath it
    activeWorkspaceIdx = idx;
    activeWorkspace = m;
  }

  function samePos(a, b) {
    var pa = columnOf(a);
    var pb = columnOf(b);
    if (!pa || !pb)
      return pa === pb;
    return pa[0] === pb[0] && pa[1] === pb[1];
  }

  function handleEvent(line) {
    var ev;
    try {
      ev = JSON.parse(line);
    } catch (e) {
      return;
    }

    if (ev.WindowsChanged) {
      var m = {};
      var list = ev.WindowsChanged.windows;
      for (var i = 0; i < list.length; i++) {
        m[list[i].id] = list[i];
        if (list[i].is_focused)
          focusedId = list[i].id;
      }
      windowById = m;
      rebuildWindows();
    } else if (ev.WindowOpenedOrChanged) {
      var w = ev.WindowOpenedOrChanged.window;
      var prev = windowById[w.id];
      windowById[w.id] = w;
      if (w.is_focused)
        focusedId = w.id;
      // title churn (terminal spinners) must not re-sort the strip every frame
      if (!prev || prev.workspace_id !== w.workspace_id || !samePos(prev, w))
        rebuildWindows();
    } else if (ev.WindowClosed) {
      delete windowById[ev.WindowClosed.id];
      rebuildWindows();
    } else if (ev.WindowFocusChanged) {
      focusedId = ev.WindowFocusChanged.id === null ? -1 : ev.WindowFocusChanged.id;
    } else if (ev.WindowLayoutsChanged) {
      var changes = ev.WindowLayoutsChanged.changes;
      var moved = false;
      for (var j = 0; j < changes.length; j++) {
        var win = windowById[changes[j][0]];
        if (!win)
          continue;
        var updated = Object.assign({}, win, {
          layout: changes[j][1]
        });
        moved = moved || !samePos(win, updated);
        windowById[win.id] = updated;
      }
      if (moved)
        rebuildWindows();
    } else if (ev.WorkspacesChanged) {
      var wm = {};
      var wl = ev.WorkspacesChanged.workspaces;
      for (var n = 0; n < wl.length; n++)
        wm[wl[n].id] = wl[n];
      workspaceById = wm;
      rebuildWorkspaces();
    } else if (ev.WorkspaceActivated) {
      var active = workspaceById[ev.WorkspaceActivated.id];
      if (!active)
        return;
      for (var key in workspaceById) {
        var ws = workspaceById[key];
        if (ws.output === active.output)
          ws.is_active = ws.id === active.id;
      }
      rebuildWorkspaces();
    }
  }

  Process {
    id: eventStream
    running: true
    command: ["niri", "msg", "-j", "event-stream"]
    stdout: SplitParser {
      onRead: function (line) {
        niri.handleEvent(line);
      }
    }
    onExited: restartTimer.restart()
  }

  Timer {
    id: restartTimer
    interval: 1000
    onTriggered: eventStream.running = true
  }
}
