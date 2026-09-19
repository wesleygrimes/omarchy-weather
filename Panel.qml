import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "wesgrimes.weather"
  ipcTarget: "wesgrimes.weather"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barSlotWidget: hostWidget || root

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    locationFile.reload()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    locationFile.reload()
    root.refresh()
    suppressHoverRevealAfterPopoutHandoff()
  }

  function suppressHoverRevealAfterPopoutHandoff() {
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    if (root.editingLocation) root.cancelEditingLocation()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barSlotWidget, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  property var lastGoodConditions: null
  property var lastGoodForecast: null
  property string detectedPlaceName: ""
  property var savedLocation: Model.emptyLocation()
  readonly property string locationQuery: Model.locationQuery(savedLocation)
  readonly property bool hasSavedCoordinates: Model.hasCoordinates(savedLocation)

  onLocationQueryChanged: {
    if (savingLocation) waitingForWeatherAfterSave = true
    resetFetchRetries()
    stopInFlightFetches()
    Qt.callLater(refresh)
  }

  property FileView locationFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.savedLocation = Model.parseSavedLocation(text())
    onLoadFailed: root.savedLocation = Model.emptyLocation()
  }

  Timer {
    id: rereadSavedLocationAfterStartup
    interval: 1500
    running: true
    onTriggered: locationFile.reload()
  }

  property int conditionsRetries: 0
  property int forecastRetries: 0

  property bool editingLocation: false
  property bool savingLocation: false
  property bool waitingForWeatherAfterSave: false
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string queuedSearchQuery: ""
  property string inFlightSearchQuery: ""

  readonly property var view: Model.buildView({
    location: root.savedLocation,
    detectedPlaceName: root.detectedPlaceName,
    conditions: root.lastGoodConditions,
    forecast: root.lastGoodForecast,
    unit: setting("unit", ""),
    locale: Qt.locale().name,
    today: Qt.formatDate(new Date(), "yyyy-MM-dd"),
    formatWeekday: function(date) { return Qt.formatDate(date, "dddd") }
  })
  readonly property var current: view && view.current ? view.current : null
  readonly property var forecastDays: view && view.forecast ? view.forecast : []
  readonly property string label: current ? current.icon : ""
  readonly property int heroConditionIconSize: 64
  readonly property int heroTemperatureSize: 56
  readonly property string locationPinGlyph: ""
  readonly property string clearLocationGlyph: "✕"
  readonly property string savingLocationGlyph: "󰦖"

  readonly property int refreshMinutes: Math.max(1, parseInt(setting("refreshMinutes", 15), 10) || 15)

  function resetFetchRetries() {
    conditionsRetries = 0
    forecastRetries = 0
  }

  function stopInFlightFetches() {
    conditionsProc.running = false
    forecastProc.running = false
  }

  function refresh() {
    resetFetchRetries()
    if (!conditionsProc.running) conditionsProc.running = true
    if (root.locationQuery === "" && !detectedPlaceProc.running) detectedPlaceProc.running = true
    fetchForecast(root.lastGoodConditions)
  }

  function fetchForecast(conditions) {
    if (forecastProc.running) return
    var coordinates = Model.forecastCoordinates(root.savedLocation, conditions || root.lastGoodConditions)
    if (!coordinates) return
    forecastProc.command = ["curl", "-fsS", "--max-time", "5", Model.forecastUrl(coordinates)]
    forecastProc.running = true
  }

  function startEditingLocation() {
    editingLocation = true
    savingLocation = false
    waitingForWeatherAfterSave = false
    locationSuggestions = []
    suggestionIndex = 0
    Qt.callLater(function() {
      locationField.text = root.savedLocation.name
      locationField.selectAll()
      locationField.forceActiveFocus()
    })
  }

  function cancelEditingLocation() {
    editingLocation = false
    savingLocation = false
    waitingForWeatherAfterSave = false
    locationSuggestions = []
    locationSearchDebounce.stop()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitLocation() {
    var location = Model.commitLocation(locationField.text, locationSuggestions, suggestionIndex)
    if (location.name === "") {
      clearLocation()
      return
    }
    savingLocation = true
    waitingForWeatherAfterSave = false
    savedLocation = {
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude
    }
    persistLocation(location.name, location.latitude, location.longitude)
  }

  function clearLocation() {
    persistLocation("", null, null)
    detectedPlaceName = ""
    cancelEditingLocation()
  }

  function pickSuggestion(suggestion) {
    if (!suggestion) return
    savingLocation = true
    waitingForWeatherAfterSave = false
    savedLocation = {
      name: suggestion.name,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude
    }
    persistLocation(suggestion.name, suggestion.latitude, suggestion.longitude)
  }

  function dismissEditorAfterSave() {
    if (savingLocation && waitingForWeatherAfterSave) cancelEditingLocation()
  }

  function persistLocation(name, latitude, longitude) {
    if (name && latitude !== null && longitude !== null)
      saveLocationProc.command = ["omarchy-weather-location", "--set", name, latitude + "," + longitude]
    else if (name)
      saveLocationProc.command = ["omarchy-weather-location", "--set", name]
    else
      saveLocationProc.command = ["omarchy-weather-location", "--clear"]
    saveLocationProc.running = true
  }

  function queueLocationSearch() {
    var query = locationField.text.trim()
    if (query.length < 2) {
      locationSuggestions = []
      return
    }
    queuedSearchQuery = query
    if (!locationSearchProc.running) fetchQueuedLocationSearch()
  }

  function fetchQueuedLocationSearch() {
    inFlightSearchQuery = queuedSearchQuery
    locationSearchProc.command = ["curl", "-fsS", "--max-time", "5", Model.locationSearchUrl(inFlightSearchQuery)]
    locationSearchProc.running = true
  }

  Process {
    id: conditionsProc
    command: ["curl", "-fsS", "--max-time", "10", Model.conditionsUrl(root.locationQuery)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.retryConditionsFetch()
          return
        }
        try {
          var parsed = JSON.parse(raw)
          root.lastGoodConditions = parsed
          root.conditionsRetries = 0
          if (Model.locationSaveCompletesOn(root.hasSavedCoordinates, "conditions"))
            root.dismissEditorAfterSave()
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

  Timer {
    id: conditionsRetryTimer
    interval: 2500
    onTriggered: if (!conditionsProc.running) conditionsProc.running = true
  }

  function retryForecastFetch() {
    if (forecastRetries >= 3) return
    forecastRetries++
    forecastRetryTimer.restart()
  }

  Timer {
    id: forecastRetryTimer
    interval: 2500
    onTriggered: root.fetchForecast(null)
  }

  Process {
    id: forecastProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.retryForecastFetch()
          return
        }
        try {
          var parsed = JSON.parse(raw)
          root.lastGoodForecast = parsed
          root.forecastRetries = 0
          if (Model.locationSaveCompletesOn(root.hasSavedCoordinates, "forecast"))
            root.dismissEditorAfterSave()
        } catch (e) {
          root.retryForecastFetch()
        }
      }
    }
  }

  Process {
    id: locationSearchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.locationSuggestions = root.editingLocation ? Model.parseLocationSuggestions(text) : []
        root.suggestionIndex = 0
        if (root.queuedSearchQuery !== root.inFlightSearchQuery) Qt.callLater(root.fetchQueuedLocationSearch)
      }
    }
  }

  Timer {
    id: locationSearchDebounce
    interval: 300
    onTriggered: root.queueLocationSearch()
  }

  Process {
    id: saveLocationProc
    onExited: function(exitCode) {
      if (exitCode !== 0 || !root.savingLocation) return
      locationFile.reload()
      if (!root.waitingForWeatherAfterSave) refreshAfterSavingCurrentLocation()
    }
  }

  function refreshAfterSavingCurrentLocation() {
    waitingForWeatherAfterSave = true
    resetFetchRetries()
    stopInFlightFetches()
    Qt.callLater(root.refresh)
  }

  Process {
    id: detectedPlaceProc
    command: ["curl", "-fsS", "--max-time", "4", Model.detectedPlaceUrl()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.detectedPlaceName = Model.parseDetectedPlaceName(text)
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function edit(): void { root.openFromHotkey(); root.startEditingLocation() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barSlotWidget
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(weatherColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLocation
      onReturnRequested: root.startEditingLocation()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: weatherScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: weatherColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: weatherColumn
          width: weatherScroll.width
          spacing: Style.space(14)

      Item {
        width: parent.width
        height: Math.max(heroLeft.height, heroRight.height)

        Row {
          id: heroLeft
          anchors.left: parent.left
          anchors.leftMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(16)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 5
            text: root.label || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: root.heroConditionIconSize
          }

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: tempBig
              textFormat: Text.PlainText
              text: root.current ? root.current.temperature : "—"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: root.heroTemperatureSize
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: root.current ? root.current.unit : ""
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.top: tempBig.top
              anchors.topMargin: Style.space(10)
            }
          }
        }

        Column {
          id: heroRight
          width: weatherStats.implicitWidth
          anchors.right: parent.right
          anchors.rightMargin: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(12)

          Row {
            visible: !root.editingLocation && root.view && root.view.location.name !== ""
            spacing: Style.space(6)

            TapHandler {
              onTapped: root.startEditingLocation()
            }
            HoverHandler {
              cursorShape: Qt.PointingHandCursor
            }

            Text {
              text: root.locationPinGlyph
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: root.view ? root.view.location.name.toUpperCase() : ""
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.letterSpacing: 1
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            visible: root.editingLocation
            spacing: Style.space(6)

            TextField {
              id: locationField
              width: Style.space(190)
              enabled: !root.savingLocation
              placeholderText: "Search city"
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily

              onTextChanged: if (root.editingLocation && !root.savingLocation) locationSearchDebounce.restart()

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.cancelEditingLocation()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                  if (root.suggestionIndex < root.locationSuggestions.length - 1) root.suggestionIndex++
                  event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                  if (root.suggestionIndex > 0) root.suggestionIndex--
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  root.commitLocation()
                  event.accepted = true
                }
              }
            }

            Rectangle {
              width: Style.space(18)
              height: Style.space(18)
              anchors.verticalCenter: parent.verticalCenter
              radius: Math.min(4, Style.cornerRadius)
              color: !root.savingLocation && clearLocationArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: root.savingLocation ? root.savingLocationGlyph : root.clearLocationGlyph
                font.family: root.bar.fontFamily
                color: Qt.darker(root.bar.foreground, 1.4)
                font.pixelSize: Style.font.bodySmall

                RotationAnimator on rotation {
                  running: root.savingLocation
                  from: 0; to: 360
                  duration: 800
                  loops: Animation.Infinite
                }
              }

              MouseArea {
                id: clearLocationArea
                anchors.fill: parent
                enabled: !root.savingLocation
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.clearLocation()
              }
            }
          }

          Row {
            id: weatherStats
            visible: !!root.current
            spacing: Style.space(36)

            Column {
              spacing: Style.space(5)
              Text {
                text: "FEELS"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.current ? root.current.feelsLike : ""
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Column {
              spacing: Style.space(5)
              Text {
                text: "WIND"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.current ? root.current.wind : ""
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Column {
              spacing: Style.space(5)
              Text {
                text: "HUMID"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.current ? root.current.humidity : ""
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }
          }
        }
      }

      Column {
        visible: root.editingLocation && !root.savingLocation && root.locationSuggestions.length > 0
        width: parent.width
        spacing: 0

        Repeater {
          model: root.locationSuggestions

          Rectangle {
            required property var modelData
            required property int index
            width: parent.width
            height: suggestionRow.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: index === root.suggestionIndex ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

            Row {
              id: suggestionRow
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: modelData.name
                color: index === root.suggestionIndex ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                visible: text !== ""
                text: modelData.description
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: root.suggestionIndex = index
              onClicked: root.pickSuggestion(modelData)
            }
          }
        }
      }

      Text {
        visible: !root.current
        text: "Fetching forecast…"
        color: Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Rectangle {
        visible: root.forecastDays.length > 0
        width: parent.width
        height: Style.spacing.hairline
        color: root.bar.foreground
        opacity: 0.12
      }

      Item {
        visible: root.forecastDays.length > 0
        width: parent.width
        height: forecastRow.height

        Row {
          id: forecastRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(44)

          Repeater {
            model: root.forecastDays

            Row {
              required property var modelData
              required property int index
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.icon
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  textFormat: Text.PlainText
                  text: modelData.weekday
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }

                Row {
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.high
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: modelData.low
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  }
  }

}
