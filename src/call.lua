local client = require "rpcclient"
local discovery = require "discovery"

-- no filter, find all devices
local things = discovery.find()

-- Loop over all devices found and turn them off
for _,thing in pairs(things) do
  local c = client.new(thing.ip, thing.rpcport)

  print((c:setattr{power = "on"}))
end
