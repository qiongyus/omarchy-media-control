import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import qs.Ui
import qs.Commons

// GNOME-style media indicator for the Omarchy bar.
//
// Bar: a single play/pause glyph, shown only while something is playing
// (or paused, unless `hideWhenPaused` is set). Left click opens the panel,
// right click toggles playback, wheel skips tracks.
//
// Panel: app name + icon, artwork, title/artist, prev/play/next, seek bar
// with elapsed/total time, and a source picker when several players exist.
//
// Playback state comes from Omarchy's built-in omarchy.media service, so
// OSD feedback, source cycling and keyboard media keys stay consistent.
BarWidget {
  id: root
  moduleName: "debba.media-control"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media") ?? null

  readonly property var rawPlayers: Mpris.players ? Mpris.players.values : []
  property string preferredPlayerKey: ""

  function playerKey(p) {
    if (!p) return ""
    return String(p.dbusName || p.desktopEntry || p.identity || "")
  }

  function selectPlayer(key) {
    if (mediaService && typeof mediaService.selectPlayer === "function") {
      mediaService.selectPlayer(key)
    }
    preferredPlayerKey = key
  }

  readonly property var sourcePlayers: {
    if (mediaService && mediaService.sourcePlayers && mediaService.sourcePlayers.length > 0)
      return mediaService.sourcePlayers
    var list = []
    for (var i = 0; i < rawPlayers.length; i++) {
      var p = rawPlayers[i]
      if (p && (p.trackTitle || p.trackArtist || p.identity || p.desktopEntry)) {
        list.push(p)
      }
    }
    return list
  }

  readonly property var activePlayer: {
    if (mediaService && mediaService.activePlayer)
      return mediaService.activePlayer
    if (sourcePlayers.length === 0) return null
    if (preferredPlayerKey) {
      for (var i = 0; i < sourcePlayers.length; i++) {
        if (playerKey(sourcePlayers[i]) === preferredPlayerKey) return sourcePlayers[i]
      }
    }
    for (var j = 0; j < sourcePlayers.length; j++) {
      if (sourcePlayers[j].isPlaying) return sourcePlayers[j]
    }
    for (var k = 0; k < sourcePlayers.length; k++) {
      if (sourcePlayers[k].trackTitle || sourcePlayers[k].trackArtist) return sourcePlayers[k]
    }
    return sourcePlayers[0]
  }

  readonly property bool hideWhenPaused: settings && settings.hideWhenPaused === true
  readonly property int panelWidth: settings && settings.panelWidth > 0 ? settings.panelWidth : 360

  readonly property bool hasMedia: activePlayer !== null && !!(activePlayer.trackTitle || activePlayer.trackArtist || activePlayer.identity)
  readonly property bool isPlaying: activePlayer !== null && activePlayer.isPlaying
  readonly property bool shouldShow: hasMedia && (isPlaying || !hideWhenPaused || popupOpen)

  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  // Resolve the player's .desktop entry so we can show the proper app name
  // and icon (e.g. Zen reports desktopEntry "zen" whose icon is "zen-browser").
  readonly property var appEntry: activePlayer && activePlayer.desktopEntry ? DesktopEntries.byId(activePlayer.desktopEntry) : null
  readonly property string appName: appEntry && appEntry.name ? appEntry.name
    : activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media") : "Media"
  readonly property string appIcon: {
    if (appEntry && appEntry.icon) {
      var themed = Quickshell.iconPath(appEntry.icon, true)
      if (themed) return themed
    }
    if (activePlayer && activePlayer.desktopEntry) return Quickshell.iconPath(activePlayer.desktopEntry, true) || ""
    return ""
  }

  readonly property bool hasLength: !!activePlayer && activePlayer.lengthSupported && activePlayer.length > 0
  readonly property bool hasPosition: !!activePlayer && activePlayer.positionSupported
  readonly property real trackLength: {
    var p = activePlayer
    return p && p.lengthSupported && p.length > 0 ? p.length : 0
  }
  readonly property real trackPosition: {
    var p = activePlayer
    if (!p || !p.positionSupported) return 0
    var pos = p.position
    var len = p.lengthSupported && p.length > 0 ? p.length : 0
    return len > 0 ? Math.min(pos, len) : pos
  }

  property bool popupOpen: false
  function close() { popupOpen = false }

  onShouldShowChanged: if (!shouldShow) popupOpen = false

  function anyPopupOpen() {
    var items = bar && typeof bar.moduleWidgets === "function"
      ? bar.moduleWidgets(moduleName) : [root]
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i].popupOpen) return true
    }
    return false
  }

  function isFocusedBar() {
    var win = root.QsWindow ? root.QsWindow.window : null
    var scr = win ? win.screen : null
    if (scr && typeof Hyprland !== "undefined" && Hyprland.focusedMonitor) {
      return Hyprland.focusedMonitor.name === scr.name
    }
    return true
  }

  function togglePopup(): void {
    if (!root.hasMedia) return
    if (anyPopupOpen()) {
      root.popupOpen = false
    } else {
      if (isFocusedBar()) {
        root.popupOpen = true
      }
    }
  }

  function openPopup(): void {
    if (root.hasMedia && isFocusedBar()) root.popupOpen = true
  }

  function closePopup(): void {
    root.popupOpen = false
  }

  readonly property bool isLoopActive: activePlayer && (activePlayer.loopSupported !== false) && activePlayer.loopState !== MprisLoopState.None
  readonly property string loopStatusText: {
    if (!activePlayer || activePlayer.loopSupported === false) return "循环: 不支持"
    if (activePlayer.loopState === MprisLoopState.Track) return "循环: 单曲循环"
    if (activePlayer.loopState === MprisLoopState.Playlist) return "循环: 列表循环"
    return "循环: 关闭"
  }

  function cycleRepeat(): void {
    var p = root.activePlayer
    if (!p) return
    if (p.loopSupported === false) return
    if (p.loopState === MprisLoopState.None) {
      p.loopState = MprisLoopState.Playlist
    } else if (p.loopState === MprisLoopState.Playlist) {
      p.loopState = MprisLoopState.Track
    } else {
      p.loopState = MprisLoopState.None
    }
  }

  readonly property bool isShuffleActive: activePlayer && (activePlayer.shuffleSupported !== false) && activePlayer.shuffle === true
  readonly property string shuffleStatusText: {
    if (!activePlayer || activePlayer.shuffleSupported === false) return "随机播放: 不支持"
    return activePlayer.shuffle ? "随机播放: 开启" : "随机播放: 关闭"
  }

  function toggleShuffle(): void {
    var p = root.activePlayer
    if (!p || p.shuffleSupported === false) return
    if (typeof p.shuffle !== "undefined") {
      p.shuffle = !p.shuffle
    }
  }

  property real savedVolume: 1.0

  function seekDelta(seconds): void {
    var p = root.activePlayer
    if (!p || !p.canSeek) return
    var len = p.lengthSupported && p.length > 0 ? p.length : 0
    var cur = root.trackPosition
    var target = cur + seconds
    if (len > 0) target = Math.max(0, Math.min(len, target))
    else target = Math.max(0, target)
    p.position = target
  }

  function adjustVolume(delta): void {
    var p = root.activePlayer
    if (!p) return
    if (typeof p.volume !== "undefined") {
      p.volume = Math.max(0.0, Math.min(1.0, (p.volume || 0.0) + delta))
    }
  }

  function toggleMute(): void {
    var p = root.activePlayer
    if (!p || typeof p.volume === "undefined") return
    if (p.volume > 0.01) {
      root.savedVolume = p.volume
      p.volume = 0.0
    } else {
      p.volume = root.savedVolume > 0.05 ? root.savedVolume : 0.8
    }
  }

  // omarchy-shell debba.media-control toggle|open|close|playPause|next|previous|repeat|shuffle|stop
  IpcHandler {
    target: "debba.media-control"
    function toggle(): void { root.broadcast("togglePopup") }
    function open(): void { root.broadcast("openPopup") }
    function close(): void { root.broadcast("closePopup") }
    function playPause(): void { root.act("playPause") }
    function next(): void { root.act("next") }
    function previous(): void { root.act("previous") }
    function stop(): void { root.act("stop") }
    function repeat(): void { root.cycleRepeat() }
    function cycleRepeat(): void { root.cycleRepeat() }
    function shuffle(): void { root.toggleShuffle() }
    function toggleShuffle(): void { root.toggleShuffle() }
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) seconds = 0
    var total = Math.floor(seconds)
    var h = Math.floor(total / 3600)
    var m = Math.floor((total % 3600) / 60)
    var s = total % 60
    var mm = h > 0 && m < 10 ? "0" + m : "" + m
    var ss = s < 10 ? "0" + s : "" + s
    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
  }

  function act(action) {
    if (mediaService && typeof mediaService.runAction === "function") {
      mediaService.runAction(action, false, playerKey(activePlayer))
      return
    }
    var p = activePlayer
    if (!p) return
    if (action === "playPause") {
      if (p.canTogglePlaying) p.togglePlaying()
      else if (p.isPlaying && p.canPause) p.pause()
      else if (!p.isPlaying && p.canPlay) p.play()
    } else if (action === "next") {
      if (p.canGoNext) p.next()
    } else if (action === "previous") {
      if (p.canGoPrevious) p.previous()
    } else if (action === "stop") {
      if (typeof p.stop === "function") p.stop()
      else if (p.canPause) p.pause()
    } else if (action === "repeat" || action === "cycleRepeat") {
      root.cycleRepeat()
    } else if (action === "shuffle" || action === "toggleShuffle") {
      root.toggleShuffle()
    } else if (action === "play") {
      if (p.canPlay) p.play()
      else if (p.canTogglePlaying) p.togglePlaying()
    } else if (action === "pause") {
      if (p.canPause) p.pause()
      else if (p.canTogglePlaying) p.togglePlaying()
    }
  }

  visible: shouldShow
  implicitWidth: shouldShow ? glyph.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Text {
    id: glyph
    anchors.centerIn: parent
    text: root.isPlaying ? "󰐊" : "󰏤"
    color: root.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.body
    Behavior on color {
      enabled: !root.bar || root.bar.foregroundAnimationEnabled
      ColorAnimation { duration: 160 }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else if (mouse.button === Qt.RightButton) root.act("playPause")
      else if (mouse.button === Qt.MiddleButton) root.act("next")
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0) root.act("previous")
      else if (wheel.angleDelta.y < 0) root.act("next")
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.title + (root.artist ? " — " + root.artist : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // MPRIS only pushes position on seeks/track changes; nudge the binding once
  // a second while the panel is open so the seek bar advances smoothly.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.isPlaying && root.hasPosition
    triggeredOnStart: true
    onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
  }

  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: keyHandler
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Item {
      id: keyHandler
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem

      Keys.onPressed: function(event) {
        // Esc or Ctrl+Q -> Close panel (VLC: Ctrl+Q quits, Esc leaves fullscreen)
        if (event.key === Qt.Key_Escape || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Q)) {
          root.close()
          event.accepted = true
          return
        }

        // Space / Return -> Play/Pause (VLC: Space)
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.act("playPause")
          event.accepted = true
          return
        }

        // 's' / 'S' -> Stop (VLC: s)
        if (event.key === Qt.Key_S || event.text === "s" || event.text === "S") {
          root.act("stop")
          event.accepted = true
          return
        }

        // 'r' / 'R' -> Random / Shuffle (VLC: r)
        if (event.key === Qt.Key_R || event.text === "r" || event.text === "R") {
          root.toggleShuffle()
          event.accepted = true
          return
        }

        // 'l' / 'L' -> Normal/Loop/Repeat (VLC: l)
        if (event.key === Qt.Key_L || event.text === "l" || event.text === "L") {
          root.cycleRepeat()
          event.accepted = true
          return
        }

        // 'm' / 'M' -> Mute (VLC: m)
        if (event.key === Qt.Key_M || event.text === "m" || event.text === "M") {
          root.toggleMute()
          event.accepted = true
          return
        }

        // Volume: Ctrl + Up / Down (VLC: Ctrl+Up / Ctrl+Down)
        if (event.modifiers & Qt.ControlModifier) {
          if (event.key === Qt.Key_Up) {
            root.adjustVolume(0.05)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Down) {
            root.adjustVolume(-0.05)
            event.accepted = true
            return
          }
        }

        // Jumps with Left / Right:
        // Shift + Left/Right -> 3s extra-short jump (VLC: Shift+Left/Right)
        if (event.modifiers & Qt.ShiftModifier) {
          if (event.key === Qt.Key_Left) { root.seekDelta(-3); event.accepted = true; return }
          if (event.key === Qt.Key_Right) { root.seekDelta(3); event.accepted = true; return }
        }
        // Alt + Left/Right -> 10s short jump (VLC: Alt+Left/Right)
        if (event.modifiers & Qt.AltModifier) {
          if (event.key === Qt.Key_Left) { root.seekDelta(-10); event.accepted = true; return }
          if (event.key === Qt.Key_Right) { root.seekDelta(10); event.accepted = true; return }
        }
        // Ctrl + Left/Right -> 60s medium jump (VLC: Ctrl+Left/Right)
        if (event.modifiers & Qt.ControlModifier) {
          if (event.key === Qt.Key_Left) { root.seekDelta(-60); event.accepted = true; return }
          if (event.key === Qt.Key_Right) { root.seekDelta(60); event.accepted = true; return }
        }

        // 'n' / 'N' or Right arrow -> Next track (VLC: n)
        if (event.key === Qt.Key_N || event.text === "n" || event.text === "N" || event.key === Qt.Key_Right) {
          root.act("next")
          event.accepted = true
          return
        }

        // 'p' / 'P' or Left arrow -> Previous track (VLC: p)
        if (event.key === Qt.Key_P || event.text === "p" || event.text === "P" || event.key === Qt.Key_Left) {
          root.act("previous")
          event.accepted = true
          return
        }

        // Up / Down (without Ctrl) -> Switch source player if multiple players exist
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
          if (root.sourcePlayers && root.sourcePlayers.length > 1) {
            var curIdx = -1
            for (var i = 0; i < root.sourcePlayers.length; i++) {
              if (root.playerKey(root.sourcePlayers[i]) === root.playerKey(root.activePlayer)) {
                curIdx = i
                break
              }
            }
            var delta = event.key === Qt.Key_Down ? 1 : -1
            var nextIdx = (curIdx + delta + root.sourcePlayers.length) % root.sourcePlayers.length
            root.selectPlayer(root.playerKey(root.sourcePlayers[nextIdx]))
          }
          event.accepted = true
          return
        }
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

      // ── App header ────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: Style.space(18)
          height: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            source: root.appIcon
            visible: root.appIcon !== ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize: Qt.size(width * 2, height * 2)
          }

          Text {
            anchors.centerIn: parent
            visible: root.appIcon === ""
            text: "󰝚"
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.appName
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          width: parent.width - Style.space(26)
        }
      }

      // ── Artwork + track + controls ────────────────────────────────
      Row {
        id: mainRow
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          id: art
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.artUrl
            visible: root.artUrl !== "" && status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          id: trackInfo
          width: mainRow.width - art.width - controls.width - mainRow.spacing * 2
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }

        Row {
          id: controls
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒮"
            foreground: root.bar.foreground
            enabled: root.activePlayer && root.activePlayer.canGoPrevious
            tooltip: "上一曲"
            bar: root.bar
            onClicked: root.act("previous")
          }

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.isPlaying ? "󰏤" : "󰐊"
            iconSize: Style.font.iconLarge
            // Nerd Font play/pause glyphs sit low in their line box.
            iconOffsetY: -iconSize * 0.08
            foreground: root.bar.foreground
            enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
            tooltip: root.isPlaying ? "暂停" : "播放"
            bar: root.bar
            onClicked: root.act("playPause")
          }

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒭"
            foreground: root.bar.foreground
            enabled: root.activePlayer && root.activePlayer.canGoNext
            tooltip: "下一曲"
            bar: root.bar
            onClicked: root.act("next")
          }

          ControlButton {
            id: repeatBtn
            anchors.verticalCenter: parent.verticalCenter
            iconText: {
              if (root.activePlayer && root.activePlayer.loopState === MprisLoopState.Track) return "󰑘"
              if (root.activePlayer && root.activePlayer.loopState === MprisLoopState.Playlist) return "󰑖"
              return "󰑗"
            }
            foreground: root.isLoopActive ? Color.accent : Qt.darker(root.bar.foreground, 1.8)
            enabled: root.activePlayer && (root.activePlayer.loopSupported !== false)
            tooltip: root.loopStatusText
            bar: root.bar
            onClicked: root.cycleRepeat()
          }

          ControlButton {
            id: shuffleBtn
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒝"
            foreground: root.isShuffleActive ? Color.accent : Qt.darker(root.bar.foreground, 1.8)
            enabled: root.activePlayer && (root.activePlayer.shuffleSupported !== false)
            tooltip: root.shuffleStatusText
            bar: root.bar
            onClicked: root.toggleShuffle()
          }
        }
      }

      // ── Seek bar ──────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(10)
        visible: root.hasLength

        Text {
          id: elapsed
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(seek.dragging ? seek.liveValue : root.trackPosition)
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: Style.space(40)
        }

        PanelSlider {
          id: seek
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - elapsed.width - total.width - parent.spacing * 2
          bar: root.bar
          minimum: 0
          maximum: Math.max(1, root.trackLength)
          step: 1
          value: root.trackPosition
          enabled: root.activePlayer && root.activePlayer.canSeek
          opacity: enabled ? 1.0 : 0.6
          onReleased: function(v) {
            if (root.activePlayer && root.activePlayer.canSeek) root.activePlayer.position = v
          }
        }

        Text {
          id: total
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(root.trackLength)
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: Style.space(40)
          horizontalAlignment: Text.AlignRight
        }
      }

      // ── Source picker (only with several players) ─────────────────
      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData
            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.playerKey(root.activePlayer) === root.playerKey(player)
            readonly property string sourceApp: player ? (player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceTrack: player ? [player.trackTitle, player.trackArtist].filter(Boolean).join(" · ") : ""

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰐊" : "󰏤"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: sourceRow.sourceApp
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: sourceRow.sourceTrack
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectPlayer(root.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
}
