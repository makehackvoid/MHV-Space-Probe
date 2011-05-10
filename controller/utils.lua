-- some utility methods for the space probe

function log(message)
	print(os.date() .. " " .. tostring(message))
end

function round(n)
	return math.floor(n+0.5)
end

-- translate a raw value through a lookup table of { {rawval, translation} }
-- interpolating between closest values
function translate(rawval, lookup_table)
	low_p = { 0, 0 }
	high_p = { 100000000, 0 } -- hacky big number here(!)
	for idx,kv in ipairs(lookup_table) do
		k = kv[1]
		if k < rawval and k > low_p[1] then low_p = kv end
		if k > rawval and k < high_p[1] then high_p = kv end
	end
	-- now rawval is bounded between low_p[1] and high_p[1], with equivalent lookup values
	return (rawval - low_p[1]) * (high_p[2] - low_p[2]) / (high_p[1] - low_p[1]) + low_p[2]
end
