import QtQuick

Canvas {
  id: root
  width: 38
  height: 38
  property string phase: ""
  property string illumination: ""
  property color foreground
  onPhaseChanged: requestPaint()
  onIlluminationChanged: requestPaint()
  onForegroundChanged: requestPaint()

  onPaint: {
    var context = getContext("2d")
    context.clearRect(0, 0, width, height)
    var lower = phase.toLowerCase()
    var waxing = lower.indexOf("waxing") >= 0 || lower.indexOf("first") >= 0
    var waning = lower.indexOf("waning") >= 0 || lower.indexOf("last") >= 0 || lower.indexOf("third") >= 0
    var fraction = parseFloat(illumination) / 100
    if (lower.indexOf("full") >= 0) fraction = 1
    if (lower.indexOf("new") >= 0) fraction = 0
    if (!isFinite(fraction)) fraction = lower.indexOf("gibbous") >= 0 ? 0.7 : lower.indexOf("quarter") >= 0 ? 0.5 : 0.2
    fraction = Math.max(0, Math.min(1, fraction))
    var cx = width / 2
    var cy = height / 2
    var radius = Math.min(width, height) / 2 - 3

    context.strokeStyle = foreground
    context.lineWidth = 1.5
    context.globalAlpha = 0.45
    context.beginPath()
    context.arc(cx, cy, radius, 0, Math.PI * 2)
    context.stroke()
    context.globalAlpha = 1
    if (fraction <= 0) return
    if (fraction >= 1 || (!waxing && !waning)) {
      context.beginPath()
      context.arc(cx, cy, radius - 1, 0, Math.PI * 2)
      context.fillStyle = foreground
      context.fill()
      return
    }

    var side = waxing ? 1 : -1
    context.beginPath()
    for (var step = 0; step <= 40; step++) {
      var y = -radius + 2 * radius * step / 40
      var edge = Math.sqrt(Math.max(0, radius * radius - y * y))
      var term = side * edge * (1 - 2 * fraction)
      if (step === 0) context.moveTo(cx + term, cy + y)
      else context.lineTo(cx + term, cy + y)
    }
    for (var reverse = 40; reverse >= 0; reverse--) {
      var outerY = -radius + 2 * radius * reverse / 40
      var outer = Math.sqrt(Math.max(0, radius * radius - outerY * outerY))
      context.lineTo(cx + side * outer, cy + outerY)
    }
    context.closePath()
    context.fillStyle = foreground
    context.fill()
  }
}
