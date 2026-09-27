import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

QtObject {
  id: root

  property var lastGoodConditions: null
  property var lastGoodForecast: null
  property string detectedPlaceName: ""
  property var savedLocation: Model.emptyLocation()
  readonly property string locationQuery: Model.locationQuery(savedLocation)
  readonly property bool hasSavedCoordinates: Model.hasCoordinates(savedLocation)
  property bool conditionsDraining: false
  property bool forecastDraining: false

  onLocationQueryChanged: {
    resetFetchRetries()
    stopInFlightFetches()
    lastGoodConditions = null
    lastGoodForecast = null
    detectedPlaceName = ""
    Qt.callLater(refresh)
  }

  property FileView locationFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: if (root.pendingLocation === null) root.savedLocation = Model.parseSavedLocation(text())
    onLoadFailed: if (root.pendingLocation === null) root.savedLocation = Model.emptyLocation()
  }

  property Timer rereadSavedLocationAfterStartup: Timer {
    interval: 1500
    running: true
    onTriggered: root.locationFile.reload()
  }

  property int conditionsRetries: 0
  property int forecastRetries: 0

  property bool searchingLocation: false
  property var pendingLocation: null
  readonly property bool savingLocation: pendingLocation !== null
  property var locationSuggestions: []
  property string queuedSearchQuery: ""
  property string inFlightSearchQuery: ""

  readonly property var view: Model.buildView({
    location: root.savedLocation,
    detectedPlaceName: root.detectedPlaceName,
    conditions: root.lastGoodConditions,
    forecast: root.lastGoodForecast,
    unit: root.unit,
    locale: Qt.locale().name,
    today: Qt.formatDate(new Date(), "yyyy-MM-dd"),
    formatWeekday: function(date) { return Qt.formatDate(date, "dddd") }
  })
  property string unit: ""
  property var refreshInterval: 15
  readonly property int refreshMinutes: Math.max(1, parseInt(refreshInterval, 10) || 15)

  signal saveCompleted()

  function reloadLocation() {
    locationFile.reload()
  }

  function resetFetchRetries() {
    conditionsRetries = 0
    forecastRetries = 0
    conditionsRetryTimer.stop()
    forecastRetryTimer.stop()
  }

  function stopInFlightFetches() {
    if (conditionsProc.running) {
      conditionsDraining = true
      conditionsProc.running = false
    }
    if (forecastProc.running) {
      forecastDraining = true
      forecastProc.running = false
    }
  }

  function refresh() {
    resetFetchRetries()
    if (!conditionsProc.running && !conditionsDraining) {
      conditionsProc.requestQuery = locationQuery
      conditionsProc.running = true
    }
    if (root.locationQuery === "" && !detectedPlaceProc.running) detectedPlaceProc.running = true
    fetchForecast(root.lastGoodConditions)
  }

  function fetchForecast(conditions) {
    if (forecastProc.running || forecastDraining) return
    var coordinates = Model.forecastCoordinates(root.savedLocation, conditions || root.lastGoodConditions)
    if (!coordinates) return
    forecastProc.command = ["curl", "-fsS", "--max-time", "5", Model.forecastUrl(coordinates)]
    forecastProc.requestQuery = locationQuery
    forecastProc.running = true
  }

  function beginLocationSearch() {
    cancelLocationSearch()
    searchingLocation = true
  }

  function cancelLocationSearch() {
    searchingLocation = false
    locationSearchDebounce.stop()
    queuedSearchQuery = ""
    locationSuggestions = []
  }

  function commitLocation(text, selectedIndex) {
    var location = Model.commitLocation(text, locationSuggestions, selectedIndex)
    saveLocation(location)
  }

  function clearLocation() {
    saveLocation(Model.emptyLocation())
  }

  function pickSuggestion(suggestion) {
    if (!suggestion) return
    saveLocation(suggestion)
  }

  function saveLocation(location) {
    if (pendingLocation !== null) return
    pendingLocation = {
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude
    }
    persistLocation(pendingLocation)
  }

  function completeLocationSave() {
    if (pendingLocation === null) return
    pendingLocation = null
    cancelLocationSearch()
    saveCompleted()
  }

  function persistLocation(location) {
    if (location.name && location.latitude !== null && location.longitude !== null)
      saveLocationProc.command = ["omarchy-weather-location", "--set", location.name, location.latitude + "," + location.longitude]
    else if (location.name)
      saveLocationProc.command = ["omarchy-weather-location", "--set", location.name]
    else
      saveLocationProc.command = ["omarchy-weather-location", "--clear"]
    saveLocationProc.running = true
  }

  function searchLocation(text) {
    queuedSearchQuery = String(text || "").trim()
    locationSearchDebounce.restart()
  }

  function queueLocationSearch() {
    if (!searchingLocation || queuedSearchQuery.length < 2) {
      locationSuggestions = []
      return
    }
    if (!locationSearchProc.running) fetchQueuedLocationSearch()
  }

  function fetchQueuedLocationSearch() {
    inFlightSearchQuery = queuedSearchQuery
    locationSearchProc.command = ["curl", "-fsS", "--max-time", "5", Model.locationSearchUrl(inFlightSearchQuery)]
    locationSearchProc.running = true
  }

  property Process conditionsProc: Process {
    property string requestQuery: ""
    command: ["curl", "-fsS", "--max-time", "10", Model.conditionsUrl(root.locationQuery)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.conditionsDraining) {
          root.conditionsDraining = false
          Qt.callLater(root.refresh)
          return
        }
        // qmllint disable missing-property
        if (root.conditionsProc.requestQuery !== root.locationQuery) return
        // qmllint enable missing-property
        var raw = String(text || "").trim()
        if (!raw) {
          root.retryConditionsFetch()
          return
        }
        try {
          var parsed = JSON.parse(raw)
          root.lastGoodConditions = parsed
          root.conditionsRetries = 0
          if (!root.hasSavedCoordinates)
            root.fetchForecast(parsed)
        } catch (e) {
          root.retryConditionsFetch()
        }
      }
    }
  }

  function retryConditionsFetch() {
    if (conditionsRetries >= 3) return
    conditionsRetries++
    conditionsRetryTimer.restart()
  }

  property Timer conditionsRetryTimer: Timer {
    interval: 2500
    onTriggered: if (!root.conditionsProc.running) root.conditionsProc.running = true
  }

  function retryForecastFetch() {
    if (forecastRetries >= 3) return
    forecastRetries++
    forecastRetryTimer.restart()
  }

  property Timer forecastRetryTimer: Timer {
    interval: 2500
    onTriggered: root.fetchForecast(null)
  }

  property Process forecastProc: Process {
    property string requestQuery: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.forecastDraining) {
          root.forecastDraining = false
          Qt.callLater(root.refresh)
          return
        }
        // qmllint disable missing-property
        if (root.forecastProc.requestQuery !== root.locationQuery) return
        // qmllint enable missing-property
        var raw = String(text || "").trim()
        if (!raw) {
          root.retryForecastFetch()
          return
        }
        try {
          var parsed = JSON.parse(raw)
          root.lastGoodForecast = parsed
          root.forecastRetries = 0
        } catch (e) {
          root.retryForecastFetch()
        }
      }
    }
  }

  property Process locationSearchProc: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.locationSuggestions = root.searchingLocation && root.queuedSearchQuery === root.inFlightSearchQuery
          ? Model.parseLocationSuggestions(text) : []
        if (root.queuedSearchQuery !== root.inFlightSearchQuery) Qt.callLater(root.queueLocationSearch)
      }
    }
  }

  property Timer locationSearchDebounce: Timer {
    interval: 300
    onTriggered: root.queueLocationSearch()
  }

  property Process saveLocationProc: Process {
    // Quickshell's type metadata omits QProcess::ExitStatus; only exitCode is used.
    // qmllint disable signal-handler-parameters
    onExited: function(exitCode) {
      if (root.pendingLocation === null) return
      if (exitCode !== 0) {
        root.pendingLocation = null
        return
      }
      root.savedLocation = root.pendingLocation
      if (root.pendingLocation.name === "")
        root.detectedPlaceName = ""
      root.completeLocationSave()
      root.locationFile.reload()
      Qt.callLater(root.refresh)
    }
    // qmllint enable signal-handler-parameters
  }

  property Process detectedPlaceProc: Process {
    command: ["curl", "-fsS", "--max-time", "4", Model.detectedPlaceUrl()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.detectedPlaceName = Model.parseDetectedPlaceName(text)
      }
    }
  }

  property Timer refreshTimer: Timer {
    interval: root.refreshMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  function showStatus() {
    statusProc.running = true
  }

  property Process statusProc: Process {
    command: ["sh", "-c", "omarchy-notification-send \"$(omarchy-weather-status)\""]
  }
}
