
local isBusy = "no"


function SendBlockMined(tgt, block)
  redmsg.CreateAndSend(tgt, "BlockMined", textutils.serialize(block), { "NOSAVE" })
end


function MineBlocks(blocks)
  local lastAttempts = {}
  while table.getn(blocks) > 0 do
    toRemove = 0
    nextToABlock = false
    local pos = lps.locateVec()
    for _i, block in pairs(blocks) do
      if lps.minDist(pos, block) == 1 then --it's next to us
        if block.y > pos.y then --it's up
          while turtle.detectUp() do --handle gravel
            turtle.digUp()
          end
        elseif block.y < pos.y then --it's down
          while turtle.detectDown() do
            turtle.digDown()
          end
        elseif block.x > pos.x then --it's east
          lps.face(3)
          while turtle.detect() do
            turtle.dig()
          end
        elseif block.x < pos.x then --it's west
          lps.face(1)
          while turtle.detect() do
            turtle.dig()
          end
        elseif block.z > pos.z then --it's south
          lps.face(0)
          while turtle.detect() do
            turtle.dig()
          end
        elseif block.z < pos.z then --it's north
          lps.face(2)
          while turtle.detect() do
            turtle.dig()
          end
        end
        nextToABlock = true
        toRemove = _i
        SendBlockMined(sender, block)
        lastAttempts = {}
        break
      end
    end
    if nextToABlock and toRemove > 0 then
      table.remove(blocks, toRemove)
    end
    if not nextToABlock then
      --we need to move
      --find the closest block
      local closest = blocks[1]
      local closeDist = lps.minDist(blocks[1], pos)
      for _i, block in pairs(blocks) do
        local d = lps.minDist(block, pos)
        if d < closeDist then
          closest = block
          closeDist = d
        end
      end --for
      --now we have the closest block, but we need to go next to it
      
      vectors = {
        vector.new(1, 0, 0),
        vector.new(-1, 0, 0),
        vector.new(0, 1, 0),
        vector.new(0, -1, 0),
        vector.new(0, 0, 1),
        vector.new(0, 0, -1),
      }
      
      local newClosest = nil
      for k,v in pairs(vectors) do
        local closeVec = vector.new(closest.x, closest.y, closest.z)+v
        if not lps.VectorInSet(closeVec, lastAttempts) then --don't repeat
          local d = lps.minDist(closeVec, pos)
          if d < closeDist then
            newClosest = closeVec
            closeDist = d 
          end
        end
      end
      
      if not newClosest then return false end
      
      table.insert(lastAttempts, newClosest)
      lps.goVec(newClosest, 10) -- go to the closest block
    end --if not nextToABlock
  end
  return true
end

function SendRegister(tgtID)
  print("Attempting to register with "..tgtID)
  local redData = CompileData()
  if redmsg.CreateAndSend(tgtID, "MINE:REGISTER", textutils.serialize(redData), { "NOSAVE" }) then
    print("AOS with "..tgtID)
    lps.SetupRedMsg(tgtID)
  else
    print(tgtID.." didn't respond")
  end
end


function CompileData()
  local redData = {}
  redData.fuel = turtle.getFuelLevel()
  redData.position = lps.locateVec()
  redData.busy = isBusy
  redData.inventory = {}
  
  for slot=1,16 do
    table.insert(redData.inventory, turtle.getItemDetail(slot))
  end
  
  return redData
end

-- sends an update message containing info like:
-- position
-- fuel level
-- busy status
-- inventory contents
function SendUpdate(tgtID)
  local redData = CompileData()
  
  if not redmsg.CreateAndSend(tonumber(tgtID), "MINE:UPDATE", textutils.serialize(redData), { "NOSAVE" }) then
    print(tgtID.." didn't respond to update...")
  end
end

-- MAIN --

if not os.loadAPI("redmsg") then
  print("Error loading redmsg API")
  return
end

if not os.loadAPI("lps") then
  print("Error loading lps API")
  return
end

-- initialize redmsg
local side = redmsg.Initialize()
if not side then
  print("Couldn't initialize redmsg. Missing modem?")
  return
end

print("I think I'm at: "..lps.locateVec():tostring().." f:"..lps.facing())

local args = {...}
if # args > 0 and args[1] == "cached" then
  lps.fileInitialize()
else
  print("Use cached location? (Y/n)")
  local resp = read()
  if resp and resp == "n" then
    print("Enter location:")
    print("x:")
    local x = tonumber(read())
    print("y:")
    local y = tonumber(read())
    print("z:")
    local z = tonumber(read())
    print("facing:")
    local face = tonumber(read())
    
    if x and y and z and face then
      lps.Initialize(x, y, z, face)
    else
      print("Invalid position data")
      return
    end
  else
    lps.fileInitialize()
  end
end

if not lps.IsInitialized() then
  print("Position not initialized! Exiting.")
  return
end

--lps.SetupRedMsg(redmsgID)
--lps.SendRedMsgUpdate()
print("Initialized")

local _lastID = -1

while true do
  print("Waiting for message...")
  isBusy = "no"
  local message = redmsg.ReceiveMessage()
  target, sender, subject, body = redmsg.GetComponents(message)
  
  if tonumber(target) < 0 then --broadcast, might be registration
    print("Got broadcast")
    if subject == "MINE:INITIALIZE" then --is registration
      SendRegister(sender)
    end
  end
  
  if target == os.getComputerID() then
    -- sent to us specifically
    if subject == "MINE:GO" then
      tgtTable = textutils.unserialize(body)
      tgt = vector.new(tgtTable.tgt.x, tgtTable.tgt.y, tgtTable.tgt.z)
      waypoints = tgtTable.waypoints
      print("Going to "..tgt:tostring())
      isBusy = "yes"
      SendUpdate(sender)
      madeIt = lps.goWaypointsClosest(tgt, waypoints)
      print("Success? ", madeIt)
      isBusy = "no"
      SendUpdate(sender)
    elseif subject == "MINE:MINE" then
      print("Attempting to mine some blocks")
      local blocks = textutils.unserialize(body)
      isBusy = "yes"
      SendUpdate(sender)
      MineBlocks(blocks)
      isBusy = "no"
      SendUpdate(sender)
    elseif subject == "MINE:HEARTBEAT" then
      print("heartbeat")
      SendUpdate(tonumber(sender))
    elseif subject == "END" then
      print("Received END message")
      break
    end
  end
end

redmsg.Finalize(side)