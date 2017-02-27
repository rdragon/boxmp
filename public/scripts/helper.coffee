do ->
  fn = (require) ->
    conf = require './config'
    MRG32k3a = require './dist/MRG32k3a'
    md5: require './dist/md5'

    rand: null
    randPrivate: null

    seed: (seed) ->
      @rand = MRG32k3a seed

    seedPrivate: (seed) ->
      @randPrivate = MRG32k3a seed

    random: (a, b = null) ->
      [a, b] = [0, a] if b is null
      @rand() * (b - a) + a

    randomPrivate: (a, b = null) ->
      [a, b] = [0, a] if b is null
      @randPrivate() * (b - a) + a

    randomInt: (a, b = null) ->
      [a, b] = [0, a] if b is null
      @rand.uint32() % (b - a) + a

    randomIntPrivate: (a, b = null) ->
      [a, b] = [0, a] if b is null
      @randPrivate.uint32() % (b - a) + a

    shufflePrivate: (ar) ->
      ar2 = new Array ar.length
      for a, i in ar
        ar2[i] = a
      for a, i in ar
        j = @randomIntPrivate i, ar.length
        [ar2[i], ar2[j]] = [ar2[j], ar2[i]]
      ar2

    getCalculatedValue: ->
      x = 1
      for n in [0..1000]
        x = SafeMath.sin x * 10000
      x

    sign: (x) ->
      if x < 0 then -1 else 1

    confine: (x, min, max = null) ->
      [min, max] = [-min, min] if max is null
      if x < min
        min
      else if x > max
        max
      else
        x

    hasLocalStorage: ->
      try
        localStorage.setItem 'x', 'x'; localStorage.removeItem 'x'; true
      catch e
        false

    getCssColor: ([r, g, b], alpha = 1, brightness = 1) ->
      r = Math.round r * brightness
      g = Math.round g * brightness
      b = Math.round b * brightness
      "rgba(#{r},#{g},#{b},#{alpha})"

    roundVec: (vec) ->
      vec.x = Math.round(vec.x * 1000) / 1000
      vec.y = Math.round(vec.y * 1000) / 1000

    roundFloat: (x) ->
      x = Math.round(x * 1000) / 1000

    getApprovedName: (name) ->
      return null if name.match(/\w/).length is 0
      name = name.replace /^\s+|\s+$/g, ''
      String(name).substr 0, conf.maxNameLength

  if exports? then module.exports = fn require else define fn
