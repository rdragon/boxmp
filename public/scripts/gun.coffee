define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Gun
    @init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar

    constructor: (@name) ->
      @proto = conf[@name]
      @reloadTicks = @proto.reloadTicks
      @spawnAmmo = @proto.spawnAmmo
      @reloading = false
      @ammo = 0
      sam.guns[@proto.slot] = @

    onReloadDone: =>
      return unless @reloading
      @reloading = false
      @onPossibleReady()

    onPossibleReady: ->
      if not @reloading and @ammo > 0 and sam.gun is @
        @showReady()

    onSpawnSam: ->
      @ammo = @spawnAmmo if @spawnAmmo isnt null
      @reloading = false

    showReady: ->
      $('canvas').css 'cursor', 'crosshair'

    showNotReady: ->
      #temp $('canvas').css 'cursor', 'default'

    fire: (targetPos, isAltFire) ->
      return if @reloading or @ammo is 0
      @['fire' + @name.charAt(0).toUpperCase() + @name.slice(1)] targetPos, isAltFire
      @ammo--
      @reloadGun()

    reloadGun: ->
      @reloading = true
      @showNotReady()
      gm.addAction gm.tick + @reloadTicks, @onReloadDone

    fireLauncher: (targetPos, isAltFire) ->
      obj = sam.objs.pop()
      [pos, angle, fireAngle] = @getLaunchPos targetPos, obj
      helper.roundVec pos
      helper.roundFloat angle
      launch = new gm.Launch pos, angle, fireAngle, isAltFire, sam
      launch.obj = obj
      io.emit 'fire launcher', pos.x, pos.y, angle, fireAngle, isAltFire, obj.id, (tick) =>
        gm.addAction tick, => map.activateLauncher launch
      map.launches.push launch

    fireAutoLauncher: (targetPos, isAltFire) ->
      [pos, angle] = @getLaunchPos targetPos
      helper.roundVec pos
      helper.roundFloat angle
      launch = new gm.Launch pos, angle, angle, isAltFire, sam
      launch.salvos = conf.autoLauncher.salvos
      io.emit 'fire autoLauncher', pos.x, pos.y, angle, angle, isAltFire, (tick) =>
        gm.addAction tick, => map.activateAutoLauncher launch
      map.launches.push launch

    getLaunchPos: (targetPos, obj = null) ->
      pos = sam.pos.copy()
      fireAngle = Math.atan2 targetPos.y - pos.y, targetPos.x - pos.x
      if obj is null
        angle = fireAngle
        r = conf.autoLauncher.box.w / 2
      else
        angle = if obj.isRect and obj.size.h > obj.size.w then fireAngle + Math.PI / 2 else fireAngle
        r = Math.max(obj.size.w, obj.size.h) / 2
      offset = new b2.vec targetPos.x - pos.x, targetPos.y - pos.y
      offset.setLength .2 + (new b2.vec conf.user.w / 2, conf.user.h / 2).length() + r
      pos.Add offset
      pos.y -= .1
      [pos, angle, fireAngle]

    fireLaser: (targetPos, isAltFire) ->
      startPos = @getStartAndTargetPos targetPos
      helper.roundVec startPos
      helper.roundVec targetPos
      laser = new gm.Laser startPos, targetPos, isAltFire, sam
      map.lasers.push laser
      io.emit 'new laser', startPos.x, startPos.y, targetPos.x, targetPos.y, isAltFire, (tick) =>
        gm.addAction tick, => map.activateLaser laser

    fireSniper: (targetPos, isAltFire) ->
      startPos = @getStartAndTargetPos targetPos
      laser = new gm.Laser startPos, targetPos, isAltFire, sam
      [impactPos] = map.rayCast laser
      laser.impactPos = impactPos
      helper.roundVec startPos
      helper.roundVec impactPos
      laser.fromSniper = true
      map.lasers.push laser
      tick = gm.tick + sam.ghostDelayTicks
      removeTick = if conf.diffGhostDelay then tick else tick + sam.ghostDelayTicks
      gm.addAction removeTick, -> map.startRemovingLaser laser
      io.emit 'fire sniper', startPos.x, startPos.y, impactPos.x, impactPos.y, isAltFire, tick

    getStartAndTargetPos: (targetPos) ->
      startPos = sam.pos.copy().add(conf.fireOffset)
      targetPos.subtract(startPos).setLength(@proto.range).add(startPos)
      startPos
