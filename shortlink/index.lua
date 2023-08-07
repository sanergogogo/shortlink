ngx.header.content_type = 'text/html'

local config = require('shortlink.config')
local redis = require("resty.redis")

local function redis_connect()
	local red = redis:new()
	red:set_timeout(1000)
	local ok, err = red:connect(config['redis']['host'], config['redis']['port'])
	if not ok then
		return nil, "redis connect failed" 
	end
	local res, err = red:auth(config['redis']['password'])
	if not res then
		return nil, "redis auth failed"
	end
	return red
end

local function get_long_url(short_code)
	if ngx.re.find(short_code, '[^0-9a-zA-Z]') then
		return false, "invalid short link"
	end
	local red, err = redis_connect()
	if err then
		return false, err
	end
	local result, err = red:get('SL:' .. short_code)
	if err then
		return nil, "invalid short link"
	end
	red:set_keepalive(10000, 100)
	if result ~= ngx.null then
		return result
	else
		return nil, "invalid short link"
	end
end

local short_code = string.sub(ngx.var.uri, -6)
local long_url, err = get_long_url(short_code)
if err then
	ngx.say(string.format('{"code":1,"msg":"%s"', err))
    ngx.exit(ngx.HTTP_OK)
end
ngx.redirect(long_url)
