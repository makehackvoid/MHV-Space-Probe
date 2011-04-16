-- Main client program for monitoring the space probe

require "config"
require "utils"
require "probe"
require "knob"

function startup()
	-- make sure we can see the probe before we start up at all
	check_probe_connection()

	-- Determine initial space state (doesn't send any notices during startup)
	local pos = probe.get_position()
	local space_open = ( pos > config.knob_deadband )
	log("Starting with space " .. "open" and space_open or "closed")

	-- Kick off with our initial state
	if space_open then 
		est_closing_time = os.time() + translate(pos, config.knob_table)*60*60
		log("Estimated closing " .. os.date(nil, est_closing_time))
		return space_is_open() 
	else 
		return space_is_closed() 
	end
end
	  
-- State
function space_is_open()
	check_probe_connection()

	local hours = knob.get_movement()
	if hours == 0 then
		-- Space just closed
		space_closing_now()
		return space_is_closed()
	elseif hours ~= nil then
		-- Dial moved to a different non-zero number
		space_closing_in(hours, true)
	end
	
	if os.time() > est_closing_time and warnings < 4 then -- est. closing is now
		log("Due to close now!!!")
		probe.buzz(15)
		probe.slow_blue_blink(100)
		warnings = 4
	elseif os.time() + 1*60 > est_closing_time and warnings < 3 then -- 1 minute to est. closing
		log("1 minute to estimated closing...")
		probe.buzz(10)
		probe.slow_blue_blink(300)
		warnings = 3
	elseif os.time() + 5*60 > est_closing_time and warnings < 2 then -- 5 minutes to est. closing
		log("5 minutes to estimated closing...")
		probe.buzz(5)
		probe.slow_blue_blink(1000)
		warnings = 2
	elseif os.time() + 30*60 > est_closing_time and warnings < 1 then -- 30 minutes to est. closing
		log("30 minutes to estimated closing...")
		probe.buzz(2)
		probe.slow_blue_blink(3000)
		warnings = 1
	end

	return space_is_open()
end

-- State
function space_is_closed()
	check_probe_connection()

	local hours = knob.get_movement()
	if hours ~= nil and hours > 0 then
		-- Space just opened
		space_closing_in(hours, false)
		return space_is_open()
	end
	return space_is_closed()
end


function check_probe_connection()
	if probe.get_offline() then
		log("Probe offline. Waiting for reconnection...")
		while probe.get_offline() do
			sleep(1)
		end
	end
end

-- Space just opened, or opening hours changed
function space_closing_in(hours, was_already_open)
	est_closing_time = os.time() + hours*60*60	

	probe.slow_green_blink()
	probe.set_dial(translate(hours, config.dial_table))
	adverb = was_already_open and "still" or "now"
	log("Space is " .. adverb  .. " open, estimated closing time " .. os.date(nil, est_closing_time))
	probe.leds_off()
	warnings = 0
	return space_is_open()
end

-- Space is closing now
function space_closing_now()
	probe.set_dial(0)
	probe.slow_green_blink()
	log("Space is now closed")
	probe.leds_off()
	return space_is_closed()
end

return startup()