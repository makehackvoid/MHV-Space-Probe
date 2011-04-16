-- Module for interacting with a simulated probe
--
-- Knob value is set by writing a file /tmp/space_probe_knob
--
-- Valid values are 0-1023
--
-- ie
-- $ echo 432 > /tmp/space_probe_knob


-- Return knob raw position as a number, nil if the
-- probe is offline (in this case, if the file is missing)
function get_knob_position()
	local f = io.open("/tmp/space_probe_knob", "r")
	if f == nil then
		return nil
	end
	local v = tonumber(f:read("*all"))
	f:close()	
	if v == nil then
		return 0
	end
	return math.max(0, math.min(1023, v))
end

-- Test if the probe is offline. Makes an attempt to reconnect
-- if it is.
function get_probe_offline()
	return io.open("/tmp/space_probe_knob", "r") == nil
end

function set_dial(raw_value)
	print("Setting dial to value " .. raw_value)
end

function set_leds(r,g,b,blink_time)
	msg = string.format("Setting LEDS %d %d %d w/ blink delay %dms",
							  r,g,b,blink_time)
	print(msg)
end



