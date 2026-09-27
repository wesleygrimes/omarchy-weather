import QtQuick

Canvas {
  id: root
  width: 38
  height: 38
  property bool rising: true
  property color foreground
  onRisingChanged: requestPaint()
  onForegroundChanged: requestPaint()

  onPaint: {
    var context = getContext("2d")
    context.clearRect(0, 0, width, height)
    context.strokeStyle = foreground
    context.lineWidth = 1.7
    context.lineCap = "round"
    context.lineJoin = "round"
    context.beginPath()
    context.moveTo(4, 30)
    context.lineTo(34, 30)
    context.moveTo(11, 27)
    context.arc(19, 27, 8, Math.PI, 0)
    context.moveTo(5, 24)
    context.lineTo(8, 25)
    context.moveTo(30, 25)
    context.lineTo(33, 24)
    context.moveTo(9, 16)
    context.lineTo(11, 18)
    context.moveTo(27, 18)
    context.lineTo(29, 16)
    if (rising) {
      context.moveTo(19, 16)
      context.lineTo(19, 3)
      context.moveTo(15, 7)
      context.lineTo(19, 3)
      context.lineTo(23, 7)
    } else {
      context.moveTo(19, 3)
      context.lineTo(19, 16)
      context.moveTo(15, 12)
      context.lineTo(19, 16)
      context.lineTo(23, 12)
    }
    context.stroke()
  }
}
