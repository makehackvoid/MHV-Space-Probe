-- some utility methods for the space probe

function log(message)
	print(os.date() .. " " .. tostring(message))
end

function round(n)
	return math.floor(n+0.5)
end

function finite(x) 
	local inf = 1/0
	return x and (x == x) and (x ~= inf ) and (x ~= -inf)
end

-- translate a raw value through a lookup table of { {rawval, translation} }
-- interpolating between closest values
function translate(rawval, lookup_table)
	local low_p = { 0, 0 }
	local high_p = { 100000000, 0 } -- hacky big number here(!)
	for idx,kv in ipairs(lookup_table) do -- kv is a table of {rawval, translation} here
		local k = kv[1]
		if rawval == k then return kv[2] end -- shortcut exact matches (helps with zero)
		if k < rawval and k > low_p[1] then low_p = kv end
		if k > rawval and k < high_p[1] then high_p = kv end
	end
	-- now rawval is bounded between low_p[1] and high_p[1], with equivalent lookup values
	local res = (rawval - low_p[1]) * (high_p[2] - low_p[2]) / (high_p[1] - low_p[1]) + low_p[2]
	if not finite(res) then res = 0 end
	return res
end

-- Return s if a pluralised number, nothing otherwise
local function plural(number)
	return (number == 1 and "") or "s"
end

-- Return number of hours, rounded to nearest 1/4 hour, as string
function hours_rounded(hours)
	-- precision needed depends on how far away closing time is
	if hours > 6 then 
		return string.format("%s hours", round(hours))
	elseif hours > 2 then
			halves = round(hours * 2)
			local lookup = { 
				[4] = "two hours",
				[5] = "2 1/2 hours",
				[6] = "three hours",
				[7] = "3 1/2 hours",
				[8] = "four hours",
				[9] = "4 1/2 hours",
				[10] = "five hours",
				[11] = "5 1/2 hours",
				[12] = "six hours"
			}
			return lookup[halves]
	elseif hours > 0.25 then
		quarters = round(hours * 4)
		local lookup = {
			[1] =  "fifteen minutes",
			[2] =  "half an hour",
			[3] =  "3/4 of an hour",
			[4] =  "an hour",
			[5] =  "1 1/4 hours",
			[6] =  "90 minutes",
			[7] =  "1 3/4 hours",
			[8] =  "two hours"
		}
		return lookup[quarters]
	else
		minutes = round(hours*60)
		return string.format("%s minute%s", minutes, plural(minutes))
	end
end
