# boxmp
Two-dimensional multiplayer game with physics. Each client runs its own physics simulation. Latency between client and server has no impact on the simulation. This is achieved by adding a one second delay to user actions that impact the physics world. During this delay the action is sent to all clients. The delay makes it possible for each client to keep its simulation running and not miss any significant actions as long as the last received message from the server is less than a second old.

Not all actions have a delay, as that would make the game very hard to play. Only actions that affect the physics world need a delay. At the moment these are firing and grabbing an object. Player movement has no delay. Hence, there can be no pushing or pulling of objects. Collisions between the player and objects in the physics world are resolved as if the player has zero mass. The player just gets pushed around without affecting the movement of these objects.

Play the game at [http://www.gomoku-ai.ewps.nl](http://www.gomoku-ai.ewps.nl).

## Goal
Try to make the most kills before the round ends.

## Controls
- **Left mouse button:** Fire
- **Right mouse button:** Alternative Fire
- **A/D:** Move left/right
- **W:** Jump (you can also double jump: press the key again while in the air)
- **1:** Switch weapon: Gravity Laser
- **2:** Switch weapon: Throw Gun (needs ammo)
- **E:** Grab closest object (gives ammo for Throw Gun)
- **N:** Change name
- **Enter:** Chat
- **Space:** Toggle score overlay
- **Delete:** Disconnect

## Build process
- Install Node.js.
- Run `npm install`.
- Start the server with `npm start`.
- Open your browser and navigate to [http://localhost:7683](http://localhost:7683).

Optionally, if you want the server to automatically restart when there are changes, you can follow the following steps:

- Install CoffeeScript `npm install --global coffee-script`.
- Install node-supervisor `npm install --global supervisor`.
- Run `start-and-watch.bat` or `./start-and-watch`, depending on your platform.

## Synchronization issues
At the moment it is possible that the physics simulations of the clients become out of sync. This is detected by the server and a message is sent to all clients.

It happens when the JavaScript engines of the clients produce different outputs for the same input. There has been an attempt to reduce this problem by rounding the return values of calls to `Math.sin`, `Math.cos`, `Math.asin` and the like. To completely solve this issue it must be possible for the clients to synchronize their state.

## Cheat protection
As of yet there is no cheat protection. This makes the development of the game a lot easier. Also some gameplay elements are only possible if the clients can be trusted. 

## Special thanks
- [Box2D](http://box2d.org/) for the physics engine
- [socket.io](http://socket.io/) for the server-client communication
