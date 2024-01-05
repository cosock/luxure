-- This comes from LuaSocket
local mime = require 'mime'
local lux = require 'luxure'

local server = lux.Server.new(lux.Opts.new():set_env('debug'))
-- use some middleware that will check for
-- the authorization header with a password 'SUPERSECRET'
server:use(function (req, res, next)
    if req.url == '/' then
        return next(req, res)
    end
    local h = req:get_headers();
    local auth = h:get_one("authorization")
    if auth then
        for encoded in string.gmatch(auth, 'Basic (.*)') do
            local decoded = mime.decode('base64')(encoded)
            for _ in string.gmatch(decoded, '.*:SUPERSECRET$') do
                return next(req, res)
            end
        end
    end
    res.headers:append("www_authenticate", "Basic realm='my realm'")
    lux.Error.raise('Unable to authenticate', 401)
end)

local function static_content(path, res)
    local f = io.open(path)
    lux.Error.assert(f, 'File not found', 404)
    res:set_content_type('text/html')
    for line in f:lines('L') do
        res:append_body(line)
    end
    res:send()
    if f then f:close() end
end

server:get('/', function(req, res)
    static_content('static/not_authed.html', res)
end)

server:get('/authed', function(req, res)
    static_content('static/authed.html', res)
end)

server.sock:setoption('reuseaddr', true)
-- open the server's socket on port 8080
server:listen(0)
server.sock:setoption('reuseaddr', true)
print(string.format('listening on http://%s:%s', server.sock:getsockname()))
server:run()
