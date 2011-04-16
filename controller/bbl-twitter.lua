-- bbl-twitter "Barebones Lua Twitter"
--
-- An OAuth-enabled Lua twitter client with _no dependencies_ apart from wget.
-- For very thin platforms like embedded systems
--
-- Requirements: wget or curl, openssl, md5sum
--
-- Inspired by "shtter" shell twitter client for OpenWRT, by "lostman"
-- http://lostman-worlds-end.blogspot.com/2010/05/openwrt_22.html
-- (lostman's is better if you want command-line tweeting on a severe budget!)
--
-- If you have easy access to luarocks + working C compiler then try
-- ltwitter - https://github.com/TheLinx/ltwitter
--
-- (this API is designed to be compatible with ltwitter, although much fewer
-- features.)

twitter_config = {
	http_get = "wget -q -O -", -- "curl -s"
	http_post = "wget -q -O - --post-data", -- "curl -s --data"	
	openssl = "openssl",
	md5sum = "md5sum",
}

local function join_http_args(args, escape_all)
	print("expanding " .. tostring(args))
	local first = true
	local res = ""
	local ampersand
	local equals
	if escape_all then
		ampersand = "%26"
		equals = "%3D"
	else
		ampersand = "&"
		equals = "="
	end

	for a,v in orderedPairs(args or {}) do 
		print("arg " .. a .. " = " .. v)
		if not first then
			res = res .. ampersand
		end
		first = false
		res = res .. a .. equals .. url_encode(v)
	end
	return res
end

local function sign_http_args(client, method, url, args)
	local data = join_http_args(args)
	local escdata = join_http_args(args, true)
	print("data " .. data)
	print("escdata " .. escdata)
	local query = string.format("%s&%s&%s", method, url_encode(url), escdata)		
	local cmd = string.format("echo -n \"%s\" | %s sha1 -hmac \"%s&%s\" -binary | openssl base64", 
				 						 query, twitter_config.openssl, 
										 client.consumer_secret, client.token_secret or "")
	local hash = cmd_output(cmd)
	hash = string.gsub(hash, "\n", "")
	return data .. "&oauth_signature=" .. url_encode(hash)
end

function cmd_output(cmd)
	print("Running " .. cmd)
	local f = assert(io.popen(cmd, 'r'))
	local res = assert(f:read('*a'))
	print ("Got back " .. res)
	f:close()
	return res
end



local function http_get(client, url, args)
	local argdata = sign_http_args(client, "GET", url, args)
 	if not string.find(url, "?") then
		url = url .. "?" 
	end
	local cmd = string.format("%s \"%s%s\"", twitter_config.http_get, url, argdata)
	return cmd_output(cmd)
end

local function http_post(client, url, postargs)
	local cmd = string.format("%s \"%s\" \"%s\"", twitter_config.http_post, sign_http_args(client, "POST", url, postargs), url)
	return cmd_output(cmd)
end


local function generate_nonce()
	-- NB: This is almost certainly sub-optimally secure as a nonce generator
	math.randomseed( os.time() )
	local src = ""
	for i=1,10 do
		src = src .. math.random()
	end
	return string.sub(cmd_output(string.format("echo \"%s\" | md5sum", src)), 1, 32)
end


-- Interact w/ the user to get us an access token & secret for the client, if not supplied
local function get_access_token(client)
	local resp= http_get( client, "http://twitter.com/oauth/request_token",
							{
								oauth_consumer_key=client.consumer_key,
								oauth_nonce=generate_nonce(),
								oauth_signature_method="HMAC-SHA1",
								oauth_timestamp=os.time(),
								oauth_token="",
								oauth_version="1.0"
							})
	assert(resp ~= "", "Could not get OAuth request token")
	
	local req_token = string.match(resp, "oauth_token=([^&]*)")
	local req_secret = string.match(resp, "oauth_token_secret=([^&]*)")

	print("Open this URL in your browser and enter back the PIN")
	print("http://twitter.com/oauth/authorize?oauth_token=" .. req_token)
	local req_pin = io.read("*line")

	resp = http_get( client, "http://twitter.com/oauth/access_token",
						  {
							  oauth_consumer_key=client.consumer_key,
							  oauth_nonce=generate_nonce(),
							  oauth_signature_method="HMAC-SHA1",
							  oauth_timestamp=os.time(),
							  oauth_token=req_token,
							  oauth_verifier=req_pin,
							  oauth_version="1.0"
						  })
	assert(resp ~= "", "Unable to get access token")

	client.token_key = string.match(resp, "oauth_token=([^&]*)")
	client.token_secret = string.match(resp, "oauth_token_secret=([^&]*)")
	print("Got OAuth key & secret")
	print(client.token_key)
	print(client.token_secret)
end
							  

function client(consumer_key, consumer_secret, token_key, token_secret, verifier)
	print("hello")
	local client = {}
	for j,x in pairs(twitter_config) do client[j] = x end
	-- args can be set in twitter_config if you want them global
	client.consumer_key = consumer_key or client.consumer_key 
	client.consumer_secret = consumer_secret or client.consumer_secret
	client.token_key = token_key or client.token_key
	client.token_secret = token_secret or client.token_secret

	assert(client.consumer_key and client.consumer_secret, "you need to specify a consumer key and a consumer secret!")
	if not (client.token_key and client.token_secret) then
		print("TOKEN!")
		get_access_token(client)
	end
	return client
end


-------------------
-- Util functions
-------------------

-- Taken from http://lua-users.org/wiki/StringRecipes
function url_decode(str)
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)",
      function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end

-- Taken from http://lua-users.org/wiki/StringRecipes then modified for RFC3986
function url_encode(str)
  if (str) then
	  print("encoding " .. str)
	  str = string.gsub (str, "([^%w-._~ ])",
								function (c) return string.format ("%%%02X", string.byte(c)) end)
	  print("got back " .. str)	 
  end
  return str	
end


--  taken from http://lua-users.org/wiki/SortedIteration
--[[
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.

Example:
]]

function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order. We use a temporary ordered key table that is stored in the
    -- table being iterated.

    --print("orderedNext: state = "..tostring(state) )
    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
        return key, t[key]
    end
    -- fetch the next value
    key = nil
    for i = 1,table.getn(t.__orderedIndex) do
        if t.__orderedIndex[i] == state then
            key = t.__orderedIndex[i+1]
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    return orderedNext, t, nil
end
