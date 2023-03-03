-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

-- require custom handlers from driver package
local command_handlers = require "command_handlers"
local discovery = require "discovery"
local protocol = require "protocol"

-----------------------------------------------------------------
-- local functions
-----------------------------------------------------------------
-- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new Test device")

  -- set a default or queried state for each capability attribute
  device:emit_event(capabilities.switch.switch.on())
end

-- this is called both when a device is added (but after `added`) and after a hub reboots.
local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Test device")

  -- mark device as online so it can be controlled from the app
  device:online()
end

-- this is called when a device is removed by the cloud and synchronized down to the hub
local function device_removed(driver, device)
  log.info("[" .. device.id .. "] Removing Test device")
end

-- create the driver object
local test_device_driver = Driver("testdevice", {
  discovery = discovery.handle_discovery,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    removed = device_removed
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = command_handlers.switch_on,
      [capabilities.switch.commands.off.NAME] = command_handlers.switch_off,
    },
  }
})

-- run the driver
test_device_driver:run()
