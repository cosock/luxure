local cosock = require "cosock"
local utils = require "luxure.utils"
---TCP Client Socket
local MockSocket = {}
MockSocket.__index = MockSocket

function MockSocket.new(inner)
  local in_tx, rx = cosock.channel.new()
  rx:settimeout(1)
  local out_tx, out_rx = cosock.channel.new()
  out_rx:settimeout(1)
  local ret = {
    recvd = 0,
    sent = 0,
    inner = rx,
    in_tx = in_tx,
    out_tx = out_tx,
    out_rx = out_rx,
    outbound = {},
    open = true,
  }
  setmetatable(ret, MockSocket)
  for _, chunk in ipairs(inner or {}) do
    in_tx:send(chunk)
  end
  return ret
end

function MockSocket:bind(ip, port)
  return 1
end

function MockSocket:listen(backlog)
  return 1
end

function MockSocket:getsockname()
  return '0.0.0.0', 0
end

function MockSocket:getstats()
  return self.recvd, self.sent
end

function MockSocket:close()
  self.open = false
end

function MockSocket.new_with_preamble(method, path)
  return MockSocket.new({
    string.format('%s %s HTTP/1.1', string.upper(method), path)
  })
end

function MockSocket:receive()
  if #self.inner.link.queue == 0 then
    return nil, 'empty'
  end
  cosock.socket.sleep(0)
  local part, _err = self.inner:receive()
  self.recvd = self.recvd + #(part or '')
  return part
end

function MockSocket:send(s)
  self.out_tx:send(s)
  if s == 'timeout' or s == 'closed' then
    return nil, s
  end
  self.outbound = self.outbound or {}
  self.sent = self.sent + #(s or '')
  table.insert(self.outbound, s)
  self.out_tx:send(s)
  if s then
    return #s
  end
end

function MockSocket:setwaker(...)
  self.inner:setwaker(...)
  
end

---TCP Master Socket
local MockTcp = {}
MockTcp.__index = MockTcp

function MockTcp.new(inner)
  local tx, rx = cosock.channel.new()
  local ret = {
    inner = rx,
    accepted = {}
  }
  setmetatable(ret, MockTcp)
  for _, sock in pairs(inner) do
    tx:send(sock)
  end
  return ret
end

function MockTcp:accept()
  local list = self.inner:receive()
  local sock = MockSocket.new(list)
  table.insert(self.accepted, sock)
  return sock
end

function MockTcp:bind(ip, port)
  return 1
end

function MockTcp:listen(backlog)
  return 1
end

function MockTcp:getsockname()
  return '0.0.0.0', 0
end

function MockTcp:settimeout(tm)
  self.inner:settimeout(tm)
end
function MockTcp:setwaker(...)
  self.inner:setwaker(...)
end
local MockModule = {}
MockModule.__index = MockModule
local sock_tx, sock_rx = cosock.channel.new()
function MockModule.new(inner)
  for _, sock in pairs(inner) do
    sock_tx:send(sock)
  end
  return MockModule
end
function MockModule.tcp()
  local list = sock_rx:recv()
  return MockTcp.new(list)
end
function MockModule.bind(ip, port)
  return 1
end


return {
  MockSocket = MockSocket,
  MockTcp = MockTcp,
  MockModule = MockModule,
}
