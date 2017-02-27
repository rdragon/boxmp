define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Dom
    constructor: ->
      @keysDown = {}
      @bindedKeys = []
      @mouse = null
      @updateTimeInterval = null
      @roundSeconds = 0

    init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar
      for x, keys of conf.keys
        @bindedKeys = @bindedKeys.concat keys
      @mouse = new b2.vec

    onReady: =>
      $(document).keydown @onKeyDown
      $(document).keyup @onKeyUp
      $(document).mousedown @onMouseDown
      $(document).mousemove (e) => @mouse.set e.pageX, e.pageY
      $(document).contextmenu -> false
      $(window).resize _.debounce(@onResize, 200)
      $('#name').show().focus() if sam.name is null
      fn = => @updateScoreTable() if $('#score').is(':visible')
      window.setInterval fn, conf.updateScoreTableInterval

    onMouseDown: (e) =>
      return if $('#name').is(':focus') or $('#chatbox').is(':focus') or not gm.running or cam.pos is null or e.which is 2
      endPos = @getWorldPos e.pageX, e.pageY
      isAltFire = e.which is 3
      sam.fire endPos, isAltFire

    getWorldPos: (x, y) ->
      canvasOffset = $('canvas').offset()
      pos = new b2.vec x - canvasOffset.left, y - canvasOffset.top
      pos.Multiply 1 / cam.scale
      pos.Add cam.pos
      pos

    onResize: =>
      cam.updateViewAndScale()
      @updateCanvasSize()
      @centerElement $('#name')

    onKeyDown: (e) =>
      return if e.ctrlKey or e.metaKey
      key = e.keyCode
      if $('#name').is(':focus')
        if key is 13
          @submitName()
          e.preventDefault()
        else if key is 27
          $('#name').hide()
          e.preventDefault()
      else if $('#chatbox').is(':focus')
        if key is 13
          @sendChat()
          e.preventDefault()
        else if key is 27
          $('#chatbox').hide()
          e.preventDefault()
      else if key in @bindedKeys
        e.preventDefault()

        if key in conf.keys.left
          sam.walkDir = sam.faceDir = -1

        else if key in conf.keys.right
          sam.walkDir = sam.faceDir = 1

        else if key in conf.keys.jump
          sam.fanciesJump = true unless @keysDown[key]

        else if key in conf.keys.switchGun
          sam.switchGun key - 48

        else if key in conf.keys.grab
          sam.tryGrab() unless @keysDown[key]

        else if key in conf.keys.chat
          $('#chatbox').show().focus()

        else if key in conf.keys.debugKey and conf.debugMode
          io.pauseOutput = true

        else if key in conf.keys.quit
          gm.stop()
          io.socket.disconnect()

        else if key in conf.keys.changeName
          $('#name').val(sam.name || '').show().focus()

        else if key in conf.keys.toggleScore
          @toggleScore() unless @keysDown[key]

      @keysDown[key] = true

    onKeyUp: (e) =>
      key = e.keyCode
      @keysDown[key] = false
      return if $('#name').is(':focus') or $('#chatbox').is(':focus')

      if key in conf.keys.left
        if @isKeyDown conf.keys.right
          sam.walkDir = sam.faceDir = 1
        else
          sam.walkDir = 0

      else if key in conf.keys.right
        if @isKeyDown conf.keys.left
          sam.walkDir = sam.faceDir = -1
        else
          sam.walkDir = 0

      else if key in conf.keys.jump
        sam.fanciesFloor = true

      else if key in conf.keys.debugKey and conf.debugMode
        io.pauseOutput = false

    isKeyDown: (keys) ->
      for key in keys
        return true if @keysDown[key]
      return false

    showScore: (msg = null) ->
      if msg isnt null
        $('#winmsg').html msg
        $('#score').addClass('round').removeClass('ingame')
      else
        $('#score').addClass('ingame').removeClass('round')
      dom.centerElement $('#score').show()
      @updateScoreTable()

    hideScore: ->
      $('#score').hide()

    toggleScore: ->
      if $('#score').is(':hidden')
        @showScore()
      else
        @hideScore()

    updateScoreTable: ->
      @showTime()
      tbody = $('<tbody></tbody>')
      i = 1
      for u in _.sortBy(gm.users, (u) -> -u.score.round.points)
        tr = $('<tr></tr>'); _td = $('<td></td>')
        td = _td.clone(); td.html i++; tr.append td
        td = _td.clone(); td.html u.toHtml(); td.css('text-align', 'left'); tr.append td
        td = _td.clone(); td.text u.score.round.kills; tr.append td
        td = _td.clone(); td.text u.score.round.deaths; tr.append td
        td = _td.clone(); td.text u.score.rounds.won; tr.append td
        td = _td.clone(); td.text u.score.rounds.played; tr.append td
        td = _td.clone(); td.text u.ping; tr.append td
        tbody.append tr
      $('tbody').replaceWith tbody

    updateTime: =>
      @roundSeconds++
      @showTime() if $('#score').is(':visible') and gm.running

    showTime: =>
      s = @roundSeconds
      m = Math.floor s / 60
      s -= m * 60
      if s < 10
        s = '0' + s
      $('#time').text m + ':' + s

    sendChat: ->
      $('#chatbox').blur().hide()
      msg = $('#chatbox').val() # we should make it nice first
      $('#chatbox').val('')

      if msg.length > 0
        @print msg, sam
        io.emit 'chat', msg

    submitName: ->
      $('#name').blur().hide()
      name = helper.getApprovedName $('#name').val()
      if name and name isnt sam.name
        if helper.hasLocalStorage()
          localStorage.name = name
        sam.changeName name
        io.emit 'name', name

    printKill: (user, killer) ->
      return if gm.catchingUp
      if killer and killer isnt user
        li = $("<li>#{user.toHtml()} is killed by #{killer.toHtml()}</li>")
      else
        li = $("<li>#{user.toHtml()} died</li>")
      $('#kills').show().append li
      fn = ->
        $('#kills li:first-child').remove()
        $('#kills:empty').hide()
      window.setTimeout fn, conf.killMsgTimeout

    print: (msg, u = null, force = false) ->
      return if gm.catchingUp and not force
      msg = "#{u.toHtml()}: #{msg}" unless u is null
      $('#log').show().append "<li>#{msg}</li>"
      fn = ->
        $('#log li:first-child').remove()
        $('#log:empty').hide()
      window.setTimeout fn, conf.logMsgTimeout

    showStatus: (status) ->
      $('#status').show().text status

    hideStatus: ->
      $('#status').hide()

    updateCanvasSize: ->
      canvas = $('canvas')
      canvas.attr 'width', cam.view.w * cam.scale
      canvas.attr 'height', cam.view.h * cam.scale
      canvas.css 'display', 'block'
      cam.reloadContext()
      @centerElement canvas

    centerElement: (element) ->
      element.css 'left', ($(window).width() - element.outerWidth()) / 2
      element.css 'top', ($(window).height() - element.outerHeight()) / 2

  new Dom
