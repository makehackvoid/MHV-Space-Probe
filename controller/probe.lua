-- Module for interacting with the probe itself

require "config"

probe = {}

-- some common utility functions
probe.leds_off = function() probe.set_leds(0,0,0) end
probe.slow_green_blink = function() probe.set_leds(0,255,0,1000,2000) end
probe.fast_red_blink   = function() probe.set_leds(255,0,0,200,200) end
probe.slow_blue_blink = function(off_time) print(off_time) probe.set_leds(0,0,255,200,off_time) end


if config.spaceprobe_name == "simulation" then
	-- shortcut the probe_sim module in its place
	dofile("probe_sim.lua")
	return
end


-- real probe functions follow



