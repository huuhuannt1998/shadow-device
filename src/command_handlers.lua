local log = require "log"
local capabilities = require "st.capabilities"
local protocol = require "protocol"

local command_handlers = {}

-- -- callback to handle an `on` capability command
-- function command_handlers.switch_on(driver, device, command)
--   log.debug(string.format("[%s] calling set_power(on)", device.device_network_id))
--   device:emit_event(capabilities.switch.switch.on())
-- end

-- -- callback to handle an `off` capability command
-- function command_handlers.switch_off(driver, device, command)
--   log.debug(string.format("[%s] calling set_power(off)", device.device_network_id))
--   device:emit_event(capabilities.switch.switch.off())
-- end

function command_handlers.handle_switch_on(driver, device)
  protocol.send_switch_cmd(device, true)
end

function command_handlers.handle_switch_off(driver, device)
  protocol.send_switch_cmd(device, false)
end

function command_handlers.handle_set_level(driver, device, command)
  protocol.send_switch_level_cmd(device, command.args.level)
end

function command_handlers.handle_refresh(driver, device)
  protocol.poll(device)
  if driver.server then
    driver.server:subscribe(device)
  end
end

return command_handlers
