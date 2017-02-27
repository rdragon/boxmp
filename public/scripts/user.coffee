define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Score
    constructor: ->
      @round =
        kills: 0
        deaths: 0
        points: 0
      @total =
        kills: 0
        deaths: 0
      @rounds =
        won: 0
        played: 0

    onJoinGame: ->
      @total.kills = 0
      @total.deaths = 0
      @rounds.won = 0
      @rounds.played = 0

    onStartRound: ->
      @round.kills = 0
      @round.deaths = 0
      @round.points = 0

    addDeath: ->
      @round.deaths++
      @addPoints map.points.die

    addKill: ->
      @round.kills++
      @addPoints map.points.kill

    addPoints: (points) ->
      @round.points += points
      if @round.points >= map.points.max
        io.emit 'end of round', gm.round

  class UserPos
    constructor: (@pos, @diff, @velY, @walkDir) ->

  class User
    @shape: null
    @feetShape: null
    @init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar
      @shape = map.getRect conf.user.w, conf.user.h
      @feetShape = map.getRect conf.user.w, conf.contactEpsilon * 2, 0, conf.user.h / 2

    constructor: ->
      @id = 0
      @name = null
      @ping = 0
      @walkDir = 0
      @faceDir = 0
      @alive = false
      @tracks = []
      @tracksFirstTick = 0
      @history = []
      @historyFirstTick = 0
      @ghostDelayTicks = 0
      @doubleJumpAvailable = false
      @style = null
      @guns = []
      @gun = null
      @objs = []
      @spaceLeft = 0
      @pos = null
      @velocity = null
      @fanciesJump = false
      @fanciesFloor = false
      @extrapolating = false
      @ghostPos = null
      @score = new Score

    onStartRound: ->
      @alive = false
      @tracks = []
      @tracksFirstTick = 0
      @history = []
      @historyFirstTick = 0
      @objs = []
      @pos = new b2.vec
      @vel = new b2.vec
      @score.onStartRound()
      @updateGhostDelay()

    addTrack: (pos, velY, walkDir) ->
      if @tracks.length isnt 0
        _.last(@tracks).diff.add(pos)
      @tracks.push new UserPos pos, pos.copy().negate(), velY, walkDir

    updateGhostDelay: ->
      if conf.diffGhostDelay
        delay = @ping / 2 + conf.extraGhostDelay
        delay += _.max(u.ping / 2 for u in gm.users when u isnt @) if gm.users.length > 1
        @ghostDelayTicks = Math.round delay / conf.tickLength
      else
        if @ is sam
          @ghostDelayTicks = Math.round (@ping / 2 + conf.extraGhostDelay) / conf.tickLength
        else
          @ghostDelayTicks = Math.round (sam.ping / 2 + @ping / 2 + conf.extraGhostDelay) / conf.tickLength

    simulate: ->
      if @ is sam
        @updatePos()
      else
        @updatePosFromTracks()

    tryWalk: (vel, cutYVel = false) ->
      e = conf.contactEpsilon
      steps = Math.ceil Math.abs vel.length() / e
      pos = @pos.copy()
      pos.add vel
      step = vel.copy().negate().setLength e
      for n in [1..steps]
        obj = @getCollidingObj pos, false
        if obj is null
          @pos.setV pos
          return true
        else if cutYVel
          @vel.y = 0
        pos.add step
      false

    trySlopeWalk: (dx) ->
      e = conf.contactEpsilon
      moved = false
      a = 1.5
      b = 2.5
      v = new b2.vec dx, -Math.abs dx * b
      if @getCollidingObj(@pos.copy().add(dx, Math.abs(dx * a) + e), false) isnt null
        @pos.add v
        moved = @tryWalk new b2.vec(0, Math.abs dx * (a + b))
        @pos.subtract v unless moved
      moved

    tryDodgeWalk: ->
      rounds = 2
      s = 8
      maxVel = conf.walk.speed * conf.timeStep
      steps = s * rounds
      a = 0
      pos = new b2.vec
      for n in [1..steps]
        b = maxVel / rounds * Math.ceil n / s
        pos.setV(@pos).add b2.safeMath.cos(a) * b, b2.safeMath.sin(a) * b
        if @getCollidingObj(pos, false) is null
          @pos.setV pos
          return true
        a += Math.PI * 2 / s
      false

    tryJumpWalk: (dy) ->
      e = conf.contactEpsilon
      steps = 8
      da = Math.PI / (steps + 2)
      pos = new b2.vec
      v = new b2.vec
      a = da
      for n in [1..steps]
        a *= -1
        v.x = b2.safeMath.sin a
        v.y = -b2.safeMath.cos a
        v.setLength -dy * (1 - Math.abs a / Math.PI / 2)
        if @getCollidingObj(pos.setV(@pos).add(v), false) is null
          @pos.setV pos
          return true
        a += da * helper.sign(a) if n % 2 is 0
      false

    updatePos: ->
      return unless @alive
      floor = if @vel.y is 0 then @getFloorObj() else null
      if @walkDir isnt 0
        @vel.x += @walkDir * conf.walk.accel * conf.timeStep
        @vel.x = helper.confine @vel.x, conf.walk.speed
      else if @vel.x isnt 0
        x = Math.abs(@vel.x) - conf.walk.decel * conf.timeStep
        @vel.x = helper.sign(@vel.x) * Math.max 0, x
      if @fanciesJump and (floor isnt null or @doubleJumpAvailable)
        @vel.y = -conf.jumpVelocity
        @doubleJumpAvailable = floor isnt null
      @fanciesJump = false
      if floor is null and @vel.y < conf.userTerminalVelocity
        @vel.y = Math.min conf.userTerminalVelocity, @vel.y + conf.userGravity * conf.timeStep
      vel = @vel.copy().multiply conf.timeStep
      e = conf.contactEpsilon
      moved = false
      if vel.x isnt 0 and vel.y is 0
        moved = @trySlopeWalk vel.x
      unless moved
        moved = @tryWalk vel.copy().setY(0) if vel.x isnt 0
        if vel.y > 0
          if @tryWalk vel.copy().setX(0), true
            moved = true
        else if vel.y < 0
          if @getCollidingObj(@pos.copy().add(0, vel.y)) is null
            @pos.add(0, vel.y)
            moved = true
          else
            if vel.x is 0 and @tryJumpWalk vel.y
              moved = true
            else if @tryWalk vel.copy().setX(0)
              moved = true
            else
              @vel.y = 0
      if not moved
        obj = @getCollidingObj @pos, false
        if obj isnt null
          moved = @tryDodgeWalk()
          unless moved
            @die null, @pos if @ is sam
      if @ is sam
        if @pos.y > map.h + 5
          @die()
        if @alive
          if @ghostDelayTicks is 0
            @ghostPos = @pos
          else
            i = gm.tick - @historyFirstTick - @ghostDelayTicks
            @ghostPos = @history[Math.max i, 0]
          obj = @getCollidingObj @ghostPos, true, false
          if obj isnt null
            @resolveDeadlyCollision @ghostPos, obj

    resolveDeadlyCollision: (pos, obj) ->
      body = obj.body
      # dit is een hack, we willen eig het contactpunt
      psuedoImpactPos = body.GetPosition().copy().subtract(pos).setLength(conf.user.w / 2).add(pos)
      # dit ook. de angular velocity wordt niet meegerekend
      impulse = body.GetLinearVelocity().copy().multiply(conf.dieImpulse.factor).setMinLength(conf.dieImpulse.min)
      killer = obj.lastUser
      @die killer, pos, impulse, psuedoImpactPos

    updatePosFromTracks: ->
      tick = gm.tick - @ghostDelayTicks
      a = (tick - @tracksFirstTick) / conf.sendPosInterval
      i = Math.floor a
      return if i < 0 or @tracks.length is 0
      if i + 1 < @tracks.length
        track = @tracks[i]
        t = a - i
        @pos.setV(track.pos).addMultiple(track.diff, t)
        @extrapolating = false
      else if @extrapolating
        @updatePos()
      else
        @extrapolating = true
        t = (@tracks.length - 1) * conf.sendPosInterval + @tracksFirstTick
        track = _.last @tracks
        @pos.setV track.pos
        @vel.set 0, track.velY
        @walkDir = track.walkDir
        ticks = Math.min tick - t, 60
        if ticks > 0
          for n in [1..ticks]
            @updatePos()

    setStyle: ->
      color = conf.color.users[@id % conf.color.users.length]
      convert = helper.getCssColor
      @style =
        fill: convert color
        stroke: convert color, 1, conf.strokeBrightness
        obj:
          fill: convert color
          stroke: 'black'
        claimedObj:
          fill: convert color, .75
          stroke: convert conf.color.obj.stroke
        claimedDeadlyObj:
          fill: convert color, .75
          stroke: 'black'
        laser: convert color, conf.alpha.laser
        faintLaser: convert color, conf.alpha.faintLaser
        ghost:
          fill: convert color, conf.alpha.ghost
          stroke: convert color, conf.alpha.ghost, conf.strokeBrightness
        ragdoll:
          fill: convert color, conf.alpha.deadUser
          stroke: convert color, conf.alpha.deadUser, conf.strokeBrightness

    changeName: (name) ->
      x = @toHtml()
      @name = name
      dom.print "#{x} changed name to #{@toHtml()}"

    spawnSam: (seed) ->
      helper.seedPrivate seed
      for pos in helper.shufflePrivate map.spawnPositions
        if @getCollidingObj(pos) is null
          @spawn pos
          @history = []
          @historyFirstTick = gm.tick
          @ghostPos = pos
          gun.onSpawnSam() for gun in @guns when gun isnt null
          @swappingGuns = 0
          @fanciesJump = false
          @vel.setZero()
          @gun = map.defaultGun
          @gun.onPossibleReady()
          cam.setTarget @
          io.emit 'spawn', gm.tick, pos
          return
      tick = gm.tick + conf.sendPosInterval * Math.ceil(conf.spawnRetryInterval / conf.sendPosInterval)
      gm.addAction tick, => @spawnSam seed

    spawn: (pos) ->
      @alive = true
      @pos.setV pos
      @fanciesJump = false
      @fanciesFloor = false

    die: (killer = null, pos = null, impulse = null, impactPos = null) ->
      return if conf.godMode
      @alive = false
      if pos isnt null
        body = map.getRagdollBody @
        body.SetPosition pos
        body.ApplyImpulse impulse, impactPos if impulse isnt null
        body.SetActive true
        snapshot = new map.Snapshot body
      else
        snapshot = null
      killerId = if killer isnt null then killer.id else null
      if @ is sam
        io.emit 'die', gm.tick, killerId, snapshot, =>
          @handleDeath killer
      else
        @handleDeath killer

    handleDeath: (killer) ->
      dom.printKill @, killer
      @score.addDeath()
      if killer isnt null and killer isnt @
        killer.score.addKill()

    tryGrab: ->
      return if @spaceLeft is 0 or not @alive
      pos = @pos.copy()
      ar = [pos.copy(), pos.copy(), pos]
      ar[0].x += @faceDir * conf.grabRange
      ar[0].y -= .1
      ar[1].x -= @faceDir * conf.grabRange
      ar[1].y -= .1
      ar[2].y += conf.grabRange
      if dom.isKeyDown conf.keys.down
        ar.unshift ar.pop()
      obj = null
      fn = (f) ->
        body = f.GetBody()
        return true if not body.obj.dynamic or body.obj.isDeadly() or body.obj.claim.user isnt null
        obj = body.obj
        false
      for pos in ar
        map.world.QueryShape fn, User.shape, new b2.transform pos, b2.mat.FromAngle 0
        if obj isnt null
          obj.doClaim @, gm.tick
          break

    addObj: (obj) ->
      return if @ isnt sam
      @objs.push obj
      launcher = @guns[conf.launcher.slot]
      if launcher isnt null
        launcher.ammo++
        launcher.onPossibleReady()

    getFloorObj: (deadlyAllowed = false) ->
      obj = null
      map.queryShape User.feetShape, @pos, 0, (f) ->
        o = f.GetBody().obj
        if deadlyAllowed or not o.isDeadly()
          obj = o
          return true
        false
      obj

    getCollidingObj: (pos, deadlyAllowed = false, nonDeadlyAllowed = true) ->
      obj = null
      map.queryShape User.shape, pos, 0, (f) ->
        o = f.GetBody().obj
        deadly = o.isDeadly()
        if (deadly and deadlyAllowed) or (not deadly and nonDeadlyAllowed)
          obj = o
          return true
        false
      obj

    fire: (targetPos, isAltFire) ->
      return unless @alive and @swappingGuns is 0
      @gun.fire targetPos, isAltFire

    switchGun: (slot) ->
      return unless @alive
      gun = @guns[slot]
      return if gun is null or gun is @gun
      @gun = gun
      @swappingGuns++
      @gun.showNotReady()
      gm.addAction gm.tick + conf.swappingGunTicks, @gunSwapped

    gunSwapped: =>
      @swappingGuns--
      if @swappingGuns is 0
        @gun.onPossibleReady()

    toString: ->
      @name || "Player #{@id}"

    toHtml: ->
      htmlName = $('<span></span>').text(@toString()).html()
      "<span style=\"color: #{@style.fill}\">#{htmlName}</span>"
