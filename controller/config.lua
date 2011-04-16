-- Spaceprobe client configuration file
--

config = {

	-- Spaceprobe name
	-- ie "rfcomm0" for a real probe
	--     "simulation" for a simulated probe
	spaceprobe_name = "simulation",

	-- Seconds after the knob stops moving
	-- before we react
	knob_latency = 2,

	-- Knob has to move by this much (in raw values, scale 0-1023)
	-- to be considered a new value
	knob_deadband = 10,

	-- Target twitter OAuth credentials
	oauth_consumer_key = "",
	oauth_consumer_secret = "",

	-- SMTP details
	-- TBA


	-- Calibration table for the knob
	-- values are [raw-value, hours} where raw-value is
	-- the ADC reading 0-1023 from the probe
	knob_table = { 
		{ 0, 0 }, 
		{ 512, 5 }, 
		{1024, 10 } 
	},

	-- Calibration table for the readback dial
	-- values are {hours, raw-value} where raw-value is the
	-- PWM setting 0-255
	dial_table = {
		{ 0, 0 },
		{ 5, 127 },
		{ 10, 255 }
	},


}
