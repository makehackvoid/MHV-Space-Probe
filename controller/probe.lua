-- Module for interacting with the probe itself

require "config"
require "posix"
local sockets = require("socket")

probe = {}

-- some common utility functions
probe.leds_off = function() probe.set_leds(0,0,0) end
probe.green_glow = function() probe.set_leds(0,30,0) end
probe.fast_green_blink = function() probe.set_leds(0,255,0,50,100) end
probe.fast_red_blink = function() probe.set_leds(255,0,0,200,200) end
probe.slow_blue_blink = function(off_time) probe.set_leds(0,0,255,200,off_time) end


if config.spaceprobe_name == "simulation" then
	-- shortcut the probe_sim module in its place
	dofile("probe_sim.lua")
	return
end

-- real probe functions follow


local function send_command(cmd)
	--log("Sending command " .. cmd)

	if not (ttyr and ttyw) then
		ttyr = io.open("/dev/" .. config.spaceprobe_name, "r")
		ttyw = io.open("/dev/" .. config.spaceprobe_name, "w")
		if not (ttyr and ttyw) then
			log("Failed to open /dev/" .. config.spaceprobe_name .. ". Not configured?")
			return nil
		end
		ttyr:setvbuf("no")
		ttyw:setvbuf("no")

		-- flush any pending data that was left over in a buffer
		while posix.rpoll(ttyr,0) == 1 do
			ttyr:read(1)
		end
	end

	ttyw:write(cmd .. "\n")
	ttyw:flush()

	local res = nil
	if posix.rpoll(ttyr,2000) == 1 then -- 2 second response timeout
		res = ttyr:read("*line")
		ttyr:flush()
	end

	if res then
		res = res:gsub("[^%w]*", "")
		--log("Got response " .. res)
	else
		log("Read timed out, device not available (command was " .. cmd .. ")")
		ttyr:close()
		ttyw:close()
		ttyr = nil
		ttyw = nil
	end

	return res
end

local function get_offline()
	rsp = send_command("P") -- ping!
	return (not rsp) or rsp ~= "OK"
end

local function set_dial(raw_value)
	return send_command(string.format("D%04d", raw_value))
end

local function set_leds(r,g,b,blink_on_time,blink_off_time)
	return send_command(string.format("L%04d,%04d,%04d,%04d,%04d",r,g,b,blink_on_time or 1,blink_off_time or 0))
end

local function buzz(seconds)
	return send_command(string.format("B%04d", seconds*1000))
end

local last_position = nil

local function get_position()
	res = tonumber(send_command("K"))
	if res and (res >= 1014) then 
		return last_position -- our probe has a bug where 0 and 1014 are interchangeable, so ignore any 1014s
	end
	if res then
		last_position = res
	end
	return res
end

probe.get_position=get_position
probe.ping=get_offline
probe.get_offline=get_offline
probe.set_dial=set_dial
probe.set_leds=set_leds
probe.buzz=buzz


