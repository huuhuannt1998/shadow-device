local socket = require("socket")

-- Create a TCP socket and bind it to a port
local server = socket.tcp()
server:setoption("reuseaddr", true)
server:bind("*", 8080)
server:listen(1)

-- Accept connections and respond to HTTP requests
while true do
  -- Accept a new connection
  local client, err = server:accept()
  if not client then
    print("Error accepting connection: " .. err)
    break
  end

  -- Read the HTTP request from the client
  local request = client:receive("*a")
  print("Received HTTP request:\n" .. request)

  -- Send an HTTP response to the client
  local response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello"
  local ok, err = client:send(response)
  if not ok then
    print("Error sending HTTP response: " .. err)
  end

  -- Close the client socket
  client:close()
end

-- Close the server socket
server:close()
