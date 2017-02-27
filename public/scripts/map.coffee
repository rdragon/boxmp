define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Snapshot
    constructor: (body) ->
      @pos = body.GetPosition().Copy()
      @vel = body.GetLinearVelocity().Copy()
      @angularVel = body.GetAngularVelocity()

    @apply: (snapshot, body) ->
      body.SetPosition snapshot.pos
      body.SetLinearVelocity snapshot.vel
      body.SetAngularVelocity snapshot.angularVel

  class Map
    constructor: ->
      @Snapshot = Snapshot
      @w = 0
      @h = 0
      @world = null
      @altWorld = null
      @wall = null
      @objs = []
      @destroyedObjs = []
      @lasers = []
      @launches = []
      @spawnPositions = []
      @style = null
      @kinematics = []
      @ragdolls = []
      @inactiveRagdolls = []
      @defaultGun = null
      @zeroGravity = null
      @destroyOutOfBounds = true
      @points =
        kill: 1
        die: 0
        max: 9999

    onStartRound: ->
      @objs = []
      @destroyedObjs = []
      @lasers = []
      @launches = []
      @spawnPositions = []
      @boxSpawnTick = 0
      @kinematics = []
      @ragdolls = []

    init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar

    simulate: ->
      @world.Step conf.tickLength / 1000, 8, 3
      @world.ClearForces()
      obj.doStuff() for obj in @objs
      @limitVelocity body for body in @ragdolls
      @removeObjs()
      u.simulate() for u in gm.users
      if @ragdolls.length > 0
        @altWorld.Step conf.tickLength / 1000, 8, 3
        @altWorld.ClearForces()
      if gm.tick of gm.actions
        fn() for fn in gm.actions[gm.tick]
        delete gm.actions[gm.tick]

    removeObjs: ->
      for obj in @destroyedObjs
        @objs.splice @objs.indexOf(obj), 1
        delete io.objDict[obj.id]
      @destroyedObjs = []

    rayCast: (laser, world = @world) ->
      target = null
      endPos = null
      bestFraction = 1
      fn = (f, pos, normal, fraction) ->
        if fraction < bestFraction
          target = f
          bestFraction = fraction
          endPos = pos
        fraction
      world.RayCast fn, laser.startPos, laser.endPos
      if endPos is null then [laser.endPos, null] else [endPos, target]

    createWorlds: ->
      @world = new b2.world new b2.vec(0, conf.gravity), true
      @altWorld = new b2.world new b2.vec(0, conf.userGravity), true
      @wall = new gm.Obj
      @wall.static = true
      @wall.body = @createBody @world, b2.staticBody
      @wall.body.obj = @wall
      @wall.altBody = @createBody @altWorld, b2.staticBody
      @wall.altBody.obj = @wall
      @setContactListener()
      @zeroGravity = new b2.constantAccelController()
      @zeroGravity.A = new b2.vec 0, -conf.gravity
      @world.AddController @zeroGravity

    setContactListener: ->
      l = new b2.contactListener()
      l.BeginContact = (c) =>
        for f in [c.GetFixtureA(), c.GetFixtureB()]
          obj = f.GetBody().obj
          if obj isnt null and obj.isProjectile
            @handleProjectileCollision obj

      @world.SetContactListener l

    settleLastUser: (b1, b2) ->
      return unless b1.obj.dynamic and b2.obj.dynamic
      if @isMoreDeadly b1, b2
        b2.obj.lastUser = b1.obj.lastUser
        @propagateLastUser b2
      else
        b1.obj.lastUser = b2.obj.lastUser
        @propagateLastUser b1

    removeLaser: (laser) ->
      i = @lasers.indexOf(laser)
      @lasers.splice i, 1 if i >= 0

    startRemovingLaser: (laser) ->
      laser.isActive = true
      window.setTimeout ( => @removeLaser laser ), conf.activeDuration

    activateLaser: (laser) ->
      [impactPos, target] = @rayCast laser
      laser.impactPos = impactPos
      @startRemovingLaser laser
      if target isnt null
        body = target.GetBody()
        if body.obj.dynamic
          scalar = if laser.isAltFire then conf.laser.altImpulse else conf.laser.impulse
          impulse = impactPos.copy().subtract(laser.startPos).setLength(scalar * body.GetMass()).multiply -1
          body.ApplyImpulse impulse, impactPos
          body.obj.lastUser = laser.user
          @propagateLastUser body
      return unless conf.laser.isLethal and laser.user isnt sam
      #@handleLethalLaser laser, sam.ghostPos

    activateSniper: (laser, tick) ->
      return unless sam.alive
      if tick is gm.tick
        pos = sam.pos
      else
        i = tick - sam.historyFirstTick
        return unless i >= 0
        pos = sam.history[i]
      @handleLethalLaser laser, pos

    handleLethalLaser: (laser, pos) ->
      return unless sam.alive
      [v, w] = [laser.startPos, laser.impactPos]
      input = new b2.rayCastIn v, w
      output = new b2.rayCastOut
      if gm.User.shape.RayCast output, input, new b2.transform pos, b2.mat.FromAngle 0
        impulse = w.copy().subtract(v).setLength(conf.lethalLaserImpulse)
        impactPos = w.copy().subtract(v).multiply(output.fraction).add(v)
        sam.die laser.user, pos, impulse, impactPos

    activateLauncher: (launch) ->
      @launches.splice @launches.indexOf(launch), 1
      obj = launch.obj
      unless @isFreePos obj.getShape(), launch.pos, launch.angle
        launch.user.addObj obj
        return
      obj.body.SetActive true
      obj.owner = null
      obj.body.SetPositionAndAngle launch.pos, launch.angle
      launch.user.spaceLeft++
      unless launch.isAltFire
        impulse = new b2.vec Math.cos(launch.fireAngle), Math.sin(launch.fireAngle)
        impulse.Multiply conf.launcher.impulse * obj.body.GetMass()
        obj.body.ApplyImpulse impulse, launch.pos
      obj.lastUser = launch.user
      # @makeProjectile obj

    activateAutoLauncher: (launch) ->
      if --launch.salvos is 0
        @launches.splice @launches.indexOf(launch), 1
      else
        gm.addAction gm.tick + conf.autoLauncher.salvoDelayTicks, => map.activateAutoLauncher launch
      if conf.autoLauncher.shouldLaunchDiscs
        shape = @getDiscShape conf.autoLauncher.box.w / 2
      else
        shape = @getRect conf.autoLauncher.box.w, conf.autoLauncher.box.h
      unless @isFreePos shape, launch.pos, launch.angle
        launch.user.autoLauncherAmmo++
        return
      if conf.autoLauncher.shouldLaunchDiscs
        obj = @addDisc conf.autoLauncher.box.w / 2, launch.pos.x, launch.pos.y, launch.angle
      else
        obj = @addBox conf.autoLauncher.box.w, conf.autoLauncher.box.h, launch.pos.x, launch.pos.y, launch.angle
      impulse = new b2.vec Math.cos(launch.fireAngle), Math.sin(launch.fireAngle)
      impulse.Multiply conf.autoLauncher.impulse * obj.body.GetMass()
      obj.body.ApplyImpulse impulse, launch.pos
      obj.lastUser = launch.user
      @makeProjectile obj

    makeProjectile: (obj) ->
      obj.isProjectile = true
      @zeroGravity.AddBody obj.body

    handleProjectileCollision: (obj) ->
      obj.isProjectile = false
      @zeroGravity.RemoveBody obj.body

    isDeadly: (body) ->
      body.GetLinearVelocity().Length() > conf.deadlyVelocity

    isMoreDeadly: (b1, b2) ->
      b1.GetLinearVelocity().Length() > b2.GetLinearVelocity().Length()

    isFreePos: (shape, pos, angle = 0) ->
      free = true
      @queryShape shape, pos, angle, (f) ->
        free = false
      free

    queryShape: (shape, pos, angle, fn) ->
      ###
      @counter = 0 if not @counter?
      @counter++
      dom.showStatus @counter
      ###
      @world.QueryShape fn, shape, new b2.transform pos, b2.mat.FromAngle angle

    propagateLastUser: (body) ->
      contactedge = body.GetContactList()
      while contactedge
        other = contactedge.other
        if contactedge.contact.IsTouching() and other.obj.dynamic and @isMoreDeadly body, other
          other.obj.lastUser = body.obj.lastUser
          @propagateLastUser other
        contactedge = contactedge.next

    createBody: (world, type, position = null, active = true) ->
      bodyDef = new b2.bodyDef
      bodyDef.type = type
      bodyDef.active = active
      bodyDef.position = position if position isnt null
      world.CreateBody bodyDef

    getRagdollBody: (user) ->
      if @inactiveRagdolls.length is 0
        body = @createBody @altWorld, b2.dynamicBody, null, false
        @addFixture body, @getRect(conf.user.w, conf.user.h), conf.friction.ragdoll, conf.restitution.ragdoll, conf.group.ragdolls
        @inactiveRagdolls.push body
      body = @inactiveRagdolls.pop()
      body.SetUserData user
      @ragdolls.push body
      fn = =>
        body.SetActive false
        @ragdolls.splice @ragdolls.indexOf(body), 1
        @inactiveRagdolls.push body
      window.setTimeout fn, conf.ragdollLifetime
      body.SetAngle 0
      body.SetLinearVelocity new b2.vec
      body.SetAngularVelocity 0
      body.obj = null
      body

    addFixture: (body, shape, friction, restitution, category, group = 0, mask = 0xFFFF) ->
      fixDef = new b2.fixDef
      fixDef.friction = friction
      fixDef.restitution = restitution
      fixDef.filter.categoryBits = category
      fixDef.filter.groupIndex = group
      fixDef.filter.maskBits = mask
      fixDef.shape = shape
      fixDef.density = 1
      body.CreateFixture fixDef

    getRect: (w, h, x = 0, y = 0, angle = 0) ->
      shape = new b2.polygonShape
      shape.SetAsOrientedBox w / 2, h / 2, new b2.vec(x, y), angle
      shape

    getHorEdge: (w, x = 0, y = 0) ->
      shape = new b2.polygonShape
      shape.SetAsEdge new b2.vec(x - w / 2, y), new b2.vec(x + w / 2, y)
      shape

    getVerEdge: (w, x = 0, y = 0) ->
      shape = new b2.polygonShape
      shape.SetAsEdge new b2.vec(x, y - w / 2), new b2.vec(x, y + w / 2)
      shape

    getDiscShape: (r, x = 0, y = 0) ->
      shape = new b2.circleShape r
      shape.SetLocalPosition new b2.vec x, y
      shape

    limitVelocity: (body) ->
      vel = body.GetLinearVelocity()
      isProjectile = body.obj isnt null and body.obj.isProjectile
      if vel.Length() > conf.terminalVelocity and not isProjectile
        vel.Multiply conf.terminalDragFactor

    addWall: (w, h, x, y, angle = 0) ->
      f = @addFixture @wall.body, @getRect(w, h, x, y, angle), conf.friction.wall, conf.restitution.wall, conf.category.wall
      @addFixture @wall.altBody, @getRect(w, h, x, y, angle), conf.friction.wall, conf.restitution.wall, conf.category.wall

    addBox: (w, h, x, y, angle = 0) ->
      obj = new gm.Obj
      obj.isRect = true
      obj.dynamic = true
      obj.size = w: w, h: h
      obj.body = @createBody @world, b2.dynamicBody, new b2.vec(x, y)
      @addFixture obj.body, @getRect(w, h, 0, 0), conf.friction.box, conf.restitution.box, conf.category.obj
      obj.body.SetAngle angle
      obj.body.obj = obj
      @objs.push obj
      obj

    addKinematic: (w, h, x, y, angle = 0) ->
      body = @createBody @world, b2.kinematicBody, new b2.vec(x, y)
      @addFixture body, @getRect(w, h, 0, 0), conf.friction.wall, conf.restitution.wall, conf.category.wall
      body.SetAngle angle
      body.obj = null
      @kinematics.push body
      body

    addDisc: (r, x, y, angle = 0) ->
      obj = new gm.Obj
      obj.size = r: r, w: 2 * r, h: 2 * r
      obj.isDisc = true
      obj.dynamic = true
      obj.body = @createBody @world, b2.dynamicBody, new b2.vec(x, y)
      @addFixture obj.body, @getDiscShape(r), conf.friction.disc, conf.restitution.disc, conf.category.obj
      obj.body.SetAngle angle
      obj.body.obj = obj
      @objs.push obj
      obj

    addBoundary: (thickness) ->
      t = thickness * 2
      @addWall t, @h + t, 0, @h / 2
      @addWall t, @h + t, @w, @h / 2
      @addWall @w + t, t, @w / 2, 0
      @addWall @w + t, t, @w / 2, @h

    addSpawn: (x, y) ->
      @spawnPositions.push new b2.vec x, y

    getMap: ->
      [@w, @h] = [60, 40]
      t = 1  # platform thickness
      a = 8  # platform height
      a1 = 10  # ceiling height
      a2 = 5  # spawn height
      [b1, b3, b4] = [15, 3, 10]  # platform widths
      c1 = 2  # boundary block width
      d4 = 12  # top platform distance to wall
      @destroyOutOfBounds = false

      addPlatform = (w, x, y) =>
        @addWall w, t, x, y
        @addSpawn x, y - a2

      # add floor
      @addWall @w, t, @w / 2, @h - t / 2

      # add ceiling
      @addWall @w, t, @w / 2, -a1

      # add walls
      gap = a * 2 - t / 2
      h = @h + a1 - gap
      @addWall t, h, t / 2, @h - h / 2 - gap
      @addWall t, h, @w - t / 2, @h - h / 2 - gap

      # add lowest platforms
      x = b1 / 2 + b3 + t
      y = @h - a
      addPlatform b1, x, y
      addPlatform b1, @w - x, y
      @addSpawn x, @h - a2
      @addSpawn @w - x, @h - a2

      # add middle platforms
      x = b3 / 2 + t
      y = @h - a * 2
      addPlatform b3, x, y
      addPlatform b3, @w - x, y

      # add top platforms
      x = b4 / 2 + t + d4
      y = @h - a * 3
      addPlatform b4, x, y
      addPlatform b4, @w - x, y

      # add boundary block towers
      h = 12
      cols = 1
      rows = 6
      @addLousyWall c1, h, c1 / 2 + t, @h - h / 2 - t, cols, rows
      @addLousyWall c1, h, @w - c1 / 2 - t, @h - h / 2 - t, cols, rows

      # add block tower (starting at bottom)
      [w1, w2, w3, w4] = [4, 3, 1.4142, 1.4142]  # width of blocks
      r = 1.2  # radius of disc
      x = @w / 2
      y = @h - t
      @addBox w1, w1, x, y - w1 / 2
      y -= w1
      h = w1
      @addLousyWall w1 + 0.1, h, x, y - h / 2, 3, 1
      y -= h
      @addBox w2, w2, x, y - w2 / 2
      y -= w2
      @addBox w2, w2, x, y - w2 / 2
      y -= w2
      #h = w2
      #@addLousyWall w2 + 0.05, h, x, y - h / 2, 2, 1
      #y -= h
      #@addBox w3, w3, x, y - w3 / 2
      #y -= w3
      h = w1
      w = w1 / 3
      @addBox w, h, x, y - h / 2
      y -= h
      @addBox w, h, x, y - h / 2
      y -= h
      @addDisc r, x, y - r, Math.PI / 4

      @setDefaultStyle()
      @equipSam()

      teleportBox = =>
        for obj in @objs
          body = obj.body
          pos = body.GetPosition()
          if body.IsActive() and (pos.y > @h + 5 or pos.x < -5 or pos.x > @w + 5)
            body.SetLinearVelocity new b2.vec 0, 0
            body.SetAngularVelocity 0
            body.SetPositionAndAngle (new b2.vec @w / 2, -5), 0
            obj.lastUser = null
            break
        gm.addAction gm.tick + 120, teleportBox
      gm.addAction 50, teleportBox

    getMap1: ->
      [@w, @h] = [50, 50]
      pady = 2
      padx = 5
      spawns = 10
      spawnHeight = 4
      t = 1
      w = @w - 2 * padx
      @addWall w, t, @w / 2, @h - pady
      for i in [1..spawns]
        @addSpawn padx + w / spawns * i, @h - pady - t / 2 - spawnHeight
      @setDefaultStyle()
      @equipSam()
      spawnBoxes = =>
        if (obj for obj in @objs when obj.body.IsActive()).length <= 5
          while (obj for obj in @objs when obj.body.IsActive()).length < 10
            @addBox helper.random(1, 3), helper.random(1, 3), helper.random(padx, @w - padx), helper.random(-10, -2)
        gm.addAction gm.tick + 50, spawnBoxes
      gm.addAction 50, spawnBoxes

    getMap2: ->
      [@w, @h] = [40, 60]
      a = 10
      b = @h-3
      c = (@w - a) / 2
      @addWall a, @h-b+1, @w / 2, b+(@h-b+1)/2, .1
      @addWall a, @h-b+1, @w / 2, b+(@h-b+1)/2, -.3
      @addWall a, @h-b+1, @w / 2+3, b+(@h-b+1)/2, -.4
      @addWall a, @h-b+1, @w / 2+9, b+(@h-b+1)/2, -.5
      @addWall a, @h-b+1, @w / 2+3, b+(@h-b+1)/2-8, -.4
      @addWall a, @h-b+1, @w / 2+9, b+(@h-b+1)/2-10, -.5
      @addWall a, @h-b+1, @w / 2-5, b+(@h-b+1)/2-8, -.6
      @addSpawn @w/2, b - 1

      #body = @addKinematic 10, 1, c, b-1
      #body.SetLinearVelocity new b2.vec 3, 0

      spawnBoxes = =>
        @addBox helper.random(1, 3), helper.random(1, 3), helper.random(11, @w - 11), -1
        gm.addAction gm.tick + 10, spawnBoxes
      gm.addAction 10, spawnBoxes

      @setDefaultStyle()
      @equipSam()

    setDefaultStyle: ->
      convert = helper.getCssColor
      @style =
        obj:
          fill: convert conf.color.obj.fill
          stroke: convert conf.color.obj.stroke
        deadlyObj:
          fill: convert conf.color.deadlyObj.fill
          stroke: convert conf.color.deadlyObj.stroke
        ghostObj:
          fill: convert conf.color.obj.fill, conf.alpha.ghostObj
          stroke: convert conf.color.obj.stroke, conf.alpha.ghostObj
        faintObj:
          fill: convert conf.color.obj.fill, conf.alpha.faintObj
          stroke: convert conf.color.obj.stroke, conf.alpha.faintObj
        wall:
          fill: convert conf.color.wall.fill
          stroke: convert conf.color.wall.stroke
        sniper: convert conf.color.sniper, conf.alpha.laser
        faintSniper: convert conf.color.faintLaser, conf.alpha.faintSniper
        activeSniper: convert conf.color.sniper

    # , 'autoLauncher', 'sniper'
    equipSam: (gunNames = ['launcher', 'laser'], spaceLeft = 3, defaultGun = conf.laser) ->
      sam.guns = [null, null, null, null, null, null, null, null, null, null, null]
      for name in gunNames
        new gm.Gun name
      @defaultGun = sam.guns[defaultGun.slot]
      sam.spaceLeft = spaceLeft

    addLousyWall: (w, h, x, y, cols, rows) ->
      box = w: w / cols, h: h / rows
      start = x: x - w / 2 + box.w / 2, y: y + h / 2 - box.h / 2
      for j in [0..rows - 1]
        for i in [0..cols - 1]
          @addBox box.w, box.h, start.x + i * box.w, start.y - j * box.h

  map = new Map
