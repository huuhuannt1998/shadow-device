local socket = require("socket")

local function export_http_connection(ip_address, port, http_request)
  -- Create a TCP socket
  local client = socket.tcp()

  -- Connect to the smart hub
  local ok, err = client:connect(ip_address, port)
  if not ok then
    client:close()
    return nil, "Error connecting to smart hub: " .. err
  end

  -- Send an HTTP request to the smart hub
  local ok, err = client:send(http_request)
  if not ok then
    client:close()
    return nil, "Error sending HTTP request: " .. err
  end

  -- Receive the response from the smart hub
  local response, err, partial = client:receive("*a")
  if not response and partial then
    response = partial
  elseif not response then
    client:close()
    return nil, "Error receiving HTTP response: " .. err
  end

  -- Close the socket
  client:close()

  -- Return the response data
  return response
end

return {
  export_http_connection = export_http_connection
}
