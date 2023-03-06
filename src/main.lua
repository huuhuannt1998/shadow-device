local http_export = require("http-export")

-- Export an HTTP connection and print the response
local ip_address = "192.168.1.124"
local port = 443
local http_request = "GET / HTTP/1.1\r\nHost: 192.168.1.124\r\n\r\n"

-- Using assert
local response = assert(http_export.export_http_connection(ip_address, port, http_request), "Error exporting HTTP connection")
print(response)

-- Using a conditional statement
local response, err = http_export.export_http_connection(ip_address, port, http_request)
if response then
  print(response)
else
  print("Error exporting HTTP connection: " .. err)
end
