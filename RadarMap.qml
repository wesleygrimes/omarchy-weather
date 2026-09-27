pragma ComponentBehavior: Bound

import QtQuick
import QtLocation
import QtPositioning
import MapLibre 3.0

Item {
  id: root
  property var radar: null
  property var coordinates: null
  property string styleName: "dark"
  property string locationName: ""
  property color foreground
  property string fontFamily: ""
  property int labelSize
  property int displayedIndex: -1
  property int queueIndex: -1
  property int inFlight: 0
  readonly property string centerKey: radar ? radar.locationKey : ""
  readonly property bool hasCoordinates: coordinates && isFinite(Number(coordinates.latitude)) &&
    isFinite(Number(coordinates.longitude))
  clip: true

  onCenterKeyChanged: displayedIndex = -1
  Component.onCompleted: resetFrames()

  function resetFrames() {
    displayedIndex = -1
    inFlight = 0
    queueIndex = radar ? radar.frames.length - 1 : -1
    queueTimer.restart()
  }

  function showSelected() {
    if (radar && radar.selectedIndex >= 0 && radar.selectedReady)
      displayedIndex = radar.selectedIndex
  }

  function fillQueue() {
    if (!radar || !radar.active) return
    while (inFlight < 2 && queueIndex >= 0) {
      var index = queueIndex--
      var image = radarImages.itemAt(index)
      if (!image) continue
      // Repeater.itemAt exposes QQuickItem; its delegate has these properties.
      // qmllint disable missing-property
      if (!radar.requestImage(image.frameUrl)) return
      inFlight++
      image.source = image.frameUrl
      // qmllint enable missing-property
    }
  }

  Connections {
    target: root.radar
    function onFramesChanged() { root.resetFrames() }
    function onSelectedFrameChanged() { root.showSelected() }
  }

  Timer {
    id: queueTimer
    interval: 0
    onTriggered: root.fillQueue()
  }

  Item {
    id: mapCanvas
    width: 512
    height: 512
    anchors.centerIn: parent
    scale: Math.max(1, root.width / 512, root.height / 512)

    Loader {
      anchors.fill: parent
      active: root.hasCoordinates
      sourceComponent: Component {
        Map {
          id: baseMap
          anchors.fill: parent
          plugin: Plugin {
            name: "maplibre"
            PluginParameter {
              name: "maplibre.map.styles"
              value: "https://tiles.openfreemap.org/styles/dark,https://tiles.openfreemap.org/styles/positron"
            }
          }
          center: QtPositioning.coordinate(root.coordinates.latitude, root.coordinates.longitude)
          zoomLevel: 8
          copyrightsVisible: false
          MapLibre.style: landBoundaries
          // Keep the native map and its style attachment alive across theme changes.
          function selectStyle() {
            if (supportedMapTypes.length < 2) return
            landBoundaries.clearParameters()
            if (root.styleName === "dark") {
              landBoundaries.addParameter(stateBoundary)
              landBoundaries.addParameter(countryBoundaryLow)
              landBoundaries.addParameter(countryBoundaryHigh)
            }
            activeMapType = supportedMapTypes[root.styleName === "dark" ? 0 : 1]
          }
          Component.onCompleted: selectStyle()
          onSupportedMapTypesChanged: selectStyle()
          Connections {
            target: root
            function onStyleNameChanged() { baseMap.selectStyle() }
          }

          Style { id: landBoundaries }
          FilterParameter {
            id: stateBoundary
            styleId: "boundary_state"
            expression: ["all", ["==", ["get", "admin_level"], 4], ["!=", ["get", "maritime"], 1]]
          }
          FilterParameter {
            id: countryBoundaryLow
            styleId: "boundary_country_z0-4"
            expression: ["all", ["==", ["get", "admin_level"], 2], ["!", ["has", "claimed_by"]], ["!=", ["get", "maritime"], 1]]
          }
          FilterParameter {
            id: countryBoundaryHigh
            styleId: "boundary_country_z5-"
            expression: ["all", ["==", ["get", "admin_level"], 2], ["!=", ["get", "maritime"], 1]]
          }
        }
      }
    }

    Repeater {
      id: radarImages
      model: root.radar ? root.radar.frames : []
      Image {
        id: radarImage
        required property var modelData
        required property int index
        readonly property string frameUrl: modelData.url
        property bool finished: false
        anchors.fill: parent
        sourceSize.width: 512
        sourceSize.height: 512
        cache: false
        asynchronous: true
        visible: root.displayedIndex === index && status === Image.Ready
        onStatusChanged: {
          if (finished || (status !== Image.Ready && status !== Image.Error)) return
          finished = true
          if (root.radar) {
            if (status === Image.Ready) {
              root.radar.markReady(frameUrl)
              if (root.radar.selectedIndex === index) root.displayedIndex = index
            } else root.radar.markFailed(frameUrl)
          }
          root.inFlight = Math.max(0, root.inFlight - 1)
          queueTimer.restart()
        }
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: 124
      height: width
      radius: width / 2
      color: "transparent"
      border.color: root.foreground
      border.width: 1
      opacity: 0.16
    }

    Rectangle {
      anchors.centerIn: parent
      width: 228
      height: width
      radius: width / 2
      color: "transparent"
      border.color: root.foreground
      border.width: 1
      opacity: 0.12
    }

    Rectangle {
      id: marker
      anchors.centerIn: parent
      width: 8
      height: 8
      radius: 4
      color: root.foreground
    }
    Text {
      anchors.left: marker.right
      anchors.leftMargin: 6
      anchors.verticalCenter: marker.verticalCenter
      text: root.locationName
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.labelSize
    }
  }
}
