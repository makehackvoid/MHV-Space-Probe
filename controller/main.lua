-- Main client program for monitoring the space probe

require "config"
require "utils"
if config.spaceprobe_name == "simulation" then
	dofile("probe_sim.lua")
else
	dofile("probe.lua")
end

function startup()
	-- make sure we can see the probe before we start up at all
	check_probe_connection()

	-- Determine initial space state (doesn't send any notices during startup)
	local pos = get_knob_position()
	local space_open = ( pos > config.knob_deadband )
	log("Starting with space " .. "open" and space_open or "closed")

	-- Kick off with our initial state
	if space_open then 
		est_closing_time = os.time() + translate(pos, config.knob_table)*60*60
		log("Estimated closing " .. os.date(nil, est_closing_time)) end
		return space_is_open() 
	else 
		return space_is_closed() 
	end
end
	  
-- State
function space_is_open()
	check_probe_connection()

	local hours = get_knob_movement()
	if hours == 0 then
		-- Space just closed
		space_closing_now()
		return space_is_closed()
	elseif hours ~= nil then
		-- Dial moved to a different non-zero number
		space_closing_in(hours, true)
	end
	return space_is_open()
end

-- State
function space_is_closed()
	check_probe_connection()

	local hours = get_knob_movement()
	if hours > 0 then
		-- Space just opened
		space_closing_in(hours, false)
		return space_is_open()
	end
	return space_is_closed()
end


function check_probe_connection()
	if get_probe_offline() then
		log("Probe offline. Waiting for reconnection...")
		while get_probe_offline() do
			sleep(1)
		end
	end
end

-- Space just opened, or opening hours changed
function space_closing_in(hours, was_already_open)
	est_closing_time = os.time() + hours*60*60	

	set_leds(0,255,0,2000) -- slow green blink
	set_dial(translate(hours, config.dial_table))
	adverb = was_already_open and "still" or "now"
	log("Space is " .. adverb  .. " open, estimated closing time " .. os.date(nil, est_closing_time))
	set_leds(0,0,0,0) -- no LEDs while space is open
	return space_is_open()
end

-- Space is closing now
function space_closing_now()
	set_dial(0)
	set_leds(0,255,0,2000) -- slow green blink
	log("Space is now closed")
	set_leds(0,0,0,0) -- done
	return space_is_closed()
end



-- Has the knob moved legitimately? If so, return new hours shown. If not, return nil.
function get_knob_movement()
	local raw = get_knob_position()
	if(raw ~= nil and raw < config.knob_deadband) then
		raw = 0
	end

	if last_knob_still_pos == nil then
		-- initialise globals for tracking the knob position
		last_knob_still_pos = raw
		last_knob_moving_pos = last_knob_still_pos
		last_knob_movetime = os.time()
	end

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


startup()