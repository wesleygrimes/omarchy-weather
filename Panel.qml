pragma ComponentBehavior: Bound

// The injected host and theme objects expose runtime properties.
// qmllint disable missing-property
import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

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
    weatherModel.reloadLocation()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    weatherModel.reloadLocation()
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

  property bool editingLocation: false
  readonly property var view: weatherModel.view
  readonly property var savedLocation: weatherModel.savedLocation
  readonly property var locationSuggestions: weatherModel.locationSuggestions
  property int suggestionIndex: 0
  onLocationSuggestionsChanged: suggestionIndex = 0
  readonly property bool savingLocation: weatherModel.savingLocation
  readonly property var current: view && view.current ? view.current : null
  readonly property var forecastDays: view && view.forecast ? view.forecast : []
  readonly property string label: current ? current.icon : ""
  readonly property int heroConditionIconSize: 64
  readonly property int heroTemperatureSize: 56
  readonly property string locationPinGlyph: ""
  readonly property string clearLocationGlyph: "✕"
  readonly property string savingLocationGlyph: "󰦖"
  property bool mapExpanded: false
  readonly property string radarStyle: (Color.background.r * 0.2126 + Color.background.g * 0.7152 + Color.background.b * 0.0722) < 0.45
    ? "dark" : "positron"
  readonly property var mapCoordinates: view && view.coordinates ? view.coordinates : null

  WeatherModel {
    id: weatherModel
    unit: root.setting("unit", "")
    refreshInterval: root.setting("refreshMinutes", 15)
    onSaveCompleted: root.cancelEditingLocation()
  }

  RadarModel {
    id: radarModel
    active: root.opened
    coordinates: root.mapCoordinates
  }

  function radarTime(timestamp) {
    return timestamp ? Qt.formatTime(new Date(timestamp * 1000), "HH:mm") : "--:--"
  }

  function installMapSupport() {
    if (!root.bar) return
    root.bar.run("omarchy-launch-floating-terminal-with-presentation 'omarchy pkg add maplibre-native-qt qt6-location && pacman -Qq maplibre-native-qt qt6-location >/dev/null && omarchy restart shell'")
  }

  function refresh() {
    weatherModel.refresh()
  }

  function showStatus() {
    weatherModel.showStatus()
  }

  function startEditingLocation() {
    editingLocation = true
    weatherModel.beginLocationSearch()
    suggestionIndex = 0
    Qt.callLater(function() {
      locationField.text = root.savedLocation.name
      locationField.selectAll()
      locationField.forceActiveFocus()
    })
  }

  function cancelEditingLocation() {
    editingLocation = false
    weatherModel.cancelLocationSearch()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitLocation() {
    weatherModel.commitLocation(locationField.text, suggestionIndex)
  }

  function clearLocation() {
    weatherModel.clearLocation()
  }

  function pickSuggestion(suggestion) {
    weatherModel.pickSuggestion(suggestion)
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

              onTextChanged: if (root.editingLocation && !root.savingLocation) weatherModel.searchLocation(text)

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
            id: suggestionDelegate
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
                text: suggestionDelegate.modelData.name
                color: suggestionDelegate.index === root.suggestionIndex ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                visible: text !== ""
                text: suggestionDelegate.modelData.description
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
              onPositionChanged: root.suggestionIndex = suggestionDelegate.index
              onClicked: root.pickSuggestion(suggestionDelegate.modelData)
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
          width: astronomyRow.width
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: astronomyRow.spacing

          Repeater {
            model: root.forecastDays

            Row {
              id: forecastDelegate
              required property var modelData
              required property int index
              width: astronomyRow.columnWidth
              spacing: Style.space(4)

              Text {
                width: forecastDelegate.index === 2 ? moonGlyph.width : sunriseGlyph.width
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: forecastDelegate.modelData.icon
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  textFormat: Text.PlainText
                  text: forecastDelegate.modelData.weekday
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }

                Row {
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: forecastDelegate.modelData.high
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: forecastDelegate.modelData.low
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

      Rectangle {
        visible: !!root.current
        width: parent.width
        height: Style.spacing.hairline
        color: root.bar.foreground
        opacity: 0.12
      }

      Item {
        visible: !!root.current
        width: parent.width
        height: Style.space(64)

        Row {
          id: astronomyRow
          readonly property real columnWidth: Math.min(Style.space(132), width / 3)
          width: mapFrame.width
          height: parent.height
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: (width - columnWidth * 3) / 2

          Item {
            width: astronomyRow.columnWidth
            height: parent.height
            SunEventGlyph {
              id: sunriseGlyph
              rising: true
              foreground: root.bar.foreground
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              opacity: 0.75
            }
            Column {
              anchors.left: sunriseGlyph.right
              anchors.leftMargin: Style.space(4)
              anchors.top: parent.top
              anchors.topMargin: Style.space(9)
              spacing: Style.space(5)
              Text {
                text: "SUNRISE"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.view && root.view.sun && root.view.sun.sunrise ? root.view.sun.sunrise : "—"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          Item {
            width: astronomyRow.columnWidth
            height: parent.height
            SunEventGlyph {
              id: sunsetGlyph
              rising: false
              foreground: root.bar.foreground
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              opacity: 0.75
            }
            Column {
              anchors.left: sunsetGlyph.right
              anchors.leftMargin: Style.space(4)
              anchors.top: parent.top
              anchors.topMargin: Style.space(9)
              spacing: Style.space(5)
              Text {
                text: "SUNSET"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.view && root.view.sun && root.view.sun.sunset ? root.view.sun.sunset : "—"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          Item {
            width: astronomyRow.columnWidth
            height: parent.height
            MoonGlyph {
              id: moonGlyph
              width: 34
              height: 34
              phase: root.view && root.view.moon ? root.view.moon.phase : ""
              illumination: root.view && root.view.moon ? root.view.moon.illumination : ""
              foreground: root.bar.foreground
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              opacity: 0.75
            }
            Column {
              anchors.left: moonGlyph.right
              anchors.leftMargin: Style.space(4)
              anchors.top: parent.top
              anchors.topMargin: Style.space(9)
              spacing: Style.space(5)
              Text {
                text: "MOON"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                width: Style.space(94)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                textFormat: Text.PlainText
                text: root.view && root.view.moon && root.view.moon.phase ? root.view.moon.phase : "—"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }

      Rectangle {
        visible: !!root.current
        width: parent.width
        height: Style.spacing.hairline
        color: root.bar.foreground
        opacity: 0.12
      }

      Column {
        visible: !!root.current
        width: parent.width
        spacing: Style.space(9)

        Item {
          id: radarHeader
          width: parent.width - Style.space(32)
          height: Style.space(20)
          anchors.horizontalCenter: parent.horizontalCenter
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "RADAR"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.bold: true
            font.pixelSize: Style.font.body
            font.letterSpacing: 1
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: radarModel.live ? root.radarTime(radarModel.selectedFrame.time) + "  ·  ● LIVE" : radarModel.loading ? "LOADING" :
              radarModel.selectedFrame && !radarModel.selectedReady ?
                (radarModel.failedUrls[radarModel.selectedFrame.url] ? "FRAME UNAVAILABLE" : "LOADING FRAME") :
                radarModel.selectedFrame ? root.radarTime(radarModel.selectedFrame.time) : ""
            color: radarModel.live ? Color.accent : Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1
          }
        }

        Rectangle {
          id: mapFrame
          width: parent.width - Style.space(32)
          height: root.mapExpanded ? Style.space(330) : Style.space(235)
          anchors.horizontalCenter: parent.horizontalCenter
          color: "transparent"
          border.color: root.bar.foreground
          border.width: 1
          radius: Math.min(Style.cornerRadius, 3)
          clip: true

          Loader {
            id: radarMapLoader
            anchors.fill: parent
            anchors.margins: 1
            active: radarModel.nativeReady && root.opened && !!root.mapCoordinates
            source: "RadarMap.qml"
            onLoaded: {
              item.radar = radarModel
              item.coordinates = Qt.binding(function() { return root.mapCoordinates })
              item.styleName = Qt.binding(function() { return root.radarStyle })
              item.locationName = Qt.binding(function() { return root.view ? root.view.location.name : "" })
              item.foreground = Qt.binding(function() { return root.bar.foreground })
              item.fontFamily = Qt.binding(function() { return root.bar.fontFamily })
              item.labelSize = Style.font.caption
            }
          }

          Column {
            visible: !radarModel.nativeReady || !root.mapCoordinates || radarMapLoader.status === Loader.Error
            anchors.centerIn: parent
            spacing: Style.space(9)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: !radarModel.nativeReady ? "Map support is ready to install" :
                !root.mapCoordinates ? "Map location unavailable" : "Map support could not load"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Rectangle {
              visible: !radarModel.nativeReady
              anchors.horizontalCenter: parent.horizontalCenter
              width: installLabel.implicitWidth + Style.space(18)
              height: installLabel.implicitHeight + Style.space(10)
              radius: Style.cornerRadius
              color: Style.hoverFillFor(root.bar.foreground, Color.accent)
              Text {
                id: installLabel
                anchors.centerIn: parent
                text: "Install map support"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.installMapSupport()
              }
            }
          }

          Rectangle {
            id: attribution
            property bool expanded: false
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(6)
            width: expanded ? Math.min(mapFrame.width - Style.space(12), Style.space(400)) : Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: Color.background
            visible: radarMapLoader.status === Loader.Ready && radarMapLoader.active

            function toggle() { expanded = !expanded }
            onVisibleChanged: expanded = false
            Text {
              id: attributionLinks
              visible: attribution.expanded
              anchors.left: parent.left
              anchors.right: attributionToggle.left
              anchors.margins: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.StyledText
              text: '<a href="https://openfreemap.org/">OpenFreeMap</a> · <a href="https://openmaptiles.org/">OpenMapTiles</a> · © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> · <a href="https://www.rainviewer.com/">RainViewer</a>'
              linkColor: Color.foreground
              color: Color.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              onLinkActivated: function(link) { Qt.openUrlExternally(link) }
            }
            Rectangle {
              id: attributionToggle
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              width: Style.space(26)
              height: width
              radius: Style.cornerRadius
              color: activeFocus ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"
              activeFocusOnTab: true
              Accessible.role: Accessible.Button
              Accessible.name: attribution.expanded ? "Hide map attribution" : "Show map attribution"
              Accessible.onPressAction: attribution.toggle()
              Keys.onSpacePressed: attribution.toggle()
              Keys.onReturnPressed: attribution.toggle()
              Text {
                anchors.centerIn: parent
                text: attribution.expanded ? "×" : "ⓘ"
                color: Color.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: attribution.toggle()
              }
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(8)
            width: Style.space(28)
            height: width
            color: Style.hoverFillFor(root.bar.foreground, Color.accent)
            radius: Style.cornerRadius
            Text {
              anchors.centerIn: parent
              text: root.mapExpanded ? "↙" : "⤢"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.mapExpanded = !root.mapExpanded
            }
          }
        }

        Item {
          id: radarControls
          width: parent.width - Style.space(32)
          height: Style.space(24)
          anchors.horizontalCenter: parent.horizontalCenter

          Text {
            id: playButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: radarModel.playing ? "Ⅱ" : "▶"
            color: root.bar.foreground
            opacity: radarModel.frames.length > 1 ? 1 : 0.4
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            MouseArea {
              anchors.fill: parent
              enabled: radarModel.frames.length > 1
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: radarModel.togglePlayback()
            }
          }

          Rectangle {
            id: scrubTrack
            anchors.left: playButton.right
            anchors.leftMargin: Style.space(16)
            anchors.right: selectedRadarTime.left
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            height: 2
            color: root.bar.foreground
            opacity: 0.45
            Rectangle {
              width: Style.space(9)
              height: width
              radius: width / 2
              color: root.bar.foreground
              x: radarModel.frames.length > 1 ?
                (radarModel.selectedIndex / (radarModel.frames.length - 1)) * (scrubTrack.width - width) : 0
              anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
              anchors.fill: parent
              anchors.topMargin: -Style.space(10)
              anchors.bottomMargin: -Style.space(10)
              enabled: radarModel.frames.length > 1
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onPressed: function(mouse) {
                radarModel.select(Math.round(Math.max(0, Math.min(1, mouse.x / width)) * (radarModel.frames.length - 1)))
              }
              onPositionChanged: function(mouse) {
                if (pressed) radarModel.select(Math.round(Math.max(0, Math.min(1, mouse.x / width)) * (radarModel.frames.length - 1)))
              }
            }
          }

          Text {
            id: selectedRadarTime
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: radarModel.selectedFrame ? root.radarTime(radarModel.selectedFrame.time) : "--:--"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Text {
          visible: radarModel.nativeReady && radarModel.error !== ""
          anchors.horizontalCenter: parent.horizontalCenter
          text: radarModel.error
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
  }
  }

}
