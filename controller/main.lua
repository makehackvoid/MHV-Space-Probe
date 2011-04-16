-- Main client program for monitoring the space probe

-- Requirents:
-- lua 5.1 or newer
-- lwitter, easily installed via luarocks as "luarocks install twitter"

require "config"
require "utils"
require "probe"
require "knob"
require "bbl-twitter"

twitter_client = client(config.oauth_consumer_key, config.oauth_consumer_secret, 
								config.oauth_access_key, config.oauth_access_secret)

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
	  
warnings = 0

-- State
function space_is_open()
	check_probe_connection()
	sleep(1)

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
	sleep(1)

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
	log("Estimated closing " .. os.date(nil, est_closing_time))

	probe.set_dial(translate(hours, config.dial_table))
	local prep = was_already_open and "will remain" or "is now"
	local adverb = was_already_open and "another" or "" 
	local msg = string.format("The MHV space %s open for approximately %s %s", prep, adverb, hours_rounded(hours))
	update_world(msg)

	warnings = 0
	return space_is_open()
end

-- Space is closing now
function space_closing_now()
	probe.set_dial(0)
	update_world("The MHV space is now closed (test)")
	return space_is_closed()
end

function update_world(msg)
	probe.slow_green_blink()
	msg = string.gsub(msg, "  ", " ")
	log(msg)
	local retries = 0
	while update_status(twitter_client, msg) == "" and retries < config.max_twitter_retries do
		sleep(2)
		retries = retries + 1
	end
	if retries == config.max_twitter_retries then
		log("Failed to tweet... :(")
	end
	probe.leds_off()
end

local function round(n)
	return math.floor(n+0.5)
end

-- Return number of hours, rounded to nearest 1/4 hour, as string
function hours_rounded(hours)
	-- precision needed depends on how far away closing time is
	if hours > 6 then 
		hours = round(hours)
	elseif hours > 2 then 
		hours = round(hours * 2) / 2
	else
		hours = round(hours * 4) / 4
	end
	local fraction_name = { "", " 1/4", " 1/2", " 3/4" }
	local whole = math.floor(hours)
	if whole == 0 and hours > 0.125 then whole = "" end
	local suffix = "s"
	if hours <= 1 then suffix = "" end
	return string.format("%s%s hour%s", whole, fraction_name[((hours % 1)*4)+1], suffix)
end


return startup()