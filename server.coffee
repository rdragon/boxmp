express = require 'express'
server = express()
http = require('http').Server server
io = require('socket.io')(http)
_ = require './public/scripts/dist/underscore.min'
conf = require './public/scripts/config'
helper = require './public/scripts/helper'

server.use express.static __dirname + '/public'

port = 7683
if 'heroku' in process.argv
  port = process.env.PORT
else if process.argv.length > 2 and /^[1-9][0-9]*$/.test process.argv[2]
  port = parseInt process.argv[2]

http.listen port, ->
  console.log "listening. on #{port}"

server.get '/', (req, res) ->
  res.sendFile 'index.html'

class User
  constructor: (socket) ->
    @socket = socket
    @id = 0
    @guid = guidCounter++
    @enabled = false
    @name = null
    @gm = null
    @state = null
    @calculatedValue = 0
    @sendTickDelayed = _.debounce @sendTick, conf.heartbeatInterval
    @alive = false
    @tick = 0
    @catchingUp = false
    @score =
      rounds:
        won: 0
        played: 0

    socket.on 'disconnect', =>
      console.log "#{@toString()} disconnected"
      @gm?.remove @

    socket.on 'get time', (fn) =>
      fn Date.now()

    socket.on 'join game', =>
      if @gm is null
        if game.users.length < conf.maxUsers
          game.add @
        else
          socket.emit 'print', 'Game is full.'

    socket.on 'done catching up', =>
      return if @gm is null or not @gm.running or not @catchingUp
      @enabled = true
      @catchingUp = false
      socket.emit 'spawn', helper.randomInt 9999

    socket.on 'user ping', (ping) =>
      @broadcast 'user ping', @id, ping

    socket.on 'new laser', (x1, y1, x2, y2, isAltFire, fn) =>
      return unless @enabled
      tick = @gm.getActionTick()
      @push 'new laser', @id, tick, x1, y1, x2, y2, isAltFire
      fn tick

    socket.on 'fire sniper', (x1, y1, x2, y2, isAltFire, tick) =>
      return unless @enabled
      @broadcast 'sniper fired', @id, tick, x1, y1, x2, y2, isAltFire

    socket.on 'fire launcher', (x, y, angle, fireAngle, isAltFire, objId, fn) =>
      return unless @enabled
      tick = @gm.getActionTick()
      @push 'launcher fired', @id, tick, x, y, angle, fireAngle, isAltFire, objId
      fn tick

    socket.on 'fire autoLauncher', (x, y, angle, fireAngle, isAltFire, fn) =>
      return unless @enabled
      tick = @gm.getActionTick()
      @push 'autoLauncher fired', @id, tick, x, y, angle, fireAngle, isAltFire
      fn tick

    socket.on 'claim', (objId, claimTick, fn) =>
      return unless @enabled
      grabTick = @gm.getActionTick()
      @push 'new claim', @id, objId, claimTick, grabTick
      fn grabTick

    socket.on 'die', (tick, killerId, snapshot, fn) =>
      return unless @enabled
      killerId = null unless _.any @gm.users, (u) -> u.id is killerId
      @push 'user died', @id, tick, killerId, snapshot
      fn()
      @alive = false
      round = @gm.round
      fnSpawn = =>
        socket.emit 'spawn', helper.randomInt 9999 if @gm?.running and @gm?.round is round
      setTimeout fnSpawn, conf.respawnDelay

    socket.on 'spawn', (tick, pos) =>
      return unless @enabled
      @push 'user spawned', @id, tick, pos
      @alive = true
      @tick = tick

    socket.on 'end of round', (round) =>
      return unless @enabled and @gm?.round is round and @gm.running
      @gm.endRound()

    socket.on 'name', (name) =>
      @name = helper.getApprovedName name
      @push 'name', @id, @name if @name isnt null

    socket.on 'chat', (msg) =>
      @broadcast 'chat', @id, msg

    socket.on 'pos', (x, y, velY, walkDir) =>
      return unless @enabled
      @broadcast 'pos', @id, x, y, velY, walkDir, @gm.getTick()
      u.sendTickDelayed() for u in @gm.users when u isnt @
      @tick += conf.sendPosInterval

    socket.on 'won round', =>
      @score.rounds.won++

    socket.on 'state', (tick, hash) =>
      return unless @enabled
      @state = tick: tick, hash: hash
      return unless _.all(@gm.users, (u) -> u.state?.tick is tick)
      groups = _.groupBy @gm.users, (u) -> u.state.hash
      return unless _.size(groups) > 1
      s = 'the game is out of sync!'
      if @gm.users.length > 2
        fn = (group) -> _.map(group, (u) -> u.name).join ', '
        s += ' different instances: ' + _.map(groups, fn).join ' | '
      @gm.broadcast 'print', s

    socket.on 'calculated value', (@calculatedValue) =>

  onStartRound: ->
    @state = null
    @alive = false
    @tick = 0
    @catchingUp = false

  onJoinGame: ->
    @score.rounds.played = 0
    @score.rounds.won = 0

  onEndRound: ->
    @enabled = false
    @score.rounds.played++

  getInfoObj: ->
    id: @id
    name: @name
    won: @score.rounds.won
    played: @score.rounds.played

  toString: ->
    "#{@name || '(someone)'} (#{@guid})"

  sendTick: ->
    @socket.emit 'tick', @gm?.getTick()
    @sendTickDelayed()

  push: (msg, args...) ->
    @gm?.pushFrom @, msg, args...

  broadcast: (msg, args...) ->
    @gm?.broadcastFrom @, msg, args...

class Game
  constructor: ->
    @id = guidCounter++
    @userCounter = helper.randomInt conf.maxUsers
    @users = []
    @startTime = 0
    @lastActionTick = 0
    @running = false
    @his = []
    @round = 0

  add: (newUser) ->
    newUser.gm = @
    newUser.id = @userCounter++
    newUser.onJoinGame()
    newUser.socket.emit 'id', newUser.id
    unless @running
      args = @getUsersInfoMsg()
      newUser.socket.emit args...
    @users.push newUser
    if @users.length is 1 and conf.autoStart
      @pushFrom newUser, 'new user', newUser.id, newUser.name
      @newRound()
    else
      if @running
        newUser.onStartRound()
        newUser.catchingUp = true
        newUser.socket.emit 'start round', @round, @startTime, true, null
        for msg in @his
          newUser.socket.emit msg...
        newUser.sendTick()
        newUser.socket.emit 'start catching up'
        newUser.socket.emit 'track ticks', ({id: u.id, tick: u.tick + conf.sendPosTick} for u in @users when u isnt newUser)
      @pushFrom newUser, 'new user', newUser.id, newUser.name
    @broadcast 'print', 'Incompatible browsers detected!', true unless _.all @users, (u) -> u.calculatedValue is newUser.calculatedValue

  remove: (user) ->
    @users.splice @users.indexOf(user), 1
    user.gm = null
    user.enabled = false
    tick = if @running then @getActionTick() else null
    @push 'user left', user.id, tick

  getUsersInfoMsg: ->
    ['users', (u.getInfoObj() for u in @users)]

  newRound: =>
    @round++
    @startTime = Date.now()
    @lastActionTick = 0
    @running = true
    @his = []
    round = @round
    for u in @users
      u.onStartRound()
      u.socket.emit 'start round', @round, @startTime, false, do (u) =>
        (data) =>
          if @round is round
            u.enabled = true
      u.socket.emit 'spawn', helper.randomInt 9999
      u.sendTickDelayed()
    @his.push @getUsersInfoMsg()

  endRound: ->
    @running = false
    u.onEndRound() for u in @users
    @broadcast 'end of round'
    setTimeout @newRound, conf.newRoundDelay

  getTick: ->
    Math.floor (Date.now() - @startTime) / conf.tickLength

  getActionTick: ->
    @lastActionTick = Math.max @getTick() + conf.physicsDelayTicks, @lastActionTick + 1

  push: (msg, args...) ->
    @pushFrom null, msg, args...

  pushFrom: (user, msg, args...) ->
    @broadcastFrom user, msg, args...
    @his.push [msg, args...] if @running

  broadcast: (msg, args...) ->
    @broadcastFrom null, msg, args...

  broadcastFrom: (user, msg, args...) ->
    for u in @users when u isnt user
      u.socket.emit msg, args...

  toString: ->
    "game #{@id}"

helper.seed Date.now()
game = new Game # just one game for now
guidCounter = 0

io.on 'connection', (socket) ->
  new User socket
  console.log 'new connection established'
