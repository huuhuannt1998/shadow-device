local log = require "log"
local capabilities = require "st.capabilities"

local command_handlers = {}

-- callback to handle an `on` capability command
function command_handlers.switch_on(driver, device, command)
  log.debug(string.format("[%s] calling set_power(on)", device.device_network_id))
  device:emit_event(capabilities.switch.switch.on())
  local cosock = require "cosock"
  -- `cosock.asyncify` works like `require` but swaps out any sockets
  -- created to be cosock sockets. This is important because we
  -- are running inside of a command handler. 
  local http = cosock.asyncify "socket.http"
  -- ltn12 is a module provided by luasocket for interacting with
  -- data streams, we need to use a "source" to populate a request
  -- body and a "sink" to extract a response body
  local ltn12 = require "ltn12"

  local ip = device.ip -- found previously via discovery
  local port = device.port -- found previously via discovery

  local url = string.format("http://%s:%s/switch", ip, port)
  local body
  for i=1,3 do
    local body_t = {}
    -- performs a POST because body parameter is passed
    local success, code, headers, status = http.request({
      url = url,
      -- the `string` source will fill in our request body
      source = ltn12.source.string("on"),
      -- The `table` sink will add a string to a list table
      -- for every chunk of the request body
      sink = ltn12.sink.table(body_t),
      -- The create function allows for overriding default socket
      -- used for request. Here we are setting a timeout to 5 seconds
      create = function()
        local sock = cosock.socket.tcp()
        sock:settimeout(5)
        return sock
      end,
    })

    if not success and code ~= "timeout" then
      local err = code -- in error case second param is error message

      error(string.format("error while setting switch status for %s: %s",
                          device.name,
                          err))
     elseif code ~= 200 then
       error(string.format("unexpected HTTP error response from %s: %s",
                           device.name,
                           status))
    elseif code == 200 then
      body = table.concat(body_t)
      break
    end

    -- loop if timeout
  end
end

-- callback to handle an `off` capability command
function command_handlers.switch_off(driver, device, command)
  log.debug(string.format("[%s] calling set_power(off)", device.device_network_id))
  device:emit_event(capabilities.switch.switch.off())
end

return command_handlers
