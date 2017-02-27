do ->
  tickLength = 1000 / 60

  base1 = [147, 161, 161]
  base01 = [88, 110, 117]
  base00 = [101, 123, 131]
  base02 = [7, 54, 66]

  conf =
    tickLength: tickLength
    timeStep: tickLength / 1000
    extraPing: 0
    heartbeatInterval: 100
    maxNameLength: 20
    maxUsers: 8
    ping:
      interval: 5000
      tries: 3
      delay: 200
    respawnDelay: 2000
    roundTicks: Math.round (5 * 60000 + 2000) / tickLength
    newRoundDelay: 10000
    diffGhostDelay: true
    extraGhostDelay: 20
    sendPosInterval: Math.round 50 / tickLength
    sendWorldStateInterval: Math.round 10000 / tickLength
    spawnRetryInterval: Math.round 500 / tickLength
    physicsDelayTicks: Math.round 1000 / tickLength
    debugMode: false
    debugEmits: false

    friction:
      wall: .3
      box: .3
      disc: .3
      ragdoll: .3
    restitution:
      wall: .1
      box: .2
      disc: .7
      ragdoll: .2
    gravity: 15
    deadlyVelocity: 2
    terminalVelocity: 20
    terminalDragFactor: .99
    dieImpulse:
      factor: .5
      min: 3
    grabRange: .5
    user:
      w: .75
      h: 1.2
    walk:
      speed: (v = 9)
      accel: Infinity # v / .1
      decel: Infinity # v / .05
    userTerminalVelocity: (v = 20)
    userGravity: v / .65
    jumpVelocity: 17
    contactEpsilon: .05
    ragdollLifetime: 3000

    group:
      ragdolls: -1
    category:
      wall: 1
      obj: 2
      user: 4

    godMode: false

    color:
      obj:
        fill: base1
        stroke: base01
      deadlyObj:
        fill: base1
        stroke: [0, 0, 0]
      wall:
        fill: base00
        stroke: base02
      users: [[181, 137, 0], [108, 113, 196], [203, 75, 22], [38, 139, 210], [220, 50, 47], [42, 161, 152], [211, 54, 130], [133, 153, 0]]
      sniper: [0, 0, 0]
      faintLaser: [0, 0, 0]
    alpha:
      ghost: .5
      ghostObj: .25
      faintObj: .1
      laser: .25
      faintLaser: .15
      faintSniper: .1
      deadUser: .25
    focusFactor: .2
    killMsgTimeout: 4000
    laserThickness: .1
    logMsgTimeout: 10000
    maxSimulationTime: 1000
    viewWidth: 45
    strokeBrightness: .5
    switchTargetDelay: 1000
    updateScoreTableInterval: 1000
    activeDuration: 50

    keys:
      left: [65, 37]
      right: [68, 39]
      down: [83, 40]
      jump: [87, 38]
      grab: [69]
      chat: [89, 13]
      toggleScore: [32]
      debugKey: [83, 40]
      quit: [46]
      changeName: [78]
      switchGun: [48, 49, 50, 51, 52, 53, 54, 55, 56, 57]

    fireOffset: x: 0, y: -.4
    lethalLaserImpulse: 15
    launcher:
      slot: 2
      impulse: 15
      reloadTicks: Math.round 100 / tickLength
      spawnAmmo: null
    autoLauncher:
      slot: 6
      impulse: 20
      reloadTicks: Math.round 100 / tickLength
      salvoDelayTicks: Math.round 300 / tickLength
      ammo: 2
      salvos: 1
      box:
        w: 1.2 * 1.2
        h: .75 * 1.2
      shouldLaunchDiscs: true
      spawnAmmo: 2
    laser:
      slot: 1
      impulse: 15
      altImpulse: -5
      reloadTicks: Math.round 500 / tickLength
      isLethal: true
      range: 30
      spawnAmmo: Infinity
    sniper:
      slot: 7
      range: 30
      reloadTicks: Math.round 300 / tickLength
      spawnAmmo: Infinity

    swappingGunTicks: Math.round 200 / tickLength

    msg:
      lag: 'Waiting for response from server...'
      joining: 'Joining game...'
    autoStart: true

  if exports? then module.exports = conf else define -> conf
