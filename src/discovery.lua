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

local function send_disco_request()
  local listen_ip = "0.0.0.0"
  local listen_port = 0
  local multicast_ip = "239.255.255.250"
  local multicast_port = 1900
  local multicast_msg = table.concat(
    {
      'M-SEARCH * HTTP/1.1',
      'HOST: 239.255.255.250:1900',
      'MAN: "ssdp:discover"',
      'MX: 4',
      'ST: urn:Belkin:device:*',
      '\r\n'
    },
    "\r\n"
  )
  local sock = assert(socket.udp(), "create discovery socket")
  assert(sock:setsockname(listen_ip, listen_port), "disco| socket setsockname")
  local timeouttime = socket.gettime() + 5 -- 5 second timeout, `MX` + 1 for network delay
  assert(sock:sendto(multicast_msg, multicast_ip, multicast_port))
  return sock, timeouttime
end

local function process_response(val)
  local info = {}
  val = string.gsub(val, "HTTP/1.1 200 OK\r\n", "", 1)
  for k, v in string.gmatch(val, "([%g]+): ([%g ]*)\r\n") do
    info[string.lower(k)] = v
  end
  return info
end

function Discovery.fetch_device_metadata(url)
  -- Wemo responds with chunked encoding, must use ltn12 sink
  local responsechunks = {}
  local _, status, _ = http.request {
    url = url,
    sink = ltn12.sink.table(responsechunks),
  }

  local response = table.concat(responsechunks)

  -- errors are coming back as literal string "[string "socket"]:1239: closed"
  -- instead of just "closed", so do a `find` for the error
  if string.find(status, "closed") then
    log.debug("disco| ignoring unexpected socket close during metadata fetch, try parsing anyway")
    -- this workaround is required because wemo doesn't send the required zero-length chunk
    -- at the end of it `Text-Encoding: Chunked` HTTP message, it just closes the socket,
    -- so ignore closed errors
  elseif status ~= 200 then
    log.error("disco| metadata request failed (" .. tostring(status) .. ")\n" .. response)
    return nil, "request failed: " .. tostring(status)
  end

  local handler = xml_handler:new()
  local xml_parser = xml2lua.parser(handler)
  xml_parser:parse(response)

  if not handler.root then
    log.error("disco| unable to parse device metadata as xml")
    return nil, "xml parse error"
  end

  local parsed_xml = handler.root

  -- check if we parsed a <root> element
  if not parsed_xml.root then
    return nil
  end

  return {
    name = tablefind(parsed_xml, "root.device.friendlyName"),
    model = tablefind(parsed_xml, "root.device.modelName"),
    mac = tablefind(parsed_xml, "root.device.macAddress"),
    serial_num = tablefind(parsed_xml, "root.device.serialNumber"),
  }
end

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
