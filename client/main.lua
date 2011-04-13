-- Main client program for monitoring the space probe

require "config"
require "utils"
if config.spaceprobe_name == "simulation" then
	dofile("probe_sim.lua")
else
	dofile("probe.lua")
end

-- make sure we can see the probe before we startup at all

function do_probe_offline()
	log("Probe offline. Waiting for reconnection...")
	while get_probe_offline() do
		sleep(1)
	end
end

if get_probe_offline() then 
	do_probe_offline()
end

local space_open = ( get_knob_position() > config.knob_deadband )
local est_closing_time = os.time() + translate(get_knob_position(), config.knob_table)*60*60

function main()
	log("Starting with space " .. "open" and space_open or "closed")
	if space_open then log ("Estimated closing " .. os.date(nil, est_closing_time)) end
	while true do
		if get_probe_offline() then 
			do_probe_offline()
		else
			if space_open then 
				do_space_open() 
			else 
				do_space_closed() end
		end
	end
end


function do_space_open()
	knob_hours = get_knob_movement()
	if knob_hours == nil then
		sleep(1)
		return
	end

	print(knob_hours .." against " .. translate(config.knob_deadband, config.knob_table))
	if knob_hours < translate(config.knob_deadband, config.knob_table) then
		-- space is now closed
		space_open = false
		set_dial(0)
		set_leds(0,255,0,2000) -- slow green blink
		log("Space is now closed")
		set_leds(0,0,0,0) -- done
	else
		-- space is still open, opening time has changed
		do_closing_in(knob_hours, true)
	end
end


function do_space_closed()
	local knob_hours = get_knob_movement()
	if knob_hours == nil or knob_hours < translate(config.knob_deadband, config.knob_table) then
		sleep(1)
		return
	end

	-- Space is open!
	space_open = true
	do_closing_in(knob_hours, false)
end


function do_closing_in(hours, was_already_open)
	est_closing_time = os.time() + hours*60*60	

	set_leds(0,255,0,2000) -- slow green blink
	set_dial(translate(hours, config.dial_table))
	adverb = was_already_open and "still" or "now"
	log("Space is " .. adverb  .. " open, estimated closing time " .. os.date(nil, est_closing_time))

	set_leds(0,0,0,0) -- no LEDs while space is open
end



-- Has the knob's raw position moved legitimately? If so, return new 'hours'
function get_knob_movement()
	if last_knob_still_pos == nil then
		-- initialise globals for tracking the knob position
		last_knob_still_pos = get_knob_position()
		last_knob_moving_pos = get_knob_position()
		last_knob_movetime = os.time()
	end

	raw = get_knob_position()
	if raw == nil or math.abs(raw - last_knob_still_pos) < config.knob_deadband then 	
		return nil -- offline or hasn't moved from last resting spot
	end

	if math.abs(raw - last_knob_moving_pos) > config.knob_deadband then		      
		last_knob_still_pos = -10000 -- even if it goes back where it came from, counts as a move now
		last_knob_moving_pos = raw
		last_knob_movetime = os.time()
		return nil -- still on the move
	end
	
	if os.time() < last_knob_movetime + config.knob_latency then
		return nil -- hasn't settled for long enough yet
	end 

	-- congrats, knob has moved!
	log("Knob has moved to new raw position " .. raw)
	last_knob_moving_pos = raw
	last_knob_still_pos = raw
	return translate(raw, config.knob_table)
end


main()