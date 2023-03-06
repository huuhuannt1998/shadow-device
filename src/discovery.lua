local log = require "log"
local cosock = require "cosock"
local socket = require "cosock.socket"
local http = cosock.asyncify "socket.http"
local ltn12 = require "ltn12"
local log = require "log"
local tablefind = require "util".tablefind
local mac_equal = require "util".mac_equal
local utils = require "st.utils"
local xml2lua = require "xml2lua"
local xml_handler = require "xmlhandler.tree"

local ControlMessageTypes = {
  Scan = "scan",
  FindDevice = "findDevice",
}

local ControlMessageBuilders = {
  Scan = function(reply_tx) return { type = ControlMessageTypes.Scan, reply_tx = reply_tx } end,
  FindDevice = function(device_id, reply_tx)
    return { type = ControlMessageTypes.FindDevice, device_id = device_id, reply_tx = reply_tx }
  end,
}

local discovery = {}

-- handle discovery events, normally you'd try to discover devices on your
-- network in a loop until calling `should_continue()` returns false.
function discovery.handle_discovery(driver, _should_continue)
  log.info("Starting Test-device Discovery")

  local metadata = {
    type = "LAN",
    -- the DNI must be unique across your hub, using static ID here so that we
    -- only ever have a single instance of this "device"
    device_network_id = "Test device",
    label = "Test Device",
    profile = "test-device.v1",
    manufacturer = "SmartThings",
    model = "v1",
    vendor_provided_label = nil
  }

  -- tell the cloud to create a new device record, will get synced back down
  -- and `device_added` and `device_init` callbacks will be called
  driver:try_create_device(metadata)
end

return discovery
