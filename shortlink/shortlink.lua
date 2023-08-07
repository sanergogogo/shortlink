local config = require("shortlink.config")
local redis = require("resty.redis")
local mmh2 = require ("shortlink.murmurhash2")
local base62 = require ("shortlink.base62")

local ttl = config.ttl

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

local function find_in_table(table, value)
	if table == ngx.null or #table == 0 then
		return false
	end
	for k,v in pairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

local function url_check(long_url)
	if long_url == nil or long_url == "" or #long_url > 2048 then
		return nil, "invalid long url"
	end
	local result = {}
	local matches = ngx.re.match(long_url, '^(http|https|ftp)://([^/]+)((/[^\\\\?#]+)([^#]+)?(.+))?')
	if matches and matches[2] then
		result['protocol'] = matches[1]
		result['host'] = matches[2]
	else
		return nil, "url format error"
	end
	if #config['white_host'] ~= 0 then
		if find_in_table(config['white_host'], result['host']) then
			return result
		else
			return nil, "invalid host"
		end
	end
	if find_in_table(config['black_host'], result['host']) then
		return nil, "invalid host"
	end
	return result
end

local function url_create(long_url)
	local red, err = redis_connect()
	if err then
		return false, err
	end
	local url_md5 = ngx.md5(long_url)
	local result, err = red:get('LS:' .. url_md5)
	if err then
		return nil, "redis get error"
	end
	if result ~= ngx.null then
		return config['domain']..result
	end
	local url_check, err = url_check(long_url)
	if err then
		return nil, err
	end

    local short_url_code
    local hash_cnt = 0
    while true do
        local hash = mmh2(long_url .. (hash_cnt > 0 and "t=" .. hash_cnt or ""))
        short_url_code = base62.encode(hash)
        hash_cnt = hash_cnt + 1

        local exist, err = red:get('SL:' .. short_url_code)
        if err then
            return nil, "internal error"
        end
        if exist == ngx.null then
            break
        end
    end

    if ttl then
        red:setex('LS:' .. url_md5, ttl, short_url_code)
        red:setex('SL:' .. short_url_code, ttl, long_url)
    else
        red:set('LS:' .. url_md5, short_url_code)
        red:set('SL:' .. short_url_code, long_url)
    end
	red:set_keepalive(10000, 100)
	return config['domain'] .. short_url_code
end

ngx.header.content_type = 'text/json'
local args = ngx.req.get_uri_args()

local long_url = args['url']
local short_url, err = url_create(long_url)
if err then
	ngx.say(string.format('{"code":1,"msg":"%s"', err))
    ngx.exit(ngx.HTTP_OK)
end

ngx.say(string.format('{"code":0,"shortlink":"%s"', short_url))
