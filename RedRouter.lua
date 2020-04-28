local mSide = ""
local lastForwardedMessage = ""
local version = "1.1"
local stopScheduled = false

function rout(msg)
  print("received a message to rout")
  if msg == lastForwardedMessage then print("message is copy of forwarded") return false end
  local bBegin, bEnd = string.find(msg, "##")
  local subMsg = ""
  local destID = -1
  if bBegin then
    destID = tonumber(string.sub(msg, 1, bBegin-1))
    subMsg = string.sub(msg, bEnd+1)
  else
    print("Improperly formatted message received!")
    return false
  end
  -- Read message if sent to router directly
  if (destID == os.computerID()) then stopScheduled = isStopCommand(subMsg) return end
  if not fs.isDir("/RedSage/"..destID) then forwardMessage(msg) return false end

  print("received message for "..destID)
  rednet.send(destID, subMsg)
  local id, msg, _ = rednet.receive(.2)
  if (msg ~= "#R55") then
    local path = "/RedSage/"..destID.."/"
    if not fs.isDir(path) then fs.makeDir(path) end
    h = fs.open(path..string.sub(subMsg, 1, 15), "w")
    h.write(subMsg)
    h.close()
    print("Saving a message for "..destID)
  else
    print("Successfully delivered a message to "..destID)
  end



  --local rID, rMsg, rDist = rednet.receive(1)
  --if rID then
   -- if rID == destID and rMsg == "#R02" then
   --   print("message routed succesfully")
    --  return true
   -- end
 -- else
    
  --end
  return false
end

function deliverMessages(targID)
  print(targID.." is requesting their messages")
  local path = "/RedSage/"..targID.."/"
  if not fs.isDir(path) then fs.makeDir(path) end
  local MessageList = fs.list(path)
  local numMsgs = 0
  for i,file in ipairs( MessageList ) do
    if i then 
      local h = fs.open(path..file, "r")
      local tmpMsg = h.readAll()
      h.close()
      rednet.send(targID, tmpMsg)
      local id, msg, _ = rednet.receive(1)
      if id == targID and msg == "#R55" then fs.delete(path..file) numMsgs=numMsgs+1 print("Successfully delivered a message to "..targID) end
    end
  end
  print("sent "..numMsgs.." messages to "..targID)
end

function registerID(registerID)
  local path = "/RedSage/"..registerID.."/"
  if not fs.isDir(path) then fs.makeDir(path) end
  rednet.send(registerID, "#R34REGISTERED")
  print("Registered ID "..registerID)
end

function forwardMessage(msgToForward)
  print("forwarding a message")
  lastForwardedMessage = msgToForward
  sleep(.1)
  rednet.broadcast(msgToForward)
end

function sellRegistration(registerID)
  sleep(math.random()/2)
  rednet.send(registerID, "%^&wtsREGISTRATION")
  print("Computer "..registerID.." is trying to register")
end

function deRegister(registerID)
  local path = "/RedSage/"..registerID.."/"
  if fs.isDir(path) then fs.delete(path) end
  rednet.send(registerID, "#R34DEREGISTERED")
  print("DeRegistered ID "..registerID)
end

function isStopCommand(msg)
  local b, e = string.find(msg, "&M13stopROUTING&")
  if b then return true else return false end
end

-- Begin Main --
print("Routing program started!")
print("Version # "..version)
print("My ID: ", os.computerID())
if not fs.isDir("/RedSage") then fs.makeDir("/RedSage") end
local sides={"top", "left", "right", "back", "front", "bottom"}
for i=1, 6 do
  if peripheral.getType( sides[i] ) == "modem" then mSide = sides[i] end
end
print("Modem side set to "..mSide)
print("Registered IDs:")
local ids = ""
for i,file in ipairs( fs.list("/RedSage/") ) do
  ids = ids.." "..file
end
print(ids)
print("Now accepting connections...")
rednet.open(mSide)
while true do
  if stopScheduled then print("Stop command received! Stopping program!") break end
  local sID, sMsg, sDist = rednet.receive()
  if sMsg then
    if sMsg == "PING" then 
    elseif sMsg == "%^&MCHECK" then deliverMessages(sID)
    elseif sMsg == "%^&REGISTER" then registerID(sID)
    elseif sMsg == "%^&DEREGISTER" then deRegister(sID)
    elseif sMsg == "#R01" then print("Forwarded a message")
    elseif sMsg == "%^&wtbREGISTRATION" then sellRegistration(sID)
    elseif sMsg == "&^&M13stopROUTING&^&" then stopScheduled = true
    else rednet.send(sID, "#R01") rout(sMsg)
    end
  end
end
print("Routing program ended!")
rednet.close(mSide)

--[[ Changelog
 * v1.1 *
 * Reworked routing/sending to work with redsage v1.1 instant receive capabilities.
 * Added list of registered IDs to startup and listing of router's id
 * Added check for router to stop when receiving message for itself

]]--

