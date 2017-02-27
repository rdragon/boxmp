define ->
  gm = conf = b2 = helper = map = cam = io = dom = sam = null

  class Obj
    @init: (ar) ->
      [gm, conf, b2, helper, map, cam, io, dom, sam] = ar

    constructor: ->
      @id = io.objCounter++
      io.objDict[@id] = @
      @size = null
      @isDisc = false
      @isRect = false
      @static = false
      @dynamic = false
      @lastUser = null
      @isProjectile = false
      @body = null
      @altBody = null
      @claim =
        user: null
        tick: 0
      @owner = null

    doStuff: ->
      return unless @body.IsActive()
      map.limitVelocity @body
      if map.destroyOutOfBounds
        pos = @body.GetPosition()
        if pos.x < -5 or pos.y < -20 or pos.x > map.w + 5 or pos.y > map.h + 5
          @destroy()

    destroy: ->
      map.world.DestroyBody @body
      map.destroyedObjs.push @

    isDeadly: ->
      map.isDeadly @body

    doClaim: (u, claimTick) ->
      return if @claim.user isnt null and (@claim.tick < claimTick or (@claim.tick is claimTick and @claim.user.id <= u.id))
      @claim.user.spaceLeft++ if @claim.user isnt null
      @claim.user = u
      @claim.tick = claimTick
      u.spaceLeft--
      if u is sam
        io.emit 'claim', @id, claimTick, (grabTick) =>
          gm.addAction grabTick, => @tryGrab u, claimTick

    tryGrab: (u, claimTick) ->
      return if @claim.user isnt u or @claim.tick isnt claimTick or not @body.IsActive()
      @claim.user = null
      unless @ in map.objs
        u.spaceLeft++
        return
      @owner = u
      @body.SetLinearVelocity new b2.vec 0, 0
      @body.SetAngularVelocity 0
      @body.SetActive false
      u.addObj @

    getShape: ->
      @body.GetFixtureList().GetShape()
