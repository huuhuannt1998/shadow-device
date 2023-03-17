-- init.lua
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

-- search network for specific thing using custom discovery library
local function find_thing(id)
  -- use our discovery function to find all of our devices
  local things = discovery.find({id})
  if not things then
    -- return early if discovery fails
    return nil
  end
  -- return the first entry in our things list
  return table.remove(thing_ids)
end

-- get an rpc client for thing if thing is reachable on the network
local function get_thing_client(device)
  local thingclient = device:get_field("client")

  if not thingclient then
    local thing = find_thing(device.device_network_id)
    if thing then
      thingclient = client.new(thing.ip, thing.rpcport)
      device:set_field("client", thingclient)

      -- tell device health to mark device online so users can control
      device:online()
    end
  end

  if not thingclient then
    -- tell device health to mark device offline so users will see that it
    -- can't currently be controlled
    device:offline()
    return nil, "unable to reach thing"
  end

  return thingclient
end

-- handle setup for newly added devices (before device_init)
local function device_added(driver, device)
  log.info("[" .. tostring(device.id) .. "] New ThingSim RPC Client device added")
end

-- initialize device at startup or when added
local function device_init(driver, device)
  log.info("[" .. tostring(device.id) .. "] Initializing ThingSim RPC Client device")

  local client = get_thing_client(device)

  if client then
    log.info("Connected")

    -- get current state and emit in case it has changed
    local attrs = client:getattr({"power"})
    if attrs and attrs.power == "on" then
      device:emit_event(capabilities.switch.switch.on())
    else
      device:emit_event(capabilities.switch.switch.off())
    end
  else
    log.warn(
      "Device not found at initial discovery (no async events until controlled)",
      device:get_field("name") or device.device_network_id
    )
  end
end


local function handle_on(driver, device, command)
  log.info("switch on", device.id)

  local client = assert(get_thing_client(device))
  if client:setattr{power = "on"} then
    device:emit_event(capabilities.switch.switch.on())
  else
    log.error("failed to set power on")
  end
end

local function handle_off(driver, device, command)
  log.info("switch off", device.id)

  local client = assert(get_thing_client(device))
  if client:setattr{power = "off"} then
    device:emit_event(capabilities.switch.switch.off())
  else
    log.error("failed to set power on")
  end
end



-- Driver library initialization
local example_driver =
  Driver("example_driver",
    {
      lifecycle_handlers = {
        added = device_added,
        init = device_init,
      },
      capability_handlers = {
        [capabilities.switch.ID] = {
          [capabilities.switch.commands.on.NAME] = handle_on,
          [capabilities.switch.commands.off.NAME] = handle_off
        }
      }
    }
  )



example_driver:run()
