'use strict'

{flatten, reject, filter} = require 'prelude-ls'

angular.module 'dottyGrid' []

  # define the toolset
  .factory 'toolset', -> [
    * id: 'line'
      icon: 'pencil'
      label: 'Draw line'
      type: 'primary'
      enabled: true
      active: ""
    * id: 'poly'
      icon: 'pencil-square-o'
      label: 'Draw shape'
      type: 'success'
      enabled: true
      active: "btn-lg"
    * id: 'camera'
      icon: 'sun-o'
      label: 'Add camera'
      type: 'info'
      enabled: true
      active: ""
    * id: 'visible'
      icon: 'eye'
      label: 'Show visible'
      type: 'warning'
      enabled: true
      active: ""
    * id:'trash'
      icon: 'trash-o'
      label: 'Delete selected'
      type: 'danger'
      enabled: true
      active: ""
  ]

  .controller 'dottyGridController', <[$scope toolset]> ++ ($scope, toolset) ->

    console.log "dottyGridController"
    $scope.toolset = toolset

    $scope.deleteSelection = ->
      remove = reject (.selected)
      $scope.polygons = remove $scope.polygons
      $scope.lines = remove $scope.lines
      $scope.cameras = remove $scope.cameras
      $scope.visihash = {}
      $scope.visipolys!

    $scope.currentTool = 'poly'

    $scope.toolCheck = (tool) ->
      if tool.id == 'trash'
        $scope.deleteSelection!
      else
        if tool.id == 'visual'
          $scope.toggleVisible!
        else
          for t in $scope.toolset
            t.active = ""
            tool.active = "btn-lg"
            $scope.currentTool = tool.id

    $scope.trace = (col, row) ->
      console.log "(#{col}, #{row})"

    colCount = 30
    rowCount = 30

    # Pixels from centre of an edge dot to the svg container boundary
    inset = 20

    # Dot separation in pixels
    sep = 30
    scale = 1

    $scope.transform = ->
      return "scale(#{scale})"

    #
    # The scope model uses column, row coordinates, but the svg element
    # uses x,y pixel coordinates.
    #
    # Integer r,c values identify a grid dot
    # Non-integers may be allowed e.g. while tracking a mouse point with a
    # part-formed line.
    #

    #
    # Coordinate transform functions.
    # Lowercase c,r coords may be non-integer
    # Uppercase C,R coords are integers and can index a dot
    #
    # Note that columns and rows are numbered from bottom left!
    #
    $scope.c2x = d3.scale.linear!
    .domain [0,colCount-1]
    .range [inset, colCount*sep]

    $scope.x2c = $scope.c2x.invert
    $scope.x2C = (x) -> Math.round $scope.x2c x

    $scope.r2y = d3.scale.linear!
    .domain [0,rowCount-1]
    .range [rowCount*sep, inset]

    $scope.y2r = $scope.r2y.invert
    $scope.y2R = (y) -> Math.round $scope.y2r y

    $scope.cr2xy = (p) ->
      * $scope.c2x p.0
        $scope.r2y p.1

    $scope.xy2cr = (p) ->
      * $scope.x2c p.0
        $scope.y2r p.1

    $scope.xy2dot = (p) ->
      col = $scope.x2C p.0
      row = $scope.y2R p.1
      $scope.grid.rows[row][col]

    $scope.svgWidth = -> scale * (inset + $scope.c2x colCount-1)
    $scope.svgHeight = -> scale * (inset + $scope.r2y 0)

    #
    # dots in the dotty grid
    #

    rows = for rowIndex from 0 til rowCount
      for colIndex from 0 til colCount
        p: [colIndex, rowIndex]
        x: $scope.c2x colIndex
        y: $scope.r2y rowIndex
        first: false
        active: false

    $scope.grid = {rows: rows}

    $scope.classHash = (dot) -> do
      circle: true
      lit: dot.first

    $scope.closeAllDots = ->
      for rowIndex from 0 til rowCount
        row = $scope.grid.rows[rowIndex]
        for colIndex from 0 til colCount
          dot = row[colIndex]
          dot.active = false
          dot.first = false

    # previously constructed polygons
    $scope.polygons = [{data: []}]

    tracePolygons = ->
      console.log ($scope.polygons.map (polygon)->polygon.data.length).join " "

    $scope.polyDraw = (dot) ~>
      polygon = $scope.polygons[*-1]
      if dot.active
        if !dot.first
          return

        # close polygon and save in polygons array
        if polygon.data.length > 2
          $scope.polygons.push({data: []})
        else
          polygon.data = []
        $scope.closeAllDots!
        console.log "close"
      else
        # append dot to current polygon
        if dot.active
          return
        polygon.data.push(dot.p)
        dot.active = $scope.polygons.length
        dot.first = polygon.data.length == 1
        console.log "active"
      tracePolygons!

    $scope.lines = []

    $scope.lineDraw = (dot) ->
      if $scope.lines.length > 0 && !$scope.lines[*-1].data.p2?
        line = $scope.lines[*-1]
      else
        line = data:{}
        $scope.lines[*] = line

      if !line.data.p1?
        line.data.p1 = dot.p
        dot.first = true
      else
        line.data.p2 = dot.p
        #$scope.lines.push [{}]
        $scope.closeAllDots!
      $scope.lines[*-1] = line

    $scope.cameras = []

    $scope.cameraDraw = (dot) ->

      $scope.cameras[*] = 
        data: dot.p

      #console.debug $scope.cameras


    $scope.cameraPoints = (c, component) ->
      p = c.data
      switch component
      | 'x1' => $scope.c2x p.0
      | 'y1' => $scope.r2y p.1
      | 'x2' => $scope.c2x p.0
      | 'y2' => $scope.r2y p.1

    $scope.dotClick = (dot) ->
      switch $scope.currentTool
      | 'line' => $scope.lineDraw dot
      | 'poly' => $scope.polyDraw dot
      | 'camera' => $scope.cameraDraw dot


    $scope.polyPoints = (p) ->
      screenPoints = p.data.map $scope.cr2xy
      (flatten screenPoints).join " "

    $scope.polyClass = (p) ->
      "polygon " + if p.selected then "opaque" else ""

    $scope.lineClass = (line) ->
      "line " + if line.selected then "opaque" else ""

    pointHash = (p) -> "#{p.0.toString 16}#{p.1.toString 16}"

    $scope.cameraClass = (c) ->
      containing = filter ((p)->VisibilityPolygon.inPolygon c.data, p.data), $scope.polygons
      inside = containing and containing.length > 0

      if inside and !c.selected
        # pick the first container
        poly = containing.0
        # console.debug poly.data
        segments = VisibilityPolygon.convertToSegments([poly.data])
        # segments = for s, i in segments by 2
        #   s
        # console.debug segments

        $scope.visihash[pointHash c.data] = VisibilityPolygon.compute c.data, segments

      "camera " + if c.selected then "opaque " else "" + if inside then "inside" else ""

    $scope.polyToggle = (p) -> p.selected = !p.selected

    $scope.linePoints = (line, component) ->
      p1 = line.data.p1
      p2 = line.data.p2 or p1
      switch component
      | 'x1' => $scope.c2x p1.0
      | 'y1' => $scope.r2y p1.1
      | 'x2' => $scope.c2x p2.0
      | 'y2' => $scope.r2y p2.1

    $scope.lineToggle = (line) -> line.selected = !line.selected

    $scope.cameraToggle = (c) -> c.selected = !c.selected

    $scope.visihash = {}
    $scope.visipolys = ->
      polys = for k, v of $scope.visihash
        {data: v}

    $scope.toggleVisible = ->
      if $scope.visihas == {}
        for c in $scope.cameras
          containing = filter ((p)->VisibilityPolygon.inPolygon c.data, p.data), $scope.polygons
          inside = containing and containing.length > 0

          if inside
            # pick the first container
            poly = containing.0
            # console.debug poly.data
            segments = VisibilityPolygon.convertToSegments([poly.data])
            $scope.visihash[pointHash c.data] = VisibilityPolygon.compute c.data, segments
            $scope.visipolys()
      else
        $scope.visihash = {}

  # .directive 'd3', <[]> ++ ->
  #   restrict: 'A'
  #   link: (scope, element, attrs) !->
  #     console.log "d3 directive"

  #     svg = d3.select element.0

  #     trace = ->
  #       p = [x,y] = d3.mouse element.0
  #       [c,r] = scope.xy2cr p
  #       dot = scope.xy2dot p
  #       console.log "#{d3.event.type} xy=(#{x},#{y}), cr=(#{c},#{r}), dot=(#{dot.p.0},#{dot.p.1})"

  #     selecter = ->
  #       p = d3.mouse element.0
  #       console.log "polyScope=#{element.scope!$index}"
  #       pos = scope.xy2cr p
  #       insideList = scope.polygons.filter (poly) ->
  #         poly.data.length > 2
  #         and VisibilityPolygon.inPolygon pos, poly.data.concat!
  #       for poly in insideList
  #         poly.selected = !poly.selected
  #       console.log insideList.length



      # svg.on "mouseover", trace
      # svg.on "mousedown", selecter
      # svg.on "mousemove", trace
      # svg.on "mouseup", trace
