define ['dist/Box2dWeb-2.1.a.3.modified'], ->
  round = (x) ->
    Math.round(x * 1000000000) / 1000000000

  b2 =
    vec: Box2D.Common.Math.b2Vec2
    mat: Box2D.Common.Math.b2Mat22
    bodyDef: Box2D.Dynamics.b2BodyDef
    body: Box2D.Dynamics.b2Body
    fixDef: Box2D.Dynamics.b2FixtureDef
    fix: Box2D.Dynamics.b2Fixture
    world: Box2D.Dynamics.b2World
    massData: Box2D.Collision.Shapes.b2MassData
    polygonShape: Box2D.Collision.Shapes.b2PolygonShape
    circleShape: Box2D.Collision.Shapes.b2CircleShape
    debugDraw: Box2D.Dynamics.b2DebugDraw
    contactListener: Box2D.Dynamics.b2ContactListener
    color: Box2D.Common.b2Color
    dynamicBody: Box2D.Dynamics.b2Body.b2_dynamicBody
    staticBody: Box2D.Dynamics.b2Body.b2_staticBody
    kinematicBody: Box2D.Dynamics.b2Body.b2_kinematicBody
    constantAccelController: Box2D.Dynamics.Controllers.b2ConstantAccelController
    transform: Box2D.Common.Math.b2Transform
    rayCastIn: Box2D.Collision.b2RayCastInput
    rayCastOut: Box2D.Collision.b2RayCastOutput
    aabb: Box2D.Collision.b2AABB
    manifold: Box2D.Collision.b2Manifold
    collision: Box2D.Collision.b2Collision

    safeMath:
      sin: (x) ->
        round Math.sin x
      cos: (x) ->
        round Math.cos x
      tan: (x) ->
        round(Math.sin x) / round(Math.cos x)
      asin: (x) ->
        round Math.asin x
      atan2: (y, x) ->
        round Math.atan2 y, x

  window.SafeMath = b2.safeMath

  b2.vec.prototype.add = (v, y = null) ->
    if y isnt null
      @x += v
      @y += y
    else
      @x += v.x
      @y += v.y
    @

  b2.vec.prototype.addX = (x) ->
    @x += x
    @

  b2.vec.prototype.addY = (y) ->
    @y += y
    @

  b2.vec.prototype.subtract = (v) ->
    @x -= v.x
    @y -= v.y
    @

  b2.vec.prototype.setV = (v) ->
    @x = v.x
    @y = v.y
    @

  b2.vec.prototype.set = (x, y) ->
    @x = x
    @y = y
    @

  b2.vec.prototype.setZero = ->
    @x = 0
    @y = 0
    @

  b2.vec.prototype.addMultiple = (v, a) ->
    @x += v.x * a
    @y += v.y * a
    @

  b2.vec.prototype.multiply = (a) ->
    @x *= a
    @y *= a
    @

  b2.vec.prototype.negate = ->
    @x *= -1
    @y *= -1
    @

  b2.vec.prototype.divide = (a) ->
    @x /= a
    @y /= a
    @

  b2.vec.prototype.copy = ->
    @Copy()

  b2.vec.prototype.normalize = (a) ->
    @Normalize()
    @

  b2.vec.prototype.setLength = (a) ->
    @Normalize()
    @Multiply a
    @

  b2.vec.prototype.setX = (a) ->
    @x = a
    @

  b2.vec.prototype.setY = (a) ->
    @y = a
    @

  b2.vec.prototype.setMinLength = (a) ->
    if @Length() < a
      @Normalize()
      @Multiply a
    @

  b2.vec.prototype.length = ->
    @Length()

  b2.vec.prototype.equals = (v) ->
    @x is v.x and @y is v.y

  b2.vec.prototype.isZero = ->
    @x is 0 and @y is 0

  b2
