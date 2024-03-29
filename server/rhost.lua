local server = require("server")
local common = require("common")

settings.define("rperipheral.hostname", {
  description="The hostname to use for this rperipheral host",
  type="string",
})
settings.define("rperipheral.ignorePassword", {
  description="Intentionally do not require a password",
  type="boolean",
  default=false,
})
settings.define("rperipheral.password", {
  description="Password to use when connecting to this rperipheral host.",
  type="string",
})

assert(settings.get("rperipheral.hostname"), "Set rperipheral.hostname first.")

local s = server.new("rperipheral", settings.get("rperipheral.hostname"))


local ignorePassword = settings.get("rperipheral.ignorePassword")

local password
if not ignorePassword then
  password = assert(settings.get("rperipheral.password"), "Set rperipheral.password first.")
end

function s:msgHandle(id, msg)
  if msg[1] == "authorize" then
    self:sendEncryptedMessage(id, {(msg[2] or " ") == password})
    self.activeConnections[id].authorized = msg[2] == password
  elseif msg[1] == "get" and (self.activeConnections[id].authorized or not password) then
    -- msg[1] should be peripheral name
    -- just return a table of all functions that this peripheral supports
    local T = {}
    local pT = peripheral.wrap(msg[2])
    
    if pT then
      T.meta = getmetatable(pT)
      for k,v in pairs(pT) do
        T[k] = k
      end
      self:sendEncryptedMessage(id, T)
    else
      self:sendMessage(id, common.messageTypes.error, msg[2].." is not a valid peripheral.")
    end
  elseif msg[1] == "call" and (self.activeConnections[id].authorized or not password) then
    -- msg[2] should be a peripheral name
    -- msg[3] should be the method name
    -- msg[4] should be the args list
    local response = {peripheral.call(msg[2], msg[3], table.unpack(msg[4]))}
    self:sendEncryptedMessage(id, response)
  elseif msg[1] == "isPresent" and (self.activeConnections[id].authorized or not password) then
    local response = {peripheral.isPresent(msg[2])}
    self:sendEncryptedMessage(id, response)
  elseif msg[1] == "getType" and (self.activeConnections[id].authorized or not password) then
    local response = {peripheral.getType(msg[2])}
    self:sendEncryptedMessage(id, response)
  elseif not self.activeConnections[id].authorized then
    self:sendEncryptedMessage(id, {"Unauthorized"})
  end
end

s:start()