pragma ComponentBehavior: Bound

import QtQuick
import QtLocation
import QtPositioning

Item {
  id: root
  property var radar: null
  property var coordinates: null
  property string styleName: "fiord"
  property string locationName: ""
  property color foreground
  property string fontFamily: ""
  property int labelSize
  property bool mapActive: true
  property int displayedIndex: -1
  property int queueIndex: -1
  property int inFlight: 0
  readonly property string centerKey: radar ? radar.locationKey : ""
  readonly property bool hasCoordinates: coordinates && isFinite(Number(coordinates.latitude)) &&
    isFinite(Number(coordinates.longitude))
  clip: true

  onStyleNameChanged: {
    mapActive = false
    mapReload.restart()
  }
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
    id: mapReload
    interval: 0
    onTriggered: root.mapActive = true
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
      active: root.mapActive && root.hasCoordinates
      sourceComponent: Component {
        Map {
          anchors.fill: parent
          plugin: Plugin {
            name: "maplibre"
            PluginParameter {
              name: "maplibre.map.styles"
              value: "https://tiles.openfreemap.org/styles/" + root.styleName
            }
          }
          center: QtPositioning.coordinate(root.coordinates.latitude, root.coordinates.longitude)
          zoomLevel: 8
          copyrightsVisible: false
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
