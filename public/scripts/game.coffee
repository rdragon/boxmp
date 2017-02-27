define ['config', 'b2', 'helper', 'map', 'camera', 'io', 'dom', 'user', 'obj', 'gun'], (conf, b2, helper, map, cam, io, dom, User, Obj, Gun) ->
  class Laser
    constructor: (@startPos, @endPos, @isAltFire, @user) ->
      @isActive = false
      @fromSniper = false
      @impactPos = null

  class Launch
    constructor: (@pos, @angle, @fireAngle, @isAltFire, @user) ->
      @salvos = 1
      @obj = null

  class Game
    constructor: ->
      @Laser = Laser
      @Launch = Launch
      @User = User
      @Obj = Obj
      @Gun = Gun
      @users = []
      @running = false
      @serverStart = 0
      @tick = 0
      @actions = {}
      @serverTick = 0
      @awaitingHeartbeat = false
      @catchingUp = false
      @round = 0
      @startTime = Date.now()

    onStartRound: ->
      @tick = 0
      @actions = {}
      @serverTick = 0

    onEndRound: ->
      @running = false
      @awaitingHeartbeat = false
      $('#status').hide()
      document.title = 'boxmp'
      window.clearInterval dom.updateTimeInterval

    startRound: (serverStart) ->
      document.title = 'boxmp (running)'
      @onStartRound()
      @running = true
      @serverStart = serverStart
      io.onStartRound()
      map.onStartRound()
      map.createWorlds()
      map.getMap()
      u.onStartRound() for u in @users
      dom.hideScore()
      dom.onResize()
      dom.roundSeconds = Math.floor (Date.now() - @getStartTime()) / 1000
      dom.updateTimeInterval = window.setInterval dom.updateTime, 1000

    stop: ->
      if @running
        @onEndRound()

    endRound: ->
      @onEndRound()
      winner = _.max @users, (u) -> u.score.round.points
      if _.any(@users, (u) -> u.score.round.points is winner.score.round.points and u isnt winner)
        msg = "It's a draw!"
      else if @users.length > 1
        msg = winner.toHtml() + ' has won the game!'
        winner.score.rounds.won++
        if winner is sam
          io.emit 'won round'
      else
        msg = 'Round ended!'
      u.score.rounds.played++ for u in @users
      dom.showScore msg
      if io.startRoundMsgs.length > 0
        args = io.startRoundMsgs.pop()
        io.startRound args...

    addUser: (u, id) ->
      u.id = id
      u.setStyle()
      io.userDict[id] = u
      @users.push u

    removeUser: (u) ->
      @users.splice @users.indexOf(u), 1
      delete io.userDict[u.id]
      if @running
        for obj in map.objs
          obj.lastUser = null if obj.lastUser is u
          obj.destroy() if obj.owner is u
      dom.print "#{u.toHtml()} left the game"

    getStartTime: ->
      @serverStart - io.sync.serverTimeDiff

    gameLoop: (time) =>
      return unless @running
      time = Date.now() unless time?
      @simulate time
      cam.drawScene()
      reqFrame @gameLoop

    simulate: (endTime) ->
      endTime += @startTime if endTime < 1e12
      endTick = Math.floor (endTime - @getStartTime()) / conf.tickLength
      if endTick > @serverTick + conf.physicsDelayTicks
        endTick = @serverTick + conf.physicsDelayTicks
        dom.showStatus conf.msg.lag unless @catchingUp
        @awaitingHeartbeat = true
      else if @awaitingHeartbeat
        dom.hideStatus() unless @catchingUp
        @awaitingHeartbeat = false
      start = Date.now()
      while @tick < endTick and Date.now() - start < conf.maxSimulationTime
        map.simulate()
        if sam.alive
          sam.history.push sam.pos.copy()
          io.sendPos() if @tick % conf.sendPosInterval is 0
        io.sendWorldState() if @tick % conf.sendWorldStateInterval is 0
        @tick++
        if @tick is conf.roundTicks
          io.emit 'end of round', @round
      if @catchingUp and endTick is @tick
        @catchingUp = false
        io.emit 'done catching up'
        dom.hideStatus()
        @gameLoop()

    catchUp: =>
      return unless @running
      @simulate Date.now()
      if @catchingUp
        window.setTimeout @catchUp, 1

    addAction: (tick, fn) ->
      if tick < @tick
        fn()
      else
        @actions[tick] = [] unless tick of @actions
        @actions[tick].push fn

  reqFrame = do ->
    window.requestAnimationFrame ||
    window.webkitRequestAnimationFrame ||
    window.mozRequestAnimationFrame ||
    window.oRequestAnimationFrame ||
    window.msRequestAnimationFrame ||
    (fn) -> window.setTimeout fn, 1000 / 60

  window.console = log: ( -> ) unless window.console? # IE doesn't support console.log
  gm = new Game
  sam = new User
  if helper.hasLocalStorage() and localStorage.name? and localStorage.name isnt ''
    sam.name = localStorage.name
  ar = [gm, conf, b2, helper, map, cam, io, dom, sam]
  map.init ar; cam.init ar; io.init ar; dom.init ar; User.init ar; Obj.init ar; Gun.init ar
  $(document).ready dom.onReady
