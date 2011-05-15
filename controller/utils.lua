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
