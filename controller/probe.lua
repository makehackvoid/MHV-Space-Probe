-- Module for interacting with the probe itself

require "config"
require "posix"
local http = require("socket.http")

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

local function probe_request(url, postdata)
   -- postdata can be nil, indicating a GET
   b, c, h = http.request("http://" .. config.spaceprobe_name .. url, postdata)
   if b == nil then
      log("Request failed. Probe offline? Error was " .. c)
      return nil
   elseif c ~= 200 then
      log("Probe refused request! Response was " .. b)
      return nil
   else
      return b
   end
end

local function get_offline()
   rsp = probe_request("/is_alive")
   return rsp ~= "OK"
end

local function set_dial(raw_value)
   return probe_request("/dial",
                        string.format("%04d", raw_value))
end

local function set_leds(r,g,b,blink_on_time,blink_off_time)
   return probe_request("/leds",
                        string.format("%04d,%04d,%04d,%04d,%04d",r,g,b,blink_on_time or 1,blink_off_time or 0))
end

local function buzz(seconds)
   return probe_request(
      "/buzz",
      string.format("%04d", seconds*1000))
end

local last_position = nil

local function get_position()
   res = tonumber(probe_request("/knob"))
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


