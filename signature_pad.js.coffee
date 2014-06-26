###
  Signature Pad v1.3.2
  https://github.com/szimek/signature_pad

  Copyright 2013 Szymon Nowak
  Released under the MIT license

  The main idea and some parts of the code (e.g. drawing variable width Bézier curve) are taken from:
  http://corner.squareup.com/2012/07/smoother-signatures.html

  Implementation of interpolation using cubic Bézier curves is taken from:
  http://benknowscode.wordpress.com/2012/09/14/path-interpolation-using-cubic-bezier-and-control-point-estimation-in-javascript

  Algorithm for approximated length of a Bézier curve is taken from:
  http://www.lemoda.net/maths/bezier-length/index.html

###


exports = this
exports.SignaturePad = ((document) ->
  "use strict"
  SignaturePad = (canvas, options) ->
    self = this
    opts = options or {}
    @velocityFilterWeight = opts.velocityFilterWeight or 0.7
    @minWidth = opts.minWidth or 0.5
    @maxWidth = opts.maxWidth or 2.5
    @dotSize = opts.dotSize or ->
      (@minWidth + @maxWidth) / 2

    @penColor = opts.penColor or "black"
    @backgroundColor = opts.backgroundColor or "rgba(0,0,0,0)"
    @onEnd = opts.onEnd
    @onBegin = opts.onBegin
    @_canvas = canvas
    @_ctx = canvas.getContext("2d")
    @clear()
    @_handleMouseEvents()
    @_handleTouchEvents()
    return

  SignaturePad::clear = ->
    ctx = @_ctx
    canvas = @_canvas
    ctx.fillStyle = @backgroundColor
    ctx.clearRect 0, 0, canvas.width, canvas.height
    ctx.fillRect 0, 0, canvas.width, canvas.height
    @_reset()
    return

  SignaturePad::toDataURLfrom = (canvas) ->
    canvas.toDataURL("image/png");

  SignaturePad::toDataURL = (imageType, quality) ->
    canvas = @_canvas
    canvas.toDataURL.apply canvas, arguments_

  SignaturePad::fromDataURL = (dataUrl) ->
    self = this
    image = new Image()
    @_reset()
    image.src = dataUrl
    image.onload = ->
      self._ctx.drawImage image, 0, 0, self._canvas.width, self._canvas.height
      return

    @_isEmpty = false
    return

  SignaturePad::_strokeUpdate = (event) ->
    point = @_createPoint(event)
    @_addPoint point
    return

  SignaturePad::_strokeBegin = (event) ->
    @_reset()
    @_strokeUpdate event
    @onBegin event  if typeof @onBegin is "function"
    return

  SignaturePad::_strokeDraw = (point) ->
    ctx = @_ctx
    dotSize = (if typeof (@dotSize) is "function" then @dotSize() else @dotSize)
    ctx.beginPath()
    @_drawPoint point.x, point.y, dotSize
    ctx.closePath()
    ctx.fill()
    return

  SignaturePad::_strokeEnd = (event) ->
    canDrawCurve = @points.length > 2
    point = @points[0]
    @_strokeDraw point  if not canDrawCurve and point
    @onEnd event  if typeof @onEnd is "function"
    return

  SignaturePad::_handleMouseEvents = ->
    self = this
    @_mouseButtonDown = false
    @_canvas.addEventListener "mousedown", (event) ->
      if event.which is 1
        self._mouseButtonDown = true
        self._strokeBegin event
      return

    @_canvas.addEventListener "mousemove", (event) ->
      self._strokeUpdate event  if self._mouseButtonDown
      return

    document.addEventListener "mouseup", (event) ->
      if event.which is 1 and self._mouseButtonDown
        self._mouseButtonDown = false
        self._strokeEnd event
      return

    return

  SignaturePad::_handleTouchEvents = ->
    self = this

    # Pass touch events to canvas element on mobile IE.
    @_canvas.style.msTouchAction = "none"
    @_canvas.addEventListener "touchstart", (event) ->
      touch = event.changedTouches[0]
      self._strokeBegin touch
      return

    @_canvas.addEventListener "touchmove", (event) ->

      # Prevent scrolling.
      event.preventDefault()
      touch = event.changedTouches[0]
      self._strokeUpdate touch
      return

    document.addEventListener "touchend", (event) ->
      wasCanvasTouched = event.target is self._canvas
      self._strokeEnd event  if wasCanvasTouched
      return

    return

  SignaturePad::isEmpty = ->
    @_isEmpty

  SignaturePad::_reset = ->
    @points = []
    @_lastVelocity = 0
    @_lastWidth = (@minWidth + @maxWidth) / 2
    @_isEmpty = true
    @_ctx.fillStyle = @penColor
    return

  SignaturePad::_createPoint = (event) ->
    rect = @_canvas.getBoundingClientRect()
    new Point(event.clientX - rect.left, event.clientY - rect.top)

  SignaturePad::_addPoint = (point) ->
    points = @points
    c2 = undefined
    c3 = undefined
    curve = undefined
    tmp = undefined
    points.push point
    if points.length > 2

      # To reduce the initial lag make it work with 3 points
      # by copying the first point to the beginning.
      points.unshift points[0]  if points.length is 3
      tmp = @_calculateCurveControlPoints(points[0], points[1], points[2])
      c2 = tmp.c2
      tmp = @_calculateCurveControlPoints(points[1], points[2], points[3])
      c3 = tmp.c1
      curve = new Bezier(points[1], c2, c3, points[2])
      @_addCurve curve

      # Remove the first element from the list,
      # so that we always have no more than 4 points in points array.
      points.shift()
    return

  SignaturePad::_calculateCurveControlPoints = (s1, s2, s3) ->
    dx1 = s1.x - s2.x
    dy1 = s1.y - s2.y
    dx2 = s2.x - s3.x
    dy2 = s2.y - s3.y
    m1 =
      x: (s1.x + s2.x) / 2.0
      y: (s1.y + s2.y) / 2.0

    m2 =
      x: (s2.x + s3.x) / 2.0
      y: (s2.y + s3.y) / 2.0

    l1 = Math.sqrt(dx1 * dx1 + dy1 * dy1)
    l2 = Math.sqrt(dx2 * dx2 + dy2 * dy2)
    dxm = (m1.x - m2.x)
    dym = (m1.y - m2.y)
    k = l2 / (l1 + l2)
    cm =
      x: m2.x + dxm * k
      y: m2.y + dym * k

    tx = s2.x - cm.x
    ty = s2.y - cm.y
    c1: new Point(m1.x + tx, m1.y + ty)
    c2: new Point(m2.x + tx, m2.y + ty)

  SignaturePad::_addCurve = (curve) ->
    startPoint = curve.startPoint
    endPoint = curve.endPoint
    velocity = undefined
    newWidth = undefined
    velocity = endPoint.velocityFrom(startPoint)
    velocity = @velocityFilterWeight * velocity + (1 - @velocityFilterWeight) * @_lastVelocity
    newWidth = @_strokeWidth(velocity)
    @_drawCurve curve, @_lastWidth, newWidth
    @_lastVelocity = velocity
    @_lastWidth = newWidth
    return

  SignaturePad::_drawPoint = (x, y, size) ->
    ctx = @_ctx
    ctx.moveTo x, y
    ctx.arc x, y, size, 0, 2 * Math.PI, false
    @_isEmpty = false
    return

  SignaturePad::_drawCurve = (curve, startWidth, endWidth) ->
    ctx = @_ctx
    widthDelta = endWidth - startWidth
    drawSteps = undefined
    width = undefined
    i = undefined
    t = undefined
    tt = undefined
    ttt = undefined
    u = undefined
    uu = undefined
    uuu = undefined
    x = undefined
    y = undefined
    drawSteps = Math.floor(curve.length())
    ctx.beginPath()
    i = 0
    while i < drawSteps

      # Calculate the Bezier (x, y) coordinate for this step.
      t = i / drawSteps
      tt = t * t
      ttt = tt * t
      u = 1 - t
      uu = u * u
      uuu = uu * u
      x = uuu * curve.startPoint.x
      x += 3 * uu * t * curve.control1.x
      x += 3 * u * tt * curve.control2.x
      x += ttt * curve.endPoint.x
      y = uuu * curve.startPoint.y
      y += 3 * uu * t * curve.control1.y
      y += 3 * u * tt * curve.control2.y
      y += ttt * curve.endPoint.y
      width = startWidth + ttt * widthDelta
      @_drawPoint x, y, width
      i++
    ctx.closePath()
    ctx.fill()
    return

  SignaturePad::_strokeWidth = (velocity) ->
    Math.max @maxWidth / (velocity + 1), @minWidth

  Point = (x, y, time) ->
    @x = x
    @y = y
    @time = time or new Date().getTime()
    return

  Point::velocityFrom = (start) ->
    (if (@time isnt start.time) then @distanceTo(start) / (@time - start.time) else 1)

  Point::distanceTo = (start) ->
    Math.sqrt Math.pow(@x - start.x, 2) + Math.pow(@y - start.y, 2)

  Bezier = (startPoint, control1, control2, endPoint) ->
    @startPoint = startPoint
    @control1 = control1
    @control2 = control2
    @endPoint = endPoint
    return


  # Returns approximated length.
  Bezier::length = ->
    steps = 10
    length = 0
    i = undefined
    t = undefined
    cx = undefined
    cy = undefined
    px = undefined
    py = undefined
    xdiff = undefined
    ydiff = undefined
    i = 0
    while i <= steps
      t = i / steps
      cx = @_point(t, @startPoint.x, @control1.x, @control2.x, @endPoint.x)
      cy = @_point(t, @startPoint.y, @control1.y, @control2.y, @endPoint.y)
      if i > 0
        xdiff = cx - px
        ydiff = cy - py
        length += Math.sqrt(xdiff * xdiff + ydiff * ydiff)
      px = cx
      py = cy
      i++
    length

  Bezier::_point = (t, start, c1, c2, end) ->
    start * (1.0 - t) * (1.0 - t) * (1.0 - t) + 3.0 * c1 * (1.0 - t) * (1.0 - t) * t + 3.0 * c2 * (1.0 - t) * t * t + end * t * t * t

  SignaturePad
)(document)
