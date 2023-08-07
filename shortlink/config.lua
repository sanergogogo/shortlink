local M = {}

-- redis配置
local redis = {}
redis['host'] = '127.0.0.1'
redis['port'] = 6379
redis['password'] = 'passwd'

-- 短链接域名
local domain = 'http://127.0.0.1:8080/'

-- 过期时间 为nil则永不过期
local ttl = 15 * 24 * 60 * 60

-- 白名单和黑名单
local white_host = {}
local black_host = {domain}

M['white_host'] = white_host
M['black_host'] = black_host
M['redis'] = redis
M['domain'] = domain
M['ttl'] = ttl

return M