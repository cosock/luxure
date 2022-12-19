local Server = require 'luxure.server'.Server
local Opts = require 'luxure.server'.Opts
local mocks = require 'spec.mock_socket'
local utils = require 'luxure.utils'
local Error = require 'luxure.error'
local cosock = require "cosock"

local test_utils = require 'spec.test_utils'

describe('Server', function()
  it('Should handle requests', test_utils.wrap(function()
    local sock = mocks.MockTcp.new({
      { 'GET / HTTP/1.1' }
    })
    local s = assert(Server.new_with(sock, { debug = true }))
    s:listen(8080)
    local call_tx, call_rx = cosock.channel.new()
    call_rx:settimeout(5)
    s:get('/', function(req, res)
      call_tx:send(1)
    end)
    s:tick()
    local s, err = call_rx:receive()
    if not s then
      print("Error receiving from get /", err)
    end
    -- assert(s, "Error from call_rx: " .. tostring(err))
  end))
  it('should call middleware and handle requests', test_utils.wrap(function()
    local s = assert(Server.new_with(mocks.MockTcp.new({
      { 'GET / HTTP/1.1' }
    }), { sync = true }))
    s:listen(8080)
    local called = false
    local called_middleware = false
    s:use(function(req, res, next)
      called_middleware = true
      next(req, res)
    end)
    s:get('/', function(req, res)
      called = true
    end)
    s:tick()
    assert(called)
    assert(called_middleware)
  end))
  it('should call a middleware chain and handle requests', test_utils.wrap(function()
    local s = assert(Server.new_with(mocks.MockTcp.new({
      { 'GET / HTTP/1.1' }
    }), { sync = true }))
    s:listen(8080)
    local called = false
    local middleware_call_count = 0
    for i = 1, 10, 1 do
      s:use(function(req, res, next)
        middleware_call_count = middleware_call_count + 1
        next(req, res)
      end)
    end
    s:get('/', function(req, res)
      called = true
    end)
    s:tick()
    assert(called)
    assert(middleware_call_count == 10)
  end))
  it('middleware error should return 500 #filter', test_utils.wrap(function()
    local sock = mocks.MockTcp.new({ { 'GET / HTTP/1.1' } })
    local s = assert(Server.new_with(sock, Opts.new():set_env("debug")))
    s:listen(8080)
    s:use(function(req, res, next)
      Error.assert(false, 'expected fail')
    end)
    s:get('/', function(req, res)
      called = true
    end)
    s:tick()
    local chunk = sock.accepted[1].out_rx:receive()
    assert(not called)
    assert(string.find(
      chunk,
      '^HTTP/1.1 500 Internal Server Error'),
      string.format('Expected 500 found %s', utils.table_string(sock.accepted[1]))
    )
    print(sock.accepted[1].out_rx:receive())
  end))
  it('no endpoint found should return 404 #four', test_utils.wrap(function()
    local sock = mocks.MockTcp.new({ { 'GET / HTTP/1.1' } })

    local s = assert(Server.new_with(sock, { debug = true }))
    s:listen(8080)
    s:tick(print)
    local err = sock.accepted[1].out_rx:receive()
    assert(string.find(err, '^HTTP/1.1 404 Not Found'), string.format('Expected 404 found %s', utils.table_string(sock)))
  end))
  it('no endpoint found should return 404, with endpoints', test_utils.wrap(function()
    local sock = mocks.MockTcp.new({ { 'GET /not-found HTTP/1.1' } })
    local s = assert(Server.new_with(sock))
    s:get('/', function() end)
    s:get('/found', function() end)
    s:post('/found', function() end)
    s:delete('/found', function() end)
    s:listen(8080)
    s:tick()
    local chunk = sock.accepted[1].out_rx:receive()
    assert(string.find(chunk, '^HTTP/1.1 404 Not Found'),
      string.format('Expected 404 found %s', utils.table_string(sock)))
  end))
  it('error in debug returns html', test_utils.wrap(function()
    local sock = mocks.MockTcp.new({ { 'GET /boom HTTP/1.1' } })
    local s = assert(Server.new_with(sock, Opts.new():set_env("debug")))
    s:get('/boom', function()
      Error.raise("BOOM!")
    end)
    s:tick()
    local ret = sock.accepted[1].out_rx:receive()
    assert(string.find(ret, '<!DOCTYPE html>', 1, true),
    string.format("Expected response to start with 500 error found: %q", ret)
  )
  end))
end)

describe('Opts', function()
  it('builder', function()
    local opts = Opts.new():set_env('debug'):set_backlog(1)
    assert.are.equal('debug', opts.env)
    assert.are.equal(1, opts.backlog)
  end)
end)
