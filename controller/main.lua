-- Main client program for monitoring the space probe

require "config"
require "utils"
if config.spaceprobe_name == "simulation" then
	dofile("probe_sim.lua")
else
	dofile("probe.lua")
end

local est_closing_time = os.time() + translate(get_knob_position(), config.knob_table)*60*60

function main()
	-- make sure we can see the probe before we start up at all
	while get_probe_offline() do
		probe_is_offline()
	end

	-- Determine initial space state (doesn't send any notices during startup)
	space_open = ( get_knob_position() > config.knob_deadband )
	log("Starting with space " .. "open" and space_open or "closed")
	if space_open then log ("Estimated closing " .. os.date(nil, est_closing_time)) end

	if space_open then 
		space_is_open() 
	else 
		space_is_closed() 
	end
end

-- Events all take result of get_knob_position as an argument
events = {}
function events.evt_probe_offline(knob_value) 
	return knob_value == nil and get_probe_offline() 
end

function events.evt_nothing(knob_value) 
	return knob_value == nil and not get_probe_offline() 
end

function events.evt_knob_zero(knob_value) 
	return knob_value != nil and
		knob_value < translate(config.knob_deadband, config.knob_table) 
end

function events.evt_knob_moved_nonzero(knob_value) 
	return knob_value != nil and 
		knob_value > translate(config.knob_deadband, config.knob_table)
end

-- States
states = {}
function states.is_open() end
function states.is_closed() end

-- State transition event handler table

states = {
	{ states.is_open= { 
		  events.evt_knob_zero=space_closing_now,
		  events.evt_knob_moved_nonzero=space_closing_in,
		  events.evt_probe_offline=probe_is_offline,
		  events.evt_nothing=nil
     } 
  },

	{ states.is_closed= {
		  events.evt_knob_zero=nil,
		  events.evt_knob_moved_nonzero=space_closing_in,
		  events.evt_probe_offline=probe_is_offline,
		  events.evt_nothing=nil
	  }
  }
}

knob_hours = nil

function step_fsm(from_state)
	knob_hours = get_knob_movement()

	
end

	  
-- Handler : Probe is offline
function probe_is_offline(state, event)
	log("Probe offline. Waiting for reconnection...")
	while get_probe_offline() do
		sleep(1)
	end
	return step_fsm(state)
end

-- Handler: Space just opened, or opening hours changed
function space_closing_in(state, event)
	was_already_open = state==states.is_open
	est_closing_time = os.time() + knob_hours*60*60	

	set_leds(0,255,0,2000) -- slow green blink
	set_dial(translate(hours, config.dial_table))
	adverb = was_already_open and "still" or "now"
	log("Space is " .. adverb  .. " open, estimated closing time " .. os.date(nil, est_closing_time))

	set_leds(0,0,0,0) -- no LEDs while space is open
	return step_fsm(states.is_open)
end

-- Handler: Space is closing now
function space_closing_now(state, event)
	set_dial(0)
	set_leds(0,255,0,2000) -- slow green blink
	log("Space is now closed")
	set_leds(0,0,0,0) -- done
	return step_fsm(states.is_closed)
end


-- Has the knob's raw position moved legitimately? If so, return new hours shown. If not, return nil.
function get_knob_movement()
	if last_knob_still_pos == nil then
		-- initialise globals for tracking the knob position
		last_knob_still_pos = get_knob_position()
		last_knob_moving_pos = last_knob_still_pos
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