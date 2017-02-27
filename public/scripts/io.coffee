define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Io
    constructor: ->
      @userDict = {}
      @objDict = {}
      @sync = serverTimeDiff: 0, maxError: Infinity
      @pings = best: Infinity, left: 1
      @socket = null
      @inBuffer = []
      @outBuffer = []
      @pauseOutput = false
      @objCounter = 0
      @startRoundMsgs = []

    onStartRound: ->
      @objCounter = 0

    init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar

      @socket = window.io()

      @on 'connect', =>
        @pingServer()
        @emit 'name', sam.name if sam.name isnt null
        @emit 'calculated value', helper.getCalculatedValue()
        @emit 'join game'

      @on 'start round', =>
        if gm.running
          @startRoundMsgs.push arguments
        else
          @startRound arguments...

      @on 'id', (id) =>
        gm.addUser sam, id

      @on 'spawn', (seed) =>
        tick = conf.sendPosInterval * Math.ceil(gm.tick / conf.sendPosInterval)
        gm.addAction tick, -> sam.spawnSam seed

      @on 'users', (users) =>
        for data in users
          u = new gm.User
          u.name = data.name
          u.score.rounds.won = data.won
          u.score.rounds.played = data.played
          u.onStartRound()
          gm.addUser u, data.id

      @on 'track ticks', (users) =>
        for data in users
          u = @userDict[data.id]
          u.tracks = []
          u.tracksFirstTick = data.tick

      @on 'new user', (id, name) =>
        u = new gm.User
        u.name = name
        u.onStartRound()
        gm.addUser u, id
        dom.print "#{u.toHtml()} joined the game"

      @on 'user spawned', (id, tick, pos) =>
        u = @userDict[id]
        pos = new b2.vec pos.x, pos.y
        u.spawn pos
        u.tracksFirstTick = tick

      @on 'user died', (id, tick, killerId, snapshot) =>
        u = @userDict[id]
        killer = if killerId is null then null else @userDict[killerId]
        u.tracks = []
        u.die killer
        if snapshot isnt null and not gm.catchingUp
          body = map.getRagdollBody u
          map.Snapshot.apply snapshot, body
          body.SetActive true

      @on 'user left', (id, tick) =>
        u = @userDict[id]
        if tick is null
          gm.removeUser u
        else
          gm.addAction tick, -> gm.removeUser u

      @on 'new laser', (id, tick, x1, y1, x2, y2, isAltFire) =>
        u = @userDict[id]
        laser = new gm.Laser new b2.vec(x1, y1), new b2.vec(x2, y2), isAltFire, u
        map.lasers.push laser
        gm.addAction tick, -> map.activateLaser laser

      @on 'sniper fired', (id, tick, x1, y1, x2, y2, isAltFire) =>
        u = @userDict[id]
        laser = new gm.Laser new b2.vec(x1, y1), new b2.vec(x2, y2), isAltFire, u
        laser.impactPos = laser.endPos
        laser.isActive = true
        laser.fromSniper = true
        map.lasers.push laser
        map.startRemovingLaser laser
        tick -= sam.ghostDelayTicks
        gm.addAction tick, -> map.activateSniper laser, tick

      @on 'launcher fired', (id, tick, x1, y1, angle, fireAngle, isAltFire, objId) =>
        u = @userDict[id]
        # we make sure objId is in @objDict by executing this piece of code at most physicsDelayTicks before the fire tick, since it takes at least that long to grab an object
        gm.addAction tick - conf.physicsDelayTicks, =>
          launch = new gm.Launch new b2.vec(x1, y1), angle, fireAngle, isAltFire, u
          launch.obj = @objDict[objId]
          map.launches.push launch
          gm.addAction tick, -> map.activateLauncher launch

      @on 'autoLauncher fired', (id, tick, x1, y1, angle, fireAngle, isAltFire) =>
        u = @userDict[id]
        launch = new gm.Launch new b2.vec(x1, y1), angle, fireAngle, isAltFire, u
        launch.salvos = conf.autoLauncher.salvos
        map.launches.push launch
        gm.addAction tick, -> map.activateAutoLauncher launch

      @on 'new claim', (id, objId, claimTick, grabTick) =>
        u = @userDict[id]
        gm.addAction claimTick, =>
          return unless objId of @objDict
          obj = @objDict[objId]
          obj.doClaim u, claimTick
          gm.addAction grabTick, => obj.tryGrab u, claimTick

      @on 'name', (id, name) =>
        u = @userDict[id]
        u.changeName name

      @on 'pos', (id, x, y, velY, walkDir, serverTick) =>
        u = @userDict[id]
        gm.serverTick = serverTick
        u.addTrack new b2.vec(x, y), velY, walkDir
        u.extrapolating = false

      @on 'end of round', =>
        gm.endRound()

      @on 'tick', (tick) =>
        gm.serverTick = tick

      @on 'start catching up', =>
        gm.catchUp()

      @on 'chat', (id, msg) =>
        dom.print msg, @userDict[id], true

      @on 'print', (msg, force = false) =>
        dom.print msg, null, force

      @on 'user ping', (id, ping) =>
        u = @userDict[id]
        u.ping = ping
        user.updateGhostDelay() for user in gm.users

      @on 'disconnect', =>
        dom.print 'Disconnected from server.'
        gm.stop()

    pingServer: =>
      time = Date.now()
      @emit 'get time', (serverTime) =>
        ping = Date.now() - time
        if ping < @sync.maxError
          @sync.serverTimeDiff = serverTime + ping / 2 - Date.now()
          @sync.maxError = ping
        @pings.best = Math.min ping, @pings.best
        if --@pings.left is 0
          sam.ping = @pings.best
          @pings.best = Infinity
          @pings.left = conf.ping.tries
          u.updateGhostDelay() for u in gm.users
          @emit 'user ping', sam.ping
          window.setTimeout @pingServer, conf.ping.interval
        else
          window.setTimeout @pingServer, conf.ping.delay

    sendWorldState: ->
      s = ''
      for obj in map.objs
        s += Math.round obj.body.GetPosition().x * 1000
      @emit 'state', gm.tick, helper.md5 s

    startRound: (round, serverStart, shouldCatchUp, fn) =>
      fn() unless fn is null
      gm.round = round
      gm.catchingUp = shouldCatchUp
      helper.seed serverStart
      gm.startRound serverStart
      if gm.catchingUp
        dom.showStatus conf.msg.joining
      else
        gm.gameLoop()

    sendPos: ->
      pos = sam.pos
      @emit 'pos', pos.x, pos.y, sam.vel.y, sam.walkDir

    on: (msg, fn) ->
      @socket.on msg, if conf.extraPing is 0 and not conf.debugMode then fn else @wrapInDelay fn

    emit: ->
      if conf.extraPing is 0 and not conf.debugMode
        @socket.emit.apply @socket, arguments
        return
      args = arguments
      if args.length > 0 and _.isFunction _.last args
        args[args.length - 1] = @wrapInDelay _.last args
      @outBuffer.push =>
        dom.print args[0] if conf.debugEmits
        @socket.emit.apply @socket, args
      window.setTimeout @sendOne, conf.extraPing / 2

    wrapInDelay: (fn) ->
      =>
        args = arguments
        @inBuffer.push -> fn.apply @, args
        window.setTimeout @readOne, conf.extraPing / 2

    readOne: =>
      @inBuffer.shift()()

    sendOne: =>
      if @pauseOutput
        window.setTimeout @sendOne, 100
      else
        @outBuffer.shift()()

  new Io
