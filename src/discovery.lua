local socket = require "socket"
local log = require "log"

local SEARCH_RESPONSE_WAIT = 2 -- seconds, max time devices will wait before responding

--------------------------------------------------------------------------------------------
-- ThingSim device discovery
--------------------------------------------------------------------------------------------

local looking_for_all = setmetatable({}, {__index = function() return true end})

local function process_response(val)
  local info = {}
  val = string.gsub(val, "HTTP/1.1 200 OK\r\n", "", 1)
  for k, v in string.gmatch(val, "([%g]+): ([%g ]*)\r\n") do
    info[string.lower(k)] = v
  end
  return info
end

local function device_discovery_metadata_generator(thing_ids, callback)
  local looking_for = {}
  local number_looking_for
  local number_found = 0
  if thing_ids ~= nil then
    number_looking_for = #thing_ids
    for _, id in ipairs(thing_ids) do looking_for[id] = true end
  else
    looking_for = looking_for_all
    number_looking_for = math.maxinteger
  end

  local s = socket.udp()
  assert(s)
  local listen_ip = interface or "0.0.0.0"
  local listen_port = 0

  local multicast_ip = "239.255.255.250"
  local multicast_port = 1900
  local multicast_msg =
  'M-SEARCH * HTTP/1.1\r\n' ..
  'HOST: 239.255.255.250:1982\r\n' ..
  'MAN: "ssdp:discover"\r\n' ..
  'MX: '..SEARCH_RESPONSE_WAIT..'\r\n' ..
  'ST: urn:smartthings-com:device:thingsim:1\r\n'

  -- Create bind local ip and port
  -- simulator will unicast back to this ip and port
  assert(s:setsockname(listen_ip, listen_port))
  -- add a second to timeout to account for network & processing latency
  local timeouttime = socket.gettime() + SEARCH_RESPONSE_WAIT + 1
  s:settimeout(SEARCH_RESPONSE_WAIT + 1)

  local ids_found = {} -- used to filter duplicates
  assert(s:sendto(multicast_msg, multicast_ip, multicast_port))
  while number_found < number_looking_for do
    local time_remaining = math.max(0, timeouttime-socket.gettime())
    s:settimeout(time_remaining)
    local val, rip, rport = s:receivefrom()
    if val then
      log.trace(val)
      local headers = process_response(val)
      local ip, port = headers["location"]:match("http://([^,]+):([^/]+)")
      local rpcip, rpcport = (headers["rpc.smartthings.com"] or ""):match("rpc://([^,]+):([^/]+)")
      local httpip, httpport = (headers["http.smartthings.com"] or ""):match("http://([^,]+):([^/]+)")
      local id = headers["usn"]:match("uuid:([^:]+)")
      local name = headers["name.smartthings.com"]

      if rip ~= ip then
        log.warn("received discovery response with reported & source IP mismatch, ignoring")
      elseif ip and port and id and looking_for[id] and not ids_found[id] then
        ids_found[id] = true
              number_found = number_found + 1
        callback({id = id, ip = ip, port = port, rpcport = rpcport, httpport = httpport, name = name})
      else
        log.debug("found device not looking for:", id)
      end
    elseif rip == "timeout" then
      return nil
    else
      error(string.format("error receiving discovery replies: %s", rip))
    end
  end
end

local function find_cb(thing_ids, cb)
  device_discovery_metadata_generator(thing_ids, cb)
end

local function find(thing_ids)
  local thingsmeta = {}
  local function cb(metadata) table.insert(thingsmeta, metadata) end
  find_cb(thing_ids, cb)
  return thingsmeta
end


return {
  find = find,
  find_cb = find_cb,
}
