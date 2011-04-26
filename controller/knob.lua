-- Module to wrap the smarts in the "knob"

require "probe"

knob = {}

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
	end

	if raw == nil or math.abs(raw - last_knob_still_pos) < config.knob_deadband then 	
		return nil -- offline or hasn't moved from last resting spot
	end

	probe.fast_green_blink() -- on the move so start blinking

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


knob.get_movement = get_knob_movement