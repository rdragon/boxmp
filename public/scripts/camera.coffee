define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Camera
    constructor: ->
      @switchTimeout = null
      @scale = 0
      @ctx = null
      @target = null
      @pos = null
      @view = null
      @overlap = null
      @debugPoints = []
      @laser = null

    init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar
      @laser = new gm.Laser new b2.vec(), new b2.vec(), false, null

    reloadContext: ->
      @ctx = $('canvas')[0].getContext '2d'
      @ctx.lineWidth = conf.laserThickness
      @ctx.lineCap = 'round'
      @ctx.scale @scale, @scale

    updateViewAndScale: ->
      client = w: $(window).width(), h: $(window).height()
      @scale = client.w / conf.viewWidth
      @view = w: Math.min(client.w / @scale, map.w), h: Math.min(client.h / @scale, map.h)

    drawScene: ->
      return if @target is null
      @ctx.save()
      @focus()
      @clip()
      @ctx.translate -@pos.x, -@pos.y
      @ctx.clearRect 0, 0, map.w, map.h
      @drawLaser laser for laser in map.lasers
      @drawObjs()
      @drawRagdolls()
      @drawGun() if sam.alive
      @drawUsers()
      @drawLaunches()
      @drawWall()
      @drawKinematics()
      @drawDebugStuff()
      @ctx.restore()

    drawGun: ->
      if sam.swappingGuns is 0 and sam.gun.ammo > 0 and not sam.gun.reloading
        if sam.gun.name is 'launcher'
          obj = _.last sam.objs
          targetPos = dom.getWorldPos dom.mouse.x, dom.mouse.y
          [pos, angle] = sam.gun.getLaunchPos targetPos, obj
          @drawObj obj, pos, angle, map.style.faintObj, true
        else if sam.gun.name is 'autoLauncher'
          targetPos = dom.getWorldPos dom.mouse.x, dom.mouse.y
          [pos, angle] = sam.gun.getLaunchPos targetPos
          if conf.autoLauncher.shouldLaunchDiscs
            @drawDisc conf.autoLauncher.box.w / 2, pos, angle, map.style.faintObj, true
          else
            @drawRect conf.autoLauncher.box, pos, angle, map.style.faintObj
        else if sam.gun.name is 'laser' or sam.gun.name is 'sniper'
          w = dom.getWorldPos dom.mouse.x, dom.mouse.y
          v = sam.gun.getStartAndTargetPos w
          @laser.startPos = v
          @laser.endPos = w
          style = if sam.gun.name is 'laser' then sam.style.faintLaser else map.style.faintSniper
          @drawLaser @laser, style

    drawRagdolls: ->
      for body in map.ragdolls
        @drawRect conf.user, body.GetPosition(), body.GetAngle(), body.GetUserData().style.ragdoll

    drawUsers: ->
      for u in gm.users when u.alive
        if u is sam
          @drawRect conf.user, sam.ghostPos, 0, sam.style.ghost
          style = sam.style
        else
          style = u.style #if u.extrapolating then {fill: 'black', stroke: 'black'} else u.style
        @drawRect conf.user, u.pos, 0, style

    drawDebugStuff: ->
      for pos in @debugPoints
        @drawRect {w: .1, h: .1}, pos, 0, {fill: 'black', stroke: 'black'}

    setTarget: (target) ->
      @target = target
      @pos = @target.pos.copy()

    clip: ->
      @pos.x = Math.max @pos.x, 0
      @pos.y = Math.max @pos.y, 0
      @pos.x = Math.min @pos.x, map.w - @view.w
      @pos.y = Math.min @pos.y, map.h - @view.h

    focus: ->
      maxw = @view.w * (1 - conf.focusFactor) / 2
      maxh = @view.h * (1 - conf.focusFactor) / 2
      targetPos = @target.pos

      @pos.x = Math.min @pos.x, targetPos.x - maxw
      @pos.y = Math.min @pos.y, targetPos.y - maxh
      @pos.x = Math.max @pos.x, targetPos.x - @view.w + maxw
      @pos.y = Math.max @pos.y, targetPos.y - @view.h + maxh

    drawPolygon: (vertices, transform, style) ->
      @ctx.fillStyle = style.fill
      @ctx.strokeStyle = style.stroke
      @ctx.beginPath()
      w = new b2.vec
      for v, i in vertices
        w.setV v
        w.MulM(transform.R)
        w.Add transform.position
        @ctx.lineTo w.x, w.y
      @ctx.closePath()
      @ctx.fill()
      @ctx.stroke()

    drawRect: (size, pos, angle, style) ->
      @ctx.save()
      @ctx.translate pos.x, pos.y
      @ctx.rotate angle
      @ctx.fillStyle = style.fill
      @ctx.strokeStyle = style.stroke
      @ctx.fillRect -size.w / 2, -size.h / 2, size.w, size.h
      @ctx.strokeRect -size.w / 2, -size.h / 2, size.w, size.h
      @ctx.restore()

    drawDisc: (r, pos, angle, style, withoutRect = false) ->
      @ctx.save()
      @ctx.translate pos.x, pos.y
      @ctx.rotate angle
      @ctx.fillStyle = style.fill
      @ctx.strokeStyle = style.stroke
      @ctx.beginPath()
      @ctx.arc 0, 0, r, 0, Math.PI * 2, false
      @ctx.fill()
      @ctx.stroke()
      unless withoutRect
        a = r * .5 * Math.sqrt 2
        @ctx.fillStyle = 'rgba(0, 0, 0, .2)' # tmp
        @ctx.fillRect -a, -a, 2 * a, 2 * a
      @ctx.restore()

    drawWall: ->
      body = map.wall.body
      transform = body.GetTransform()
      f = body.GetFixtureList()
      while f
        @drawPolygon f.GetShape().GetVertices(), transform, map.style.wall
        f = f.GetNext()

    drawKinematics: ->
      for body in map.kinematics
        transform = body.GetTransform()
        f = body.GetFixtureList()
        while f
          @drawPolygon f.GetShape().GetVertices(), transform, map.style.wall
          f = f.GetNext()

    drawObjs: ->
      for obj in map.objs
        body = obj.body
        continue unless body.IsActive()
        @drawObj obj, body.GetPosition(), body.GetAngle()

    drawObj: (obj, pos, angle, style = null, withoutRect = false) ->
        style = @getObjStyle obj if style is null
        if obj.isDisc
          @drawDisc obj.size.r, pos, angle, style, withoutRect
        else
          @drawRect obj.size, pos, angle, style

    drawLaunches: ->
      for launch in map.launches
        if launch.obj isnt null
          @drawObj launch.obj, launch.pos, launch.angle
        else if conf.autoLauncher.shouldLaunchDiscs
          @drawDisc conf.autoLauncher.box.w / 2, launch.pos, launch.angle, map.style.ghostObj
        else
          @drawRect conf.autoLauncher.box, launch.pos, launch.angle, map.style.ghostObj

    getObjStyle: (obj) ->
      if obj.claim.user isnt null
        if obj.isDeadly()
          obj.claim.user.style.claimedDeadlyObj
        else
          obj.claim.user.style.claimedObj
      else if obj.isDeadly()
        if obj.lastUser isnt null
          obj.lastUser.style.obj
        else
          map.style.deadlyObj
      else
        if obj.body.IsActive()
          map.style.obj
        else
          map.style.ghostObj

    drawLaser: (laser, style = null) ->
      @ctx.beginPath()
      impactPos = laser.impactPos
      [impactPos] = map.rayCast laser if impactPos is null
      @ctx.moveTo laser.startPos.x, laser.startPos.y
      @ctx.lineTo impactPos.x, impactPos.y
      if style is null
        if laser.fromSniper
          style = if laser.isActive then map.style.activeSniper else map.style.sniper
        else
          style = if laser.isActive then laser.user.style.fill else laser.user.style.laser
      @ctx.strokeStyle = style
      @ctx.stroke()

  new Camera
