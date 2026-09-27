import QtQuick
import Quickshell.Io
import "Radar.js" as Radar

QtObject {
  id: root

  property bool active: false
  property var coordinates: null
  readonly property string locationKey: Radar.locationKey(coordinates)
  property bool nativeReady: false
  property var frames: []
  property int selectedIndex: -1
  property bool followingNewest: true
  property bool playing: false
  property bool loading: false
  property bool stale: false
  property string error: ""
  property int newestTime: frames.length ? frames[frames.length - 1].time : 0
  property int nowSeconds: Math.floor(Date.now() / 1000)
  readonly property var selectedFrame: selectedIndex >= 0 && selectedIndex < frames.length ? frames[selectedIndex] : null
  readonly property bool live: selectedFrame !== null && selectedFrame.time === newestTime &&
    selectedReady && followingNewest && !stale && !error && nowSeconds - newestTime >= -120 &&
    nowSeconds - newestTime < 1200
  property int lastManifestAt: 0
  property int generation: 0
  property bool pendingRefresh: false
  property bool manifestDraining: false
  property bool playbackHold: false
  property var requestTimes: []
  property var readyUrls: ({})
  property var failedUrls: ({})
  readonly property bool selectedReady: selectedFrame !== null && readyUrls[selectedFrame.url] === true

  Component.onCompleted: packageCheck.running = true
  Component.onDestruction: stop()

  onActiveChanged: {
    if (active) refresh()
    else {
      stop()
      readyUrls = ({})
      failedUrls = ({})
    }
  }

  onSelectedIndexChanged: if (error === "Radar image unavailable") error = ""

  onNativeReadyChanged: if (active) refresh()

  onLocationKeyChanged: {
    stop()
    frames = []
    readyUrls = ({})
    failedUrls = ({})
    selectedIndex = -1
    followingNewest = true
    lastManifestAt = 0
    stale = false
    error = ""
    if (active) refresh()
  }

  function stop() {
    generation++
    pendingRefresh = false
    playing = false
    loading = false
    if (manifestProc.running) {
      manifestDraining = true
      manifestProc.running = false
    }
  }

  function reserve(count) {
    var now = Date.now()
    requestTimes = requestTimes.filter(function(value) { return now - value < 60000 })
    if (requestTimes.length + count > 60) return false
    var next = requestTimes.slice()
    for (var i = 0; i < count; i++) next.push(now)
    requestTimes = next
    return true
  }

  function requestImage(url) {
    if (!active || !frames.some(function(frame) { return frame.url === url })) return false
    if (!reserve(1)) {
      error = "Radar request limit reached"
      return false
    }
    return true
  }

  function markReady(url) {
    if (!frames.some(function(frame) { return frame.url === url })) return
    var next = Object.assign({}, readyUrls)
    next[url] = true
    readyUrls = next
  }

  function markFailed(url) {
    if (!frames.some(function(frame) { return frame.url === url })) return
    var next = Object.assign({}, failedUrls)
    next[url] = true
    failedUrls = next
    if (selectedFrame && selectedFrame.url === url) error = "Radar image unavailable"
  }

  function refresh() {
    if (!active || !nativeReady || !locationKey) return
    nowSeconds = Math.floor(Date.now() / 1000)
    if (lastManifestAt && nowSeconds - lastManifestAt < 300) return
    if (manifestDraining || manifestProc.running) {
      pendingRefresh = true
      return
    }
    if (!reserve(1)) {
      error = "Radar request limit reached"
      return
    }
    pendingRefresh = false
    loading = true
    error = ""
    manifestProc.requestKey = locationKey
    manifestProc.requestGeneration = ++generation
    manifestProc.running = true
  }

  function acceptManifest(raw, key, serial) {
    if (!active || key !== locationKey || serial !== generation) return
    loading = false
    try {
      var parsed = Radar.parseManifest(raw, coordinates, Math.floor(Date.now() / 1000))
      var oldTime = selectedFrame ? selectedFrame.time : -1
      readyUrls = ({})
      failedUrls = ({})
      frames = parsed
      lastManifestAt = Math.floor(Date.now() / 1000)
      stale = false
      error = parsed.length ? "" : "No recent radar frames"
      if (followingNewest) selectedIndex = parsed.length - 1
      else {
        var found = parsed.findIndex(function(frame) { return frame.time === oldTime })
        selectedIndex = found >= 0 ? found : Math.min(selectedIndex, parsed.length - 1)
      }
    } catch (e) {
      stale = frames.length > 0
      error = "Radar temporarily unavailable"
    }
  }

  function select(index) {
    if (index < 0 || index >= frames.length) return
    playing = false
    selectedIndex = index
    followingNewest = index === frames.length - 1
  }

  function togglePlayback() {
    if (frames.length < 2) return
    playing = !playing
    playbackHold = false
    if (playing) followingNewest = false
  }

  property Process packageCheck: Process {
    command: ["pacman", "-Qq", "qt6-location", "maplibre-native-qt"]
    // qmllint disable signal-handler-parameters
    onExited: function(exitCode) { root.nativeReady = exitCode === 0 }
    // qmllint enable signal-handler-parameters
  }

  property Process manifestProc: Process {
    property string requestKey: ""
    property int requestGeneration: 0
    command: ["curl", "-fsS", "--max-time", "8", "https://api.rainviewer.com/public/weather-maps.json"]
    stdout: StdioCollector {
      waitForEnd: true
      // qmllint disable missing-property
      onStreamFinished: {
        if (root.manifestDraining) {
          root.manifestDraining = false
          if (root.pendingRefresh && root.active) {
            root.pendingRefresh = false
            Qt.callLater(root.refresh)
          }
          return
        }
        root.acceptManifest(text, root.manifestProc.requestKey, root.manifestProc.requestGeneration)
      }
      // qmllint enable missing-property
    }
    // qmllint disable signal-handler-parameters
    onExited: {
      if (root.pendingRefresh && !root.manifestDraining && root.active) {
        root.pendingRefresh = false
        Qt.callLater(root.refresh)
      }
    }
    // qmllint enable signal-handler-parameters
  }

  property Timer refreshTimer: Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: root.active && root.nativeReady && root.locationKey !== ""
    onTriggered: root.refresh()
  }

  property Timer clockTimer: Timer {
    interval: 60000
    repeat: true
    running: root.active
    onTriggered: root.nowSeconds = Math.floor(Date.now() / 1000)
  }

  property Timer playbackTimer: Timer {
    interval: 750
    repeat: true
    running: root.active && root.playing && root.frames.length > 1
    onTriggered: {
      var next = root.selectedIndex + 1
      while (next < root.frames.length && root.readyUrls[root.frames[next].url] !== true) next++
      if (next < root.frames.length) {
        root.selectedIndex = next
        root.playbackHold = false
      } else if (root.playbackHold) {
        var first = root.frames.findIndex(function(frame) { return root.readyUrls[frame.url] === true })
        if (first >= 0) root.selectedIndex = first
        root.playbackHold = false
      } else root.playbackHold = true
    }
  }
}
