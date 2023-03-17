-- table that both holds our module and represents our class
local client = {}
local socket = require("socket")
local json = require("cjson")

-- create a new client object
--function client.new()
--  local o = { }
--  setmetatable(o, {__index = client})
--  return o
--end

function client.new(ip, port)
  local sock = socket.tcp()

  -- in a real world driver you'll probably want more reliable connect logic than this
  assert(sock:connect(ip, port))

  local o = { sock = sock, ip = ip, port = port, last_req_id = 0 }
  setmetatable(o, {__index = client})
  return o
end

-- internal function that actually performs the RPC on the network
-- note: by convention, a leading underscore in a name means something internal
function client:_call(method, ...)
  -- new request, new id
  self.last_req_id = self.last_req_id + 1

  -- structure call with a table
  local request = {
    id = self.last_req_id,
    method = method,
    params = {...}
  }

  -- encode the call as a json-formatted string
  local requeststr = assert(json.encode(request))

  -- send our encoded request, terminated by a newline character
  local bytessent, err = self.sock:send(requeststr.."\n")
  assert(bytessent, "failed to send request")
  assert(bytessent == #requeststr + 1, "request only partially sent")

  while true do
    -- by default `receive` reads a line of data, perfect for our protocol
    local line, err = self.sock:receive()
    assert(line, "failed to get response:" .. tostring(err))

    -- decode the response into a lua table
    local resp, cont, err = json.decode(line)
    assert(resp, "failed to parse response")

    if resp.id then
      assert(resp.id == request.id, "unexpected response")

      -- return the result of the call back to the caller
      return table.unpack(resp.result)
    else
      -- a "resp" without an id is a notification, ignore for now
      -- and let the loop take us back around to try again
    end
  end
end

-- `setattr` RPC
--
-- sets attributes on the thing
function client:setattr(attrmap)
  return self:_call("setattr", attrmap)
end

-- `getattr` RPC
--
-- gets the current value of attributes of thing
function client:getattr(attrlist)
  return self:_call("getattr", attrlist)
end

return client
