set res=false
if not exist server.js set res=true
if not exist public/scripts/config.js set res=true
if not exist public/scripts/helper.js set res=true
if "%res%"=="true" call coffee --bare --compile server.coffee public/scripts/
start coffee --bare --compile --watch server.coffee public/scripts/
supervisor --watch server.js,public/scripts/config.js,public/scripts/helper.js --no-restart-on exit server.js
