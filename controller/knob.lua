-- Module to wrap the smarts in the "knob"

require "probe"

knob = {}
knob.states = { STILL=nil, MOVING=nil } -- to become function lookup table
knob.state = "STILL"

local last_knob_still_pos = nil
local last_knob_moving_pos = nil
local last_knob_movetime = nil

-- Has the knob moved legitimately? If so, return new hours shown. If not, return nil.
local function get_knob_movement()
	local raw = probe.get_position()
	if(raw ~= nil and raw < config.knob_deadband) then
		raw = 0 -- makes it easy to tell if the knob is back at zero or not
	end

	if last_knob_still_pos == nil then
		-- initialise globals for tracking the knob position
		last_knob_still_pos = raw
		last_knob_moving_pos = last_knob_still_pos
		last_knob_movetime = os.time()
		return nil
	end

	if raw == nil then -- offline
		knob.state = "STILL"
		return nil
	else
		-- call appropriate handler (stored in knob.states table)
		return knob.states[knob.state](raw)
	end
end

-- handle a new raw value when still
local function knob_handle_still(raw)
	if math.abs(raw - last_knob_still_pos) < config.knob_deadband then 	
		return nil -- offline or hasn't moved from last resting spot
	else
		-- check it's not a blip
		raw2 = probe.get_position()
		if raw2 ~= raw then
			return nil -- was an ADC blip
		end
		knob.state = "MOVING"
		probe.fast_green_blink() -- on the move so start blinking
		last_knob_moving_pos = raw
		last_knob_movetime = os.time()		
		return nil
	end	
end

-- handle a new raw value when moving
local function knob_handle_moving(raw)

	-- feedback on the dial in realtime
	probe.set_dial(round(translate(translate(raw, config.knob_table), config.dial_table)))

	if math.abs(raw - last_knob_moving_pos) > config.knob_deadband then		      
		last_knob_moving_pos = raw
		last_knob_movetime = os.time()
		return nil -- still on the move
	end

	if os.time() < last_knob_movetime + config.knob_latency then
		return nil -- hasn't settled for long enough yet
	end 

	-- congrats, movement completed!
	log("Knob has moved to new raw position " .. raw)
	knob.state = "STILL"
	last_knob_moving_pos = raw
	last_knob_still_pos = raw
	return translate(raw, config.knob_table)
end


knob.states = { STILL=knob_handle_still, MOVING=knob_handle_moving }

knob.get_movement = get_knob_movement