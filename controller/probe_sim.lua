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
local function get_position()
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
local function get_offline()
	rs = io.open("/tmp/space_probe_knob", "r")
	if rs then
		rs:close()
	end
	return rs == nil
end

local function set_dial(raw_value)
	if raw_value ~= last_dial then
		log("Setting dial to value " .. raw_value)
		last_dial = raw_value
	end
end

local function set_leds(r,g,b,blink_on_time,blink_off_time)
	if blink_on_time == nil or blink_off_time == nil then
		blink_on_time = 1 -- constant duty
		blink_off_time = 0
	end
	if last_r ~= r or last_g ~= g or last_b ~= b or last_bon ~= blink_on_time or last_boff ~= blink_off_time then
		msg = string.format("Setting LEDS %d %d %d w/ blink cycle %d/%dms",
								  r,g,b,blink_on_time,blink_on_time,blink_on_time+blink_off_time)
		log(msg)
		last_r = r
		last_g = g
		last_b = b
		last_bon = blink_on_time
		last_boff = blink_off_time
	end
end

local function buzz(seconds)
	log("Buzzing for " .. seconds .. " seconds")
end


probe.get_position=get_position
probe.get_offline=get_offline
probe.set_dial=set_dial
probe.set_leds=set_leds
probe.buzz=buzz
probe.ping=get_offline
